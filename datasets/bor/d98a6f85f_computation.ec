commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
commit d98a6f85fc1787a166ab91720c738fed2098185f
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat May 16 12:33:55 2015 +0200

    core: further improved uncle error messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 9a213686f..cae618b39 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -343,23 +343,23 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 
 	uncles.Add(block.Hash())
 	for i, uncle := range block.Uncles() {
-		if uncles.Has(uncle.Hash()) {
+		hash := uncle.Hash()
+		if uncles.Has(hash) {
 			// Error not unique
-			return UncleError("uncle[%d] not unique", i)
+			return UncleError("uncle[%d](%x) not unique", i, hash[:4])
 		}
+		uncles.Add(hash)
 
-		uncles.Add(uncle.Hash())
-
-		if ancestors.Has(uncle.Hash()) {
-			return UncleError("uncle[%d] is ancestor", i)
+		if ancestors.Has(hash) {
+			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
+			return UncleError("uncle[%d](%x)'s parent unknown (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
-			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, uncle.Hash().Bytes()[:4], err))
+			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
 
