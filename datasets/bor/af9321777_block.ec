commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
commit af932177755f5f839ab29b16dc490d3e1bb3708d
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Thu Apr 30 17:39:08 2015 +0300

    p2p: reduce the concurrent handshakes to 10/10 in/out

diff --git a/p2p/server.go b/p2p/server.go
index b7a92ce55..164aaba37 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -25,10 +25,10 @@ const (
 	// This is the maximum number of inbound connection
 	// that are allowed to linger between 'accepted' and
 	// 'added as peer'.
-	maxAcceptConns = 50
+	maxAcceptConns = 10
 
 	// Maximum number of concurrently dialing outbound connections.
-	maxDialingConns = 50
+	maxDialingConns = 10
 
 	// total timeout for encryption handshake and protocol
 	// handshake in both directions.
