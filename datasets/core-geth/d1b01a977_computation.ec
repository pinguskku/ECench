commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
commit d1b01a977fe3f836e2df718212c57a187a09bbe9
Author: meows <b5c6@protonmail.com>
Date:   Thu Oct 15 09:19:56 2020 -0500

    eth: (lint) remove unnecessary type conversion
    
    Signed-off-by: meows <b5c6@protonmail.com>

diff --git a/eth/api_tracer.go b/eth/api_tracer.go
index 83c168bef..66314c0bd 100644
--- a/eth/api_tracer.go
+++ b/eth/api_tracer.go
@@ -753,7 +753,7 @@ func traceTransaction(ctx context.Context, eth *Ethereum, hash common.Hash, conf
 		"blockNumber":         block.NumberU64(),
 		"blockHash":           blockHash.Hex(),
 		"transactionHash":     tx.Hash().Hex(),
-		"transactionPosition": uint64(index),
+		"transactionPosition": index,
 	}
 
 	// Trace the transaction and return
