commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
commit ad0e6e971e7d03c07842cc236fec09c73f93f465
Author: Felix Lange <fjl@twurst.com>
Date:   Thu Jun 2 22:33:11 2016 +0200

    console: remove unnecessary JS evaluation in Welcome

diff --git a/console/console.go b/console/console.go
index a19b267bc..baa9cf545 100644
--- a/console/console.go
+++ b/console/console.go
@@ -244,15 +244,13 @@ func (c *Console) AutoCompleteInput(line string, pos int) (string, []string, str
 // console's available modules.
 func (c *Console) Welcome() {
 	// Print some generic Geth metadata
+	fmt.Fprintf(c.printer, "Welcome to the Geth JavaScript console!\n\n")
 	c.jsre.Run(`
-    (function () {
-			console.log("Welcome to the Geth JavaScript console!\n");
-      console.log("instance: " + web3.version.node);
-      console.log("coinbase: " + eth.coinbase);
-      console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
-      console.log(" datadir: " + admin.datadir);
-    })();
-  `)
+		console.log("instance: " + web3.version.node);
+		console.log("coinbase: " + eth.coinbase);
+		console.log("at block: " + eth.blockNumber + " (" + new Date(1000 * eth.getBlock(eth.blockNumber).timestamp) + ")");
+		console.log(" datadir: " + admin.datadir);
+	`)
 	// List all the supported modules for the user to call
 	if apis, err := c.client.SupportedModules(); err == nil {
 		modules := make([]string, 0, len(apis))
@@ -260,9 +258,9 @@ func (c *Console) Welcome() {
 			modules = append(modules, fmt.Sprintf("%s:%s", api, version))
 		}
 		sort.Strings(modules)
-		c.jsre.Run("(function () { console.log(' modules: " + strings.Join(modules, " ") + "'); })();")
+		fmt.Fprintln(c.printer, " modules:", strings.Join(modules, " "))
 	}
-	c.jsre.Run("(function () { console.log(); })();")
+	fmt.Fprintln(c.printer)
 }
 
 // Evaluate executes code and pretty prints the result to the specified output
