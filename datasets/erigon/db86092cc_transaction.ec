commit db86092ccda498731d3bb608d07bd13bd9a8a31d
Author: Andrew Ashikhmin <34320705+yperbasis@users.noreply.github.com>
Date:   Mon Jul 26 16:09:39 2021 +0200

    Remove unnecessary value transfer check from TransitionDb (#2424)

diff --git a/core/error.go b/core/error.go
index f5ac3c11d..753f20015 100644
--- a/core/error.go
+++ b/core/error.go
@@ -65,10 +65,6 @@ var (
 	// by a transaction is higher than what's left in the block.
 	ErrGasLimitReached = errors.New("gas limit reached")
 
-	// ErrInsufficientFundsForTransfer is returned if the transaction sender doesn't
-	// have enough funds for transfer(topmost call only).
-	ErrInsufficientFundsForTransfer = errors.New("insufficient funds for transfer")
-
 	// ErrInsufficientFunds is returned if the total cost of executing a transaction
 	// is higher than the balance of the user's account.
 	ErrInsufficientFunds = errors.New("insufficient funds for gas * price + value")
diff --git a/core/state_transition.go b/core/state_transition.go
index 174ce3630..eb8f303d3 100644
--- a/core/state_transition.go
+++ b/core/state_transition.go
@@ -287,7 +287,7 @@ func (st *StateTransition) TransitionDb(refunds bool, gasBailout bool) (*Executi
 	// 5. there is no overflow when calculating intrinsic gas
 	// 6. caller has enough balance to cover asset transfer for **topmost** call
 
-	// Check clauses 1-3, buy gas if everything is correct
+	// Check clauses 1-3 and 6, buy gas if everything is correct
 	if err := st.preCheck(gasBailout); err != nil {
 		return nil, err
 	}
@@ -308,15 +308,6 @@ func (st *StateTransition) TransitionDb(refunds bool, gasBailout bool) (*Executi
 	}
 	st.gas -= gas
 
-	// Check clause 6
-	var bailout bool
-	if !msg.Value().IsZero() && !st.evm.Context.CanTransfer(st.state, msg.From(), msg.Value()) {
-		if gasBailout {
-			bailout = true
-		} else {
-			return nil, fmt.Errorf("%w: address %v", ErrInsufficientFundsForTransfer, msg.From().Hex())
-		}
-	}
 	// Set up the initial access list.
 	if st.evm.ChainRules.IsBerlin {
 		st.state.PrepareAccessList(msg.From(), msg.To(), st.evm.ActivePrecompiles(), msg.AccessList())
@@ -335,7 +326,7 @@ func (st *StateTransition) TransitionDb(refunds bool, gasBailout bool) (*Executi
 	} else {
 		// Increment the nonce for the next transaction
 		st.state.SetNonce(msg.From(), st.state.GetNonce(sender.Address())+1)
-		ret, st.gas, vmerr = st.evm.Call(sender, st.to(), st.data, st.gas, st.value, bailout)
+		ret, st.gas, vmerr = st.evm.Call(sender, st.to(), st.data, st.gas, st.value, gasBailout)
 	}
 	if refunds {
 		if london {
