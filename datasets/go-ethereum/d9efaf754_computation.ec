commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
commit d9efaf754c54b5a66f03c68a0c04fbad050e9370
Author: Bas van Kervel <bas@ethdev.com>
Date:   Fri Jul 3 15:44:35 2015 +0200

    simplified implementation and improved performance

diff --git a/rpc/codec/json.go b/rpc/codec/json.go
index a4953a59c..8aa0e6bbf 100644
--- a/rpc/codec/json.go
+++ b/rpc/codec/json.go
@@ -15,129 +15,46 @@ const (
 	MAX_RESPONSE_SIZE = 1024 * 1024
 )
 
-var (
-	// No new requests in buffer
-	EmptyRequestQueueError = fmt.Errorf("No incoming requests")
-	// Next request in buffer isn't yet complete
-	IncompleteRequestError = fmt.Errorf("Request incomplete")
-)
-
 // Json serialization support
 type JsonCodec struct {
-	c                net.Conn
-	reqBuffer        []byte
-	bytesInReqBuffer int
-	reqLastPos       int
+	c net.Conn
+	d *json.Decoder
 }
 
 // Create new JSON coder instance
 func NewJsonCoder(conn net.Conn) ApiCoder {
 	return &JsonCodec{
-		c:                conn,
-		reqBuffer:        make([]byte, MAX_REQUEST_SIZE),
-		bytesInReqBuffer: 0,
-		reqLastPos:       0,
-	}
-}
-
-// Indication if the next request in the buffer is a batch request
-func (self *JsonCodec) isNextBatchReq() (bool, error) {
-	for i := 0; i < self.bytesInReqBuffer; i++ {
-		switch self.reqBuffer[i] {
-		case 0x20, 0x09, 0x0a, 0x0d: // allow leading whitespace (JSON whitespace RFC4627)
-			continue
-		case 0x7b: // single req
-			return false, nil
-		case 0x5b: // batch req
-			return true, nil
-		default:
-			return false, &json.InvalidUnmarshalError{}
-		}
-	}
-
-	return false, EmptyRequestQueueError
-}
-
-// remove parsed request from buffer
-func (self *JsonCodec) resetReqbuffer(pos int) {
-	copy(self.reqBuffer, self.reqBuffer[pos:self.bytesInReqBuffer])
-	self.reqLastPos = 0
-	self.bytesInReqBuffer -= pos
-}
-
-// parse request in buffer
-func (self *JsonCodec) nextRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if isBatch, err := self.isNextBatchReq(); err == nil {
-		if isBatch {
-			requests = make([]*shared.Request, 0)
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &requests); err == nil {
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, true, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		} else {
-			request := shared.Request{}
-			for ; self.reqLastPos <= self.bytesInReqBuffer; self.reqLastPos++ {
-				if err = json.Unmarshal(self.reqBuffer[:self.reqLastPos], &request); err == nil {
-					requests := make([]*shared.Request, 1)
-					requests[0] = &request
-					self.resetReqbuffer(self.reqLastPos)
-					return requests, false, nil
-				}
-			}
-			return nil, true, IncompleteRequestError
-		}
-	} else {
-		return nil, false, err
+		c: conn,
+		d: json.NewDecoder(conn),
 	}
 }
 
-// Serialize obj to JSON and write it to conn
+// Read incoming request and parse it to RPC request
 func (self *JsonCodec) ReadRequest() (requests []*shared.Request, isBatch bool, err error) {
-	if self.bytesInReqBuffer != 0 {
-		req, batch, err := self.nextRequest()
-		if err == nil {
-			return req, batch, err
-		}
-
-		if err != IncompleteRequestError {
-			return nil, false, err
-		}
-	}
-
-	// no/incomplete request in buffer -> read more data first
 	deadline := time.Now().Add(READ_TIMEOUT * time.Second)
 	if err := self.c.SetDeadline(deadline); err != nil {
 		return nil, false, err
 	}
 
-	var retErr error
-	for {
-		n, err := self.c.Read(self.reqBuffer[self.bytesInReqBuffer:])
-		if err != nil {
-			retErr = err
-			break
-		}
-
-		self.bytesInReqBuffer += n
-
-		requests, isBatch, err := self.nextRequest()
-		if err == nil {
-			return requests, isBatch, nil
-		}
-
-		if err == IncompleteRequestError || err == EmptyRequestQueueError {
-			continue // need more data
+	var incoming json.RawMessage
+	err = self.d.Decode(&incoming)
+	if err == nil {
+		isBatch = incoming[0] == '['
+		if isBatch {
+			requests = make([]*shared.Request, 0)
+			err = json.Unmarshal(incoming, &requests)
+		} else {
+			requests = make([]*shared.Request, 1)
+			var singleRequest shared.Request
+			if err = json.Unmarshal(incoming, &singleRequest); err == nil {
+				requests[0] = &singleRequest
+			}
 		}
-
-		retErr = err
-		break
+		return
 	}
 
 	self.c.Close()
-	return nil, false, retErr
+	return nil, false, err
 }
 
 func (self *JsonCodec) ReadResponse() (interface{}, error) {
