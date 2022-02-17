commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
commit 1ffbb977522a6b08853a09c986fa40f2967af968
Author: alex.sharov <alex.sharov@lazada.com>
Date:   Tue Dec 3 17:13:23 2019 +0700

    removed unnecessary allocations, add tcp context

diff --git a/cmd/state/commands/state_growth.go b/cmd/state/commands/state_growth.go
index 5b776084c..b1e03eb0a 100644
--- a/cmd/state/commands/state_growth.go
+++ b/cmd/state/commands/state_growth.go
@@ -15,7 +15,7 @@ func init() {
 				return err
 			}
 
-			reporter.StateGrowth1(chaindata)
+			//reporter.StateGrowth1(chaindata)
 			reporter.StateGrowth2(chaindata)
 			return nil
 		},
diff --git a/cmd/state/stateless/state.go b/cmd/state/stateless/state.go
index 312bc06bb..0c0632869 100644
--- a/cmd/state/stateless/state.go
+++ b/cmd/state/stateless/state.go
@@ -180,7 +180,7 @@ func (r *Reporter) StateGrowth1(chaindata string) {
 			return nil
 		}
 		c := b.Cursor()
-		for k, _ := c.Seek([]byte("0xx")); k != nil; k, _ = c.Next() {
+		for k, _ := c.First(); k != nil; k, _ = c.Next() {
 			// First 32 bytes is the hash of the address
 			copy(addrHash[:], k[:32])
 			lastTimestamps[addrHash] = maxTimestamp
diff --git a/ethdb/remote/bolt_remote.go b/ethdb/remote/bolt_remote.go
index 42e8bd1ce..75b233e49 100644
--- a/ethdb/remote/bolt_remote.go
+++ b/ethdb/remote/bolt_remote.go
@@ -23,7 +23,6 @@ import (
 	"net"
 
 	"github.com/ledgerwatch/bolt"
-	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ugorji/go/codec"
 )
@@ -348,6 +347,7 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 				log.Error("could not decode numberOfKeys for CmdCursorNext")
 			}
 			var key, value []byte
+
 			cursor, ok := cursors[cursorHandle]
 			if !ok {
 				lastError = fmt.Errorf("cursor not found")
@@ -391,10 +391,6 @@ func Server(db *bolt.DB, in io.Reader, out io.Writer, closer io.Closer) error {
 			}
 
 			key, value = cursor.First()
-			var addrHash common.Hash
-			copy(addrHash[:], key[:32])
-			fmt.Println(addrHash.String())
-
 			if err := encoder.Encode(&key); err != nil {
 				log.Error("could not encode key in response to CmdCursorFirst", "error", err)
 				return err
@@ -676,10 +672,7 @@ func (b *Bucket) Cursor() *Cursor {
 		cacheKeys:   make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 		cacheValues: make([][]byte, DefaultCursorCacheSize, DefaultCursorCacheSize),
 	}
-	for i := 0; i < len(cursor.cacheKeys); i++ {
-		cursor.cacheKeys[i] = make([]byte, 2*common.HashLength)
-		cursor.cacheValues[i] = make([]byte, 2*common.HashLength)
-	}
+
 	return cursor
 }
 
@@ -780,13 +773,13 @@ func (c *Cursor) fetchPage(cmd Command, numberOfKeys uint64) {
 	var err error
 
 	for c.cacheLastIdx = uint64(0); c.cacheLastIdx < numberOfKeys; c.cacheLastIdx++ {
-		err = decoder.Decode(c.cacheKeys[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheKeys[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode key in response to CmdCursorNext", "error", err)
 			return
 		}
 
-		err = decoder.Decode(c.cacheValues[c.cacheLastIdx])
+		err = decoder.Decode(&c.cacheValues[c.cacheLastIdx])
 		if err != nil {
 			log.Error("could not decode value in response to CmdCursorNext", "error", err)
 			return
diff --git a/node/service.go b/node/service.go
index cd3fc5311..224ef7392 100644
--- a/node/service.go
+++ b/node/service.go
@@ -17,6 +17,7 @@
 package node
 
 import (
+	"context"
 	"reflect"
 
 	"github.com/ledgerwatch/turbo-geth/accounts"
@@ -63,7 +64,11 @@ func (ctx *ServiceContext) OpenDatabase(name string) (ethdb.Database, error) {
 		return nil, err
 	}
 	if ctx.config.RemoteDbListenAddress != "" {
-		go remote.Listener(boltDb.DB(), ctx.config.RemoteDbListenAddress, nil)
+		tcpCtx, cancel := context.WithCancel(context.Background())
+		go remote.Listener(tcpCtx, boltDb.DB(), ctx.config.RemoteDbListenAddress)
+
+		// TODO: call cancel when OS sent signal.
+		_ = cancel
 	}
 	return boltDb, nil
 	/*
