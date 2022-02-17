commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
commit a84230d45c45e3a42444a526c133948184bda676
Author: b00ris <b00ris@mail.ru>
Date:   Sat Aug 1 19:18:31 2020 +0400

    fix streams leak (#847)

diff --git a/ethdb/kv_remote2.go b/ethdb/kv_remote2.go
index e6e7a7ecb..33a4afc60 100644
--- a/ethdb/kv_remote2.go
+++ b/ethdb/kv_remote2.go
@@ -38,7 +38,7 @@ type Remote2KV struct {
 type remote2Tx struct {
 	ctx     context.Context
 	db      *Remote2KV
-	cursors []remote2Cursor
+	cursors []*remote2Cursor
 }
 
 type remote2Bucket struct {
@@ -204,7 +204,17 @@ func (b *remote2Bucket) Clear() error {
 }
 
 func (b *remote2Bucket) Get(key []byte) (val []byte, err error) {
-	k, v, err := b.Cursor().Seek(key)
+	c := b.Cursor()
+	defer func() {
+		if v, ok := c.(*remote2Cursor); ok {
+			if v.stream == nil {
+				return
+			}
+			_ = v.stream.CloseSend()
+		}
+	}()
+
+	k, v, err := c.Seek(key)
 	if err != nil {
 		fmt.Printf("errr3: %s\n", err)
 		return nil, err
@@ -224,7 +234,9 @@ func (b *remote2Bucket) Delete(key []byte) error {
 }
 
 func (b *remote2Bucket) Cursor() Cursor {
-	return &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	c := &remote2Cursor{bucket: b, ctx: b.tx.ctx}
+	b.tx.cursors = append(b.tx.cursors, c)
+	return c
 }
 
 func (c *remote2Cursor) Put(key []byte, value []byte) error {
diff --git a/ethdb/remote/remotedbserver/server2.go b/ethdb/remote/remotedbserver/server2.go
index aac7f00ce..0eaebbd74 100644
--- a/ethdb/remote/remotedbserver/server2.go
+++ b/ethdb/remote/remotedbserver/server2.go
@@ -47,10 +47,10 @@ func StartGrpc(kv ethdb.KV, addr string) {
 	unaryInterceptors = append(unaryInterceptors, grpc_recovery.UnaryServerInterceptor())
 
 	grpcServer := grpc.NewServer(
-		grpc.NumStreamWorkers(2),   // reduce amount of goroutines
+		grpc.NumStreamWorkers(20),  // reduce amount of goroutines
 		grpc.WriteBufferSize(1024), // reduce buffers to save mem
 		grpc.ReadBufferSize(1024),
-		grpc.MaxConcurrentStreams(16), // to force clients reduce concurency level
+		grpc.MaxConcurrentStreams(40), // to force clients reduce concurency level
 		grpc.StreamInterceptor(grpc_middleware.ChainStreamServer(streamInterceptors...)),
 		grpc.UnaryInterceptor(grpc_middleware.ChainUnaryServer(unaryInterceptors...)),
 	)
