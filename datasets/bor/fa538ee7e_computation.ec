commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
commit fa538ee7ed04b1a5e101938d64805d3fcd0eb697
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 8 17:58:03 2019 +0200

    p2p/discover: improve randomness of ReadRandomNodes (#19799)
    
    Make it select from all live nodes instead of selecting the heads of
    random buckets.

diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index e0a46792b..e5a5793e3 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -147,35 +147,18 @@ func (tab *Table) ReadRandomNodes(buf []*enode.Node) (n int) {
 	tab.mutex.Lock()
 	defer tab.mutex.Unlock()
 
-	// Find all non-empty buckets and get a fresh slice of their entries.
-	var buckets [][]*node
+	var nodes []*enode.Node
 	for _, b := range &tab.buckets {
-		if len(b.entries) > 0 {
-			buckets = append(buckets, b.entries)
+		for _, n := range b.entries {
+			nodes = append(nodes, unwrapNode(n))
 		}
 	}
-	if len(buckets) == 0 {
-		return 0
-	}
-	// Shuffle the buckets.
-	for i := len(buckets) - 1; i > 0; i-- {
-		j := tab.rand.Intn(len(buckets))
-		buckets[i], buckets[j] = buckets[j], buckets[i]
-	}
-	// Move head of each bucket into buf, removing buckets that become empty.
-	var i, j int
-	for ; i < len(buf); i, j = i+1, (j+1)%len(buckets) {
-		b := buckets[j]
-		buf[i] = unwrapNode(b[0])
-		buckets[j] = b[1:]
-		if len(b) == 1 {
-			buckets = append(buckets[:j], buckets[j+1:]...)
-		}
-		if len(buckets) == 0 {
-			break
-		}
+	// Shuffle.
+	for i := 0; i < len(nodes); i++ {
+		j := tab.rand.Intn(len(nodes))
+		nodes[i], nodes[j] = nodes[j], nodes[i]
 	}
-	return i + 1
+	return copy(buf, nodes)
 }
 
 // getNode returns the node with the given ID or nil if it isn't in the table.
