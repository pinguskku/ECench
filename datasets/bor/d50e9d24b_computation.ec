commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
commit d50e9d24be6ae410af7b5975f453456367a7b28c
Author: jacksoom <lifengliu1994@gmail.com>
Date:   Fri Mar 19 19:04:15 2021 +0800

    consensus/ethash: remove unnecessary variable definition (#22512)

diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index 550d99893..1afdc9381 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -537,7 +537,6 @@ func NewShared() *Ethash {
 
 // Close closes the exit channel to notify all backend threads exiting.
 func (ethash *Ethash) Close() error {
-	var err error
 	ethash.closeOnce.Do(func() {
 		// Short circuit if the exit channel is not allocated.
 		if ethash.remote == nil {
@@ -546,7 +545,7 @@ func (ethash *Ethash) Close() error {
 		close(ethash.remote.requestExit)
 		<-ethash.remote.exitCh
 	})
-	return err
+	return nil
 }
 
 // cache tries to retrieve a verification cache for the specified block number
