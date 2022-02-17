commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
commit a0659799d0c290d38495cc68d6888cecc00bcb1e
Author: Chris Ziogas <ziogaschr@gmail.com>
Date:   Tue Aug 24 18:00:38 2021 +0300

    params/types/goethereum: remove unnecessary use of bigNewU64Min

diff --git a/params/types/goethereum/goethereum_configurator.go b/params/types/goethereum/goethereum_configurator.go
index 1a8a251df..22b9e5fd2 100644
--- a/params/types/goethereum/goethereum_configurator.go
+++ b/params/types/goethereum/goethereum_configurator.go
@@ -452,7 +452,7 @@ func (c *ChainConfig) SetEIP2929Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2930Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2930Transition(n *uint64) error {
@@ -470,7 +470,7 @@ func (c *ChainConfig) SetEIP1559Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2565Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
@@ -479,7 +479,7 @@ func (c *ChainConfig) SetEIP2565Transition(n *uint64) error {
 }
 
 func (c *ChainConfig) GetEIP2718Transition() *uint64 {
-	return bigNewU64Min(c.BerlinBlock, c.BerlinBlock)
+	return bigNewU64(c.BerlinBlock)
 }
 
 func (c *ChainConfig) SetEIP2718Transition(n *uint64) error {
