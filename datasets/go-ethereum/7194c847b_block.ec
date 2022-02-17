commit 7194c847b6e7f545f2aad57d8eae0a046e08d7a4
Author: Felix Lange <fjl@twurst.com>
Date:   Thu May 27 10:19:13 2021 +0200

    p2p/rlpx: reduce allocation and syscalls (#22899)
    
    This change significantly improves the performance of RLPx message reads
    and writes. In the previous implementation, reading and writing of
    message frames performed multiple reads and writes on the underlying
    network connection, and allocated a new []byte buffer for every read.
    
    In the new implementation, reads and writes re-use buffers, and perform
    much fewer system calls on the underlying connection. This doubles the
    theoretically achievable throughput on a single connection, as shown by
    the benchmark result:
    
        name             old speed      new speed       delta
        Throughput-8     70.3MB/s ± 0%  155.4MB/s ± 0%  +121.11%  (p=0.000 n=9+8)
    
    The change also removes support for the legacy, pre-EIP-8 handshake encoding.
    As of May 2021, no actively maintained client sends this format.

diff --git a/p2p/rlpx/buffer.go b/p2p/rlpx/buffer.go
new file mode 100644
index 000000000..bb38e1057
--- /dev/null
+++ b/p2p/rlpx/buffer.go
@@ -0,0 +1,127 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package rlpx
+
+import (
+	"io"
+)
+
+// readBuffer implements buffering for network reads. This type is similar to bufio.Reader,
+// with two crucial differences: the buffer slice is exposed, and the buffer keeps all
+// read data available until reset.
+//
+// How to use this type:
+//
+// Keep a readBuffer b alongside the underlying network connection. When reading a packet
+// from the connection, first call b.reset(). This empties b.data. Now perform reads
+// through b.read() until the end of the packet is reached. The complete packet data is
+// now available in b.data.
+type readBuffer struct {
+	data []byte
+	end  int
+}
+
+// reset removes all processed data which was read since the last call to reset.
+// After reset, len(b.data) is zero.
+func (b *readBuffer) reset() {
+	unprocessed := b.end - len(b.data)
+	copy(b.data[:unprocessed], b.data[len(b.data):b.end])
+	b.end = unprocessed
+	b.data = b.data[:0]
+}
+
+// read reads at least n bytes from r, returning the bytes.
+// The returned slice is valid until the next call to reset.
+func (b *readBuffer) read(r io.Reader, n int) ([]byte, error) {
+	offset := len(b.data)
+	have := b.end - len(b.data)
+
+	// If n bytes are available in the buffer, there is no need to read from r at all.
+	if have >= n {
+		b.data = b.data[:offset+n]
+		return b.data[offset : offset+n], nil
+	}
+
+	// Make buffer space available.
+	need := n - have
+	b.grow(need)
+
+	// Read.
+	rn, err := io.ReadAtLeast(r, b.data[b.end:cap(b.data)], need)
+	if err != nil {
+		return nil, err
+	}
+	b.end += rn
+	b.data = b.data[:offset+n]
+	return b.data[offset : offset+n], nil
+}
+
+// grow ensures the buffer has at least n bytes of unused space.
+func (b *readBuffer) grow(n int) {
+	if cap(b.data)-b.end >= n {
+		return
+	}
+	need := n - (cap(b.data) - b.end)
+	offset := len(b.data)
+	b.data = append(b.data[:cap(b.data)], make([]byte, need)...)
+	b.data = b.data[:offset]
+}
+
+// writeBuffer implements buffering for network writes. This is essentially
+// a convenience wrapper around a byte slice.
+type writeBuffer struct {
+	data []byte
+}
+
+func (b *writeBuffer) reset() {
+	b.data = b.data[:0]
+}
+
+func (b *writeBuffer) appendZero(n int) []byte {
+	offset := len(b.data)
+	b.data = append(b.data, make([]byte, n)...)
+	return b.data[offset : offset+n]
+}
+
+func (b *writeBuffer) Write(data []byte) (int, error) {
+	b.data = append(b.data, data...)
+	return len(data), nil
+}
+
+const maxUint24 = int(^uint32(0) >> 8)
+
+func readUint24(b []byte) uint32 {
+	return uint32(b[2]) | uint32(b[1])<<8 | uint32(b[0])<<16
+}
+
+func putUint24(v uint32, b []byte) {
+	b[0] = byte(v >> 16)
+	b[1] = byte(v >> 8)
+	b[2] = byte(v)
+}
+
+// growslice ensures b has the wanted length by either expanding it to its capacity
+// or allocating a new slice if b has insufficient capacity.
+func growslice(b []byte, wantLength int) []byte {
+	if len(b) >= wantLength {
+		return b
+	}
+	if cap(b) >= wantLength {
+		return b[:cap(b)]
+	}
+	return make([]byte, wantLength)
+}
diff --git a/p2p/rlpx/buffer_test.go b/p2p/rlpx/buffer_test.go
new file mode 100644
index 000000000..9fee4172b
--- /dev/null
+++ b/p2p/rlpx/buffer_test.go
@@ -0,0 +1,51 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package rlpx
+
+import (
+	"bytes"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common/hexutil"
+	"github.com/stretchr/testify/assert"
+)
+
+func TestReadBufferReset(t *testing.T) {
+	reader := bytes.NewReader(hexutil.MustDecode("0x010202030303040505"))
+	var b readBuffer
+
+	s1, _ := b.read(reader, 1)
+	s2, _ := b.read(reader, 2)
+	s3, _ := b.read(reader, 3)
+
+	assert.Equal(t, []byte{1}, s1)
+	assert.Equal(t, []byte{2, 2}, s2)
+	assert.Equal(t, []byte{3, 3, 3}, s3)
+
+	b.reset()
+
+	s4, _ := b.read(reader, 1)
+	s5, _ := b.read(reader, 2)
+
+	assert.Equal(t, []byte{4}, s4)
+	assert.Equal(t, []byte{5, 5}, s5)
+
+	s6, err := b.read(reader, 2)
+
+	assert.EqualError(t, err, "EOF")
+	assert.Nil(t, s6)
+}
diff --git a/p2p/rlpx/rlpx.go b/p2p/rlpx/rlpx.go
index 2021bf08b..326c7c494 100644
--- a/p2p/rlpx/rlpx.go
+++ b/p2p/rlpx/rlpx.go
@@ -48,19 +48,45 @@ import (
 // This type is not generally safe for concurrent use, but reading and writing of messages
 // may happen concurrently after the handshake.
 type Conn struct {
-	dialDest  *ecdsa.PublicKey
-	conn      net.Conn
-	handshake *handshakeState
-	snappy    bool
+	dialDest *ecdsa.PublicKey
+	conn     net.Conn
+	session  *sessionState
+
+	// These are the buffers for snappy compression.
+	// Compression is enabled if they are non-nil.
+	snappyReadBuffer  []byte
+	snappyWriteBuffer []byte
 }
 
-type handshakeState struct {
+// sessionState contains the session keys.
+type sessionState struct {
 	enc cipher.Stream
 	dec cipher.Stream
 
-	macCipher  cipher.Block
-	egressMAC  hash.Hash
-	ingressMAC hash.Hash
+	egressMAC  hashMAC
+	ingressMAC hashMAC
+	rbuf       readBuffer
+	wbuf       writeBuffer
+}
+
+// hashMAC holds the state of the RLPx v4 MAC contraption.
+type hashMAC struct {
+	cipher     cipher.Block
+	hash       hash.Hash
+	aesBuffer  [16]byte
+	hashBuffer [32]byte
+	seedBuffer [32]byte
+}
+
+func newHashMAC(cipher cipher.Block, h hash.Hash) hashMAC {
+	m := hashMAC{cipher: cipher, hash: h}
+	if cipher.BlockSize() != len(m.aesBuffer) {
+		panic(fmt.Errorf("invalid MAC cipher block size %d", cipher.BlockSize()))
+	}
+	if h.Size() != len(m.hashBuffer) {
+		panic(fmt.Errorf("invalid MAC digest size %d", h.Size()))
+	}
+	return m
 }
 
 // NewConn wraps the given network connection. If dialDest is non-nil, the connection
@@ -76,7 +102,13 @@ func NewConn(conn net.Conn, dialDest *ecdsa.PublicKey) *Conn {
 // after the devp2p Hello message exchange when the negotiated version indicates that
 // compression is available on both ends of the connection.
 func (c *Conn) SetSnappy(snappy bool) {
-	c.snappy = snappy
+	if snappy {
+		c.snappyReadBuffer = []byte{}
+		c.snappyWriteBuffer = []byte{}
+	} else {
+		c.snappyReadBuffer = nil
+		c.snappyWriteBuffer = nil
+	}
 }
 
 // SetReadDeadline sets the deadline for all future read operations.
@@ -95,12 +127,13 @@ func (c *Conn) SetDeadline(time time.Time) error {
 }
 
 // Read reads a message from the connection.
+// The returned data buffer is valid until the next call to Read.
 func (c *Conn) Read() (code uint64, data []byte, wireSize int, err error) {
-	if c.handshake == nil {
+	if c.session == nil {
 		panic("can't ReadMsg before handshake")
 	}
 
-	frame, err := c.handshake.readFrame(c.conn)
+	frame, err := c.session.readFrame(c.conn)
 	if err != nil {
 		return 0, nil, 0, err
 	}
@@ -111,7 +144,7 @@ func (c *Conn) Read() (code uint64, data []byte, wireSize int, err error) {
 	wireSize = len(data)
 
 	// If snappy is enabled, verify and decompress message.
-	if c.snappy {
+	if c.snappyReadBuffer != nil {
 		var actualSize int
 		actualSize, err = snappy.DecodedLen(data)
 		if err != nil {
@@ -120,51 +153,55 @@ func (c *Conn) Read() (code uint64, data []byte, wireSize int, err error) {
 		if actualSize > maxUint24 {
 			return code, nil, 0, errPlainMessageTooLarge
 		}
-		data, err = snappy.Decode(nil, data)
+		c.snappyReadBuffer = growslice(c.snappyReadBuffer, actualSize)
+		data, err = snappy.Decode(c.snappyReadBuffer, data)
 	}
 	return code, data, wireSize, err
 }
 
-func (h *handshakeState) readFrame(conn io.Reader) ([]byte, error) {
-	// read the header
-	headbuf := make([]byte, 32)
-	if _, err := io.ReadFull(conn, headbuf); err != nil {
+func (h *sessionState) readFrame(conn io.Reader) ([]byte, error) {
+	h.rbuf.reset()
+
+	// Read the frame header.
+	header, err := h.rbuf.read(conn, 32)
+	if err != nil {
 		return nil, err
 	}
 
-	// verify header mac
-	shouldMAC := updateMAC(h.ingressMAC, h.macCipher, headbuf[:16])
-	if !hmac.Equal(shouldMAC, headbuf[16:]) {
+	// Verify header MAC.
+	wantHeaderMAC := h.ingressMAC.computeHeader(header[:16])
+	if !hmac.Equal(wantHeaderMAC, header[16:]) {
 		return nil, errors.New("bad header MAC")
 	}
-	h.dec.XORKeyStream(headbuf[:16], headbuf[:16]) // first half is now decrypted
-	fsize := readInt24(headbuf)
-	// ignore protocol type for now
 
-	// read the frame content
-	var rsize = fsize // frame size rounded up to 16 byte boundary
+	// Decrypt the frame header to get the frame size.
+	h.dec.XORKeyStream(header[:16], header[:16])
+	fsize := readUint24(header[:16])
+	// Frame size rounded up to 16 byte boundary for padding.
+	rsize := fsize
 	if padding := fsize % 16; padding > 0 {
 		rsize += 16 - padding
 	}
-	framebuf := make([]byte, rsize)
-	if _, err := io.ReadFull(conn, framebuf); err != nil {
+
+	// Read the frame content.
+	frame, err := h.rbuf.read(conn, int(rsize))
+	if err != nil {
 		return nil, err
 	}
 
-	// read and validate frame MAC. we can re-use headbuf for that.
-	h.ingressMAC.Write(framebuf)
-	fmacseed := h.ingressMAC.Sum(nil)
-	if _, err := io.ReadFull(conn, headbuf[:16]); err != nil {
+	// Validate frame MAC.
+	frameMAC, err := h.rbuf.read(conn, 16)
+	if err != nil {
 		return nil, err
 	}
-	shouldMAC = updateMAC(h.ingressMAC, h.macCipher, fmacseed)
-	if !hmac.Equal(shouldMAC, headbuf[:16]) {
+	wantFrameMAC := h.ingressMAC.computeFrame(frame)
+	if !hmac.Equal(wantFrameMAC, frameMAC) {
 		return nil, errors.New("bad frame MAC")
 	}
 
-	// decrypt frame content
-	h.dec.XORKeyStream(framebuf, framebuf)
-	return framebuf[:fsize], nil
+	// Decrypt the frame data.
+	h.dec.XORKeyStream(frame, frame)
+	return frame[:fsize], nil
 }
 
 // Write writes a message to the connection.
@@ -172,83 +209,90 @@ func (h *handshakeState) readFrame(conn io.Reader) ([]byte, error) {
 // Write returns the written size of the message data. This may be less than or equal to
 // len(data) depending on whether snappy compression is enabled.
 func (c *Conn) Write(code uint64, data []byte) (uint32, error) {
-	if c.handshake == nil {
+	if c.session == nil {
 		panic("can't WriteMsg before handshake")
 	}
 	if len(data) > maxUint24 {
 		return 0, errPlainMessageTooLarge
 	}
-	if c.snappy {
-		data = snappy.Encode(nil, data)
+	if c.snappyWriteBuffer != nil {
+		// Ensure the buffer has sufficient size.
+		// Package snappy will allocate its own buffer if the provided
+		// one is smaller than MaxEncodedLen.
+		c.snappyWriteBuffer = growslice(c.snappyWriteBuffer, snappy.MaxEncodedLen(len(data)))
+		data = snappy.Encode(c.snappyWriteBuffer, data)
 	}
 
 	wireSize := uint32(len(data))
-	err := c.handshake.writeFrame(c.conn, code, data)
+	err := c.session.writeFrame(c.conn, code, data)
 	return wireSize, err
 }
 
-func (h *handshakeState) writeFrame(conn io.Writer, code uint64, data []byte) error {
-	ptype, _ := rlp.EncodeToBytes(code)
+func (h *sessionState) writeFrame(conn io.Writer, code uint64, data []byte) error {
+	h.wbuf.reset()
 
-	// write header
-	headbuf := make([]byte, 32)
-	fsize := len(ptype) + len(data)
+	// Write header.
+	fsize := rlp.IntSize(code) + len(data)
 	if fsize > maxUint24 {
 		return errPlainMessageTooLarge
 	}
-	putInt24(uint32(fsize), headbuf)
-	copy(headbuf[3:], zeroHeader)
-	h.enc.XORKeyStream(headbuf[:16], headbuf[:16]) // first half is now encrypted
+	header := h.wbuf.appendZero(16)
+	putUint24(uint32(fsize), header)
+	copy(header[3:], zeroHeader)
+	h.enc.XORKeyStream(header, header)
 
-	// write header MAC
-	copy(headbuf[16:], updateMAC(h.egressMAC, h.macCipher, headbuf[:16]))
-	if _, err := conn.Write(headbuf); err != nil {
-		return err
-	}
+	// Write header MAC.
+	h.wbuf.Write(h.egressMAC.computeHeader(header))
 
-	// write encrypted frame, updating the egress MAC hash with
-	// the data written to conn.
-	tee := cipher.StreamWriter{S: h.enc, W: io.MultiWriter(conn, h.egressMAC)}
-	if _, err := tee.Write(ptype); err != nil {
-		return err
-	}
-	if _, err := tee.Write(data); err != nil {
-		return err
-	}
+	// Encode and encrypt the frame data.
+	offset := len(h.wbuf.data)
+	h.wbuf.data = rlp.AppendUint64(h.wbuf.data, code)
+	h.wbuf.Write(data)
 	if padding := fsize % 16; padding > 0 {
-		if _, err := tee.Write(zero16[:16-padding]); err != nil {
-			return err
-		}
+		h.wbuf.appendZero(16 - padding)
 	}
+	framedata := h.wbuf.data[offset:]
+	h.enc.XORKeyStream(framedata, framedata)
 
-	// write frame MAC. egress MAC hash is up to date because
-	// frame content was written to it as well.
-	fmacseed := h.egressMAC.Sum(nil)
-	mac := updateMAC(h.egressMAC, h.macCipher, fmacseed)
-	_, err := conn.Write(mac)
+	// Write frame MAC.
+	h.wbuf.Write(h.egressMAC.computeFrame(framedata))
+
+	_, err := conn.Write(h.wbuf.data)
 	return err
 }
 
-func readInt24(b []byte) uint32 {
-	return uint32(b[2]) | uint32(b[1])<<8 | uint32(b[0])<<16
+// computeHeader computes the MAC of a frame header.
+func (m *hashMAC) computeHeader(header []byte) []byte {
+	sum1 := m.hash.Sum(m.hashBuffer[:0])
+	return m.compute(sum1, header)
 }
 
-func putInt24(v uint32, b []byte) {
-	b[0] = byte(v >> 16)
-	b[1] = byte(v >> 8)
-	b[2] = byte(v)
+// computeFrame computes the MAC of framedata.
+func (m *hashMAC) computeFrame(framedata []byte) []byte {
+	m.hash.Write(framedata)
+	seed := m.hash.Sum(m.seedBuffer[:0])
+	return m.compute(seed, seed[:16])
 }
 
-// updateMAC reseeds the given hash with encrypted seed.
-// it returns the first 16 bytes of the hash sum after seeding.
-func updateMAC(mac hash.Hash, block cipher.Block, seed []byte) []byte {
-	aesbuf := make([]byte, aes.BlockSize)
-	block.Encrypt(aesbuf, mac.Sum(nil))
-	for i := range aesbuf {
-		aesbuf[i] ^= seed[i]
+// compute computes the MAC of a 16-byte 'seed'.
+//
+// To do this, it encrypts the current value of the hash state, then XORs the ciphertext
+// with seed. The obtained value is written back into the hash state and hash output is
+// taken again. The first 16 bytes of the resulting sum are the MAC value.
+//
+// This MAC construction is a horrible, legacy thing.
+func (m *hashMAC) compute(sum1, seed []byte) []byte {
+	if len(seed) != len(m.aesBuffer) {
+		panic("invalid MAC seed")
+	}
+
+	m.cipher.Encrypt(m.aesBuffer[:], sum1)
+	for i := range m.aesBuffer {
+		m.aesBuffer[i] ^= seed[i]
 	}
-	mac.Write(aesbuf)
-	return mac.Sum(nil)[:16]
+	m.hash.Write(m.aesBuffer[:])
+	sum2 := m.hash.Sum(m.hashBuffer[:0])
+	return sum2[:16]
 }
 
 // Handshake performs the handshake. This must be called before any data is written
@@ -257,23 +301,26 @@ func (c *Conn) Handshake(prv *ecdsa.PrivateKey) (*ecdsa.PublicKey, error) {
 	var (
 		sec Secrets
 		err error
+		h   handshakeState
 	)
 	if c.dialDest != nil {
-		sec, err = initiatorEncHandshake(c.conn, prv, c.dialDest)
+		sec, err = h.runInitiator(c.conn, prv, c.dialDest)
 	} else {
-		sec, err = receiverEncHandshake(c.conn, prv)
+		sec, err = h.runRecipient(c.conn, prv)
 	}
 	if err != nil {
 		return nil, err
 	}
 	c.InitWithSecrets(sec)
+	c.session.rbuf = h.rbuf
+	c.session.wbuf = h.wbuf
 	return sec.remote, err
 }
 
 // InitWithSecrets injects connection secrets as if a handshake had
 // been performed. This cannot be called after the handshake.
 func (c *Conn) InitWithSecrets(sec Secrets) {
-	if c.handshake != nil {
+	if c.session != nil {
 		panic("can't handshake twice")
 	}
 	macc, err := aes.NewCipher(sec.MAC)
@@ -287,12 +334,11 @@ func (c *Conn) InitWithSecrets(sec Secrets) {
 	// we use an all-zeroes IV for AES because the key used
 	// for encryption is ephemeral.
 	iv := make([]byte, encc.BlockSize())
-	c.handshake = &handshakeState{
+	c.session = &sessionState{
 		enc:        cipher.NewCTR(encc, iv),
 		dec:        cipher.NewCTR(encc, iv),
-		macCipher:  macc,
-		egressMAC:  sec.EgressMAC,
-		ingressMAC: sec.IngressMAC,
+		egressMAC:  newHashMAC(macc, sec.EgressMAC),
+		ingressMAC: newHashMAC(macc, sec.IngressMAC),
 	}
 }
 
@@ -303,28 +349,18 @@ func (c *Conn) Close() error {
 
 // Constants for the handshake.
 const (
-	maxUint24 = int(^uint32(0) >> 8)
-
 	sskLen = 16                     // ecies.MaxSharedKeyLength(pubKey) / 2
 	sigLen = crypto.SignatureLength // elliptic S256
 	pubLen = 64                     // 512 bit pubkey in uncompressed representation without format byte
 	shaLen = 32                     // hash length (for nonce etc)
 
-	authMsgLen  = sigLen + shaLen + pubLen + shaLen + 1
-	authRespLen = pubLen + shaLen + 1
-
 	eciesOverhead = 65 /* pubkey */ + 16 /* IV */ + 32 /* MAC */
-
-	encAuthMsgLen  = authMsgLen + eciesOverhead  // size of encrypted pre-EIP-8 initiator handshake
-	encAuthRespLen = authRespLen + eciesOverhead // size of encrypted pre-EIP-8 handshake reply
 )
 
 var (
 	// this is used in place of actual frame header data.
 	// TODO: replace this when Msg contains the protocol type code.
 	zeroHeader = []byte{0xC2, 0x80, 0x80}
-	// sixteen zero bytes
-	zero16 = make([]byte, 16)
 
 	// errPlainMessageTooLarge is returned if a decompressed message length exceeds
 	// the allowed 24 bits (i.e. length >= 16MB).
@@ -338,19 +374,20 @@ type Secrets struct {
 	remote                *ecdsa.PublicKey
 }
 
-// encHandshake contains the state of the encryption handshake.
-type encHandshake struct {
+// handshakeState contains the state of the encryption handshake.
+type handshakeState struct {
 	initiator            bool
 	remote               *ecies.PublicKey  // remote-pubk
 	initNonce, respNonce []byte            // nonce
 	randomPrivKey        *ecies.PrivateKey // ecdhe-random
 	remoteRandomPub      *ecies.PublicKey  // ecdhe-random-pubk
+
+	rbuf readBuffer
+	wbuf writeBuffer
 }
 
 // RLPx v4 handshake auth (defined in EIP-8).
 type authMsgV4 struct {
-	gotPlain bool // whether read packet had plain format.
-
 	Signature       [sigLen]byte
 	InitiatorPubkey [pubLen]byte
 	Nonce           [shaLen]byte
@@ -370,17 +407,16 @@ type authRespV4 struct {
 	Rest []rlp.RawValue `rlp:"tail"`
 }
 
-// receiverEncHandshake negotiates a session token on conn.
+// runRecipient negotiates a session token on conn.
 // it should be called on the listening side of the connection.
 //
 // prv is the local client's private key.
-func receiverEncHandshake(conn io.ReadWriter, prv *ecdsa.PrivateKey) (s Secrets, err error) {
+func (h *handshakeState) runRecipient(conn io.ReadWriter, prv *ecdsa.PrivateKey) (s Secrets, err error) {
 	authMsg := new(authMsgV4)
-	authPacket, err := readHandshakeMsg(authMsg, encAuthMsgLen, prv, conn)
+	authPacket, err := h.readMsg(authMsg, prv, conn)
 	if err != nil {
 		return s, err
 	}
-	h := new(encHandshake)
 	if err := h.handleAuthMsg(authMsg, prv); err != nil {
 		return s, err
 	}
@@ -389,22 +425,18 @@ func receiverEncHandshake(conn io.ReadWriter, prv *ecdsa.PrivateKey) (s Secrets,
 	if err != nil {
 		return s, err
 	}
-	var authRespPacket []byte
-	if authMsg.gotPlain {
-		authRespPacket, err = authRespMsg.sealPlain(h)
-	} else {
-		authRespPacket, err = sealEIP8(authRespMsg, h)
-	}
+	authRespPacket, err := h.sealEIP8(authRespMsg)
 	if err != nil {
 		return s, err
 	}
 	if _, err = conn.Write(authRespPacket); err != nil {
 		return s, err
 	}
+
 	return h.secrets(authPacket, authRespPacket)
 }
 
-func (h *encHandshake) handleAuthMsg(msg *authMsgV4, prv *ecdsa.PrivateKey) error {
+func (h *handshakeState) handleAuthMsg(msg *authMsgV4, prv *ecdsa.PrivateKey) error {
 	// Import the remote identity.
 	rpub, err := importPublicKey(msg.InitiatorPubkey[:])
 	if err != nil {
@@ -438,7 +470,7 @@ func (h *encHandshake) handleAuthMsg(msg *authMsgV4, prv *ecdsa.PrivateKey) erro
 
 // secrets is called after the handshake is completed.
 // It extracts the connection secrets from the handshake values.
-func (h *encHandshake) secrets(auth, authResp []byte) (Secrets, error) {
+func (h *handshakeState) secrets(auth, authResp []byte) (Secrets, error) {
 	ecdheSecret, err := h.randomPrivKey.GenerateShared(h.remoteRandomPub, sskLen, sskLen)
 	if err != nil {
 		return Secrets{}, err
@@ -471,21 +503,23 @@ func (h *encHandshake) secrets(auth, authResp []byte) (Secrets, error) {
 
 // staticSharedSecret returns the static shared secret, the result
 // of key agreement between the local and remote static node key.
-func (h *encHandshake) staticSharedSecret(prv *ecdsa.PrivateKey) ([]byte, error) {
+func (h *handshakeState) staticSharedSecret(prv *ecdsa.PrivateKey) ([]byte, error) {
 	return ecies.ImportECDSA(prv).GenerateShared(h.remote, sskLen, sskLen)
 }
 
-// initiatorEncHandshake negotiates a session token on conn.
+// runInitiator negotiates a session token on conn.
 // it should be called on the dialing side of the connection.
 //
 // prv is the local client's private key.
-func initiatorEncHandshake(conn io.ReadWriter, prv *ecdsa.PrivateKey, remote *ecdsa.PublicKey) (s Secrets, err error) {
-	h := &encHandshake{initiator: true, remote: ecies.ImportECDSAPublic(remote)}
+func (h *handshakeState) runInitiator(conn io.ReadWriter, prv *ecdsa.PrivateKey, remote *ecdsa.PublicKey) (s Secrets, err error) {
+	h.initiator = true
+	h.remote = ecies.ImportECDSAPublic(remote)
+
 	authMsg, err := h.makeAuthMsg(prv)
 	if err != nil {
 		return s, err
 	}
-	authPacket, err := sealEIP8(authMsg, h)
+	authPacket, err := h.sealEIP8(authMsg)
 	if err != nil {
 		return s, err
 	}
@@ -495,18 +529,19 @@ func initiatorEncHandshake(conn io.ReadWriter, prv *ecdsa.PrivateKey, remote *ec
 	}
 
 	authRespMsg := new(authRespV4)
-	authRespPacket, err := readHandshakeMsg(authRespMsg, encAuthRespLen, prv, conn)
+	authRespPacket, err := h.readMsg(authRespMsg, prv, conn)
 	if err != nil {
 		return s, err
 	}
 	if err := h.handleAuthResp(authRespMsg); err != nil {
 		return s, err
 	}
+
 	return h.secrets(authPacket, authRespPacket)
 }
 
 // makeAuthMsg creates the initiator handshake message.
-func (h *encHandshake) makeAuthMsg(prv *ecdsa.PrivateKey) (*authMsgV4, error) {
+func (h *handshakeState) makeAuthMsg(prv *ecdsa.PrivateKey) (*authMsgV4, error) {
 	// Generate random initiator nonce.
 	h.initNonce = make([]byte, shaLen)
 	_, err := rand.Read(h.initNonce)
@@ -538,13 +573,13 @@ func (h *encHandshake) makeAuthMsg(prv *ecdsa.PrivateKey) (*authMsgV4, error) {
 	return msg, nil
 }
 
-func (h *encHandshake) handleAuthResp(msg *authRespV4) (err error) {
+func (h *handshakeState) handleAuthResp(msg *authRespV4) (err error) {
 	h.respNonce = msg.Nonce[:]
 	h.remoteRandomPub, err = importPublicKey(msg.RandomPubkey[:])
 	return err
 }
 
-func (h *encHandshake) makeAuthResp() (msg *authRespV4, err error) {
+func (h *handshakeState) makeAuthResp() (msg *authRespV4, err error) {
 	// Generate random nonce.
 	h.respNonce = make([]byte, shaLen)
 	if _, err = rand.Read(h.respNonce); err != nil {
@@ -558,81 +593,53 @@ func (h *encHandshake) makeAuthResp() (msg *authRespV4, err error) {
 	return msg, nil
 }
 
-func (msg *authMsgV4) decodePlain(input []byte) {
-	n := copy(msg.Signature[:], input)
-	n += shaLen // skip sha3(initiator-ephemeral-pubk)
-	n += copy(msg.InitiatorPubkey[:], input[n:])
-	copy(msg.Nonce[:], input[n:])
-	msg.Version = 4
-	msg.gotPlain = true
-}
+// readMsg reads an encrypted handshake message, decoding it into msg.
+func (h *handshakeState) readMsg(msg interface{}, prv *ecdsa.PrivateKey, r io.Reader) ([]byte, error) {
+	h.rbuf.reset()
+	h.rbuf.grow(512)
 
-func (msg *authRespV4) sealPlain(hs *encHandshake) ([]byte, error) {
-	buf := make([]byte, authRespLen)
-	n := copy(buf, msg.RandomPubkey[:])
-	copy(buf[n:], msg.Nonce[:])
-	return ecies.Encrypt(rand.Reader, hs.remote, buf, nil, nil)
-}
+	// Read the size prefix.
+	prefix, err := h.rbuf.read(r, 2)
+	if err != nil {
+		return nil, err
+	}
+	size := binary.BigEndian.Uint16(prefix)
 
-func (msg *authRespV4) decodePlain(input []byte) {
-	n := copy(msg.RandomPubkey[:], input)
-	copy(msg.Nonce[:], input[n:])
-	msg.Version = 4
+	// Read the handshake packet.
+	packet, err := h.rbuf.read(r, int(size))
+	if err != nil {
+		return nil, err
+	}
+	dec, err := ecies.ImportECDSA(prv).Decrypt(packet, nil, prefix)
+	if err != nil {
+		return nil, err
+	}
+	// Can't use rlp.DecodeBytes here because it rejects
+	// trailing data (forward-compatibility).
+	s := rlp.NewStream(bytes.NewReader(dec), 0)
+	err = s.Decode(msg)
+	return h.rbuf.data[:len(prefix)+len(packet)], err
 }
 
-var padSpace = make([]byte, 300)
+// sealEIP8 encrypts a handshake message.
+func (h *handshakeState) sealEIP8(msg interface{}) ([]byte, error) {
+	h.wbuf.reset()
 
-func sealEIP8(msg interface{}, h *encHandshake) ([]byte, error) {
-	buf := new(bytes.Buffer)
-	if err := rlp.Encode(buf, msg); err != nil {
+	// Write the message plaintext.
+	if err := rlp.Encode(&h.wbuf, msg); err != nil {
 		return nil, err
 	}
-	// pad with random amount of data. the amount needs to be at least 100 bytes to make
+	// Pad with random amount of data. the amount needs to be at least 100 bytes to make
 	// the message distinguishable from pre-EIP-8 handshakes.
-	pad := padSpace[:mrand.Intn(len(padSpace)-100)+100]
-	buf.Write(pad)
+	h.wbuf.appendZero(mrand.Intn(100) + 100)
+
 	prefix := make([]byte, 2)
-	binary.BigEndian.PutUint16(prefix, uint16(buf.Len()+eciesOverhead))
+	binary.BigEndian.PutUint16(prefix, uint16(len(h.wbuf.data)+eciesOverhead))
 
-	enc, err := ecies.Encrypt(rand.Reader, h.remote, buf.Bytes(), nil, prefix)
+	enc, err := ecies.Encrypt(rand.Reader, h.remote, h.wbuf.data, nil, prefix)
 	return append(prefix, enc...), err
 }
 
-type plainDecoder interface {
-	decodePlain([]byte)
-}
-
-func readHandshakeMsg(msg plainDecoder, plainSize int, prv *ecdsa.PrivateKey, r io.Reader) ([]byte, error) {
-	buf := make([]byte, plainSize)
-	if _, err := io.ReadFull(r, buf); err != nil {
-		return buf, err
-	}
-	// Attempt decoding pre-EIP-8 "plain" format.
-	key := ecies.ImportECDSA(prv)
-	if dec, err := key.Decrypt(buf, nil, nil); err == nil {
-		msg.decodePlain(dec)
-		return buf, nil
-	}
-	// Could be EIP-8 format, try that.
-	prefix := buf[:2]
-	size := binary.BigEndian.Uint16(prefix)
-	if size < uint16(plainSize) {
-		return buf, fmt.Errorf("size underflow, need at least %d bytes", plainSize)
-	}
-	buf = append(buf, make([]byte, size-uint16(plainSize)+2)...)
-	if _, err := io.ReadFull(r, buf[plainSize:]); err != nil {
-		return buf, err
-	}
-	dec, err := key.Decrypt(buf[2:], nil, prefix)
-	if err != nil {
-		return buf, err
-	}
-	// Can't use rlp.DecodeBytes here because it rejects
-	// trailing data (forward-compatibility).
-	s := rlp.NewStream(bytes.NewReader(dec), 0)
-	return buf, s.Decode(msg)
-}
-
 // importPublicKey unmarshals 512 bit public keys.
 func importPublicKey(pubKey []byte) (*ecies.PublicKey, error) {
 	var pubKey65 []byte
diff --git a/p2p/rlpx/rlpx_test.go b/p2p/rlpx/rlpx_test.go
index 127a01816..28759f2b4 100644
--- a/p2p/rlpx/rlpx_test.go
+++ b/p2p/rlpx/rlpx_test.go
@@ -22,6 +22,7 @@ import (
 	"encoding/hex"
 	"fmt"
 	"io"
+	"math/rand"
 	"net"
 	"reflect"
 	"strings"
@@ -30,6 +31,7 @@ import (
 	"github.com/davecgh/go-spew/spew"
 	"github.com/ethereum/go-ethereum/crypto"
 	"github.com/ethereum/go-ethereum/crypto/ecies"
+	"github.com/ethereum/go-ethereum/p2p/simulations/pipes"
 	"github.com/ethereum/go-ethereum/rlp"
 	"github.com/stretchr/testify/assert"
 )
@@ -124,7 +126,7 @@ func TestFrameReadWrite(t *testing.T) {
 		IngressMAC: hash,
 		EgressMAC:  hash,
 	})
-	h := conn.handshake
+	h := conn.session
 
 	golden := unhex(`
 		00828ddae471818bb0bfa6b551d1cb42
@@ -166,27 +168,11 @@ func (h fakeHash) Sum(b []byte) []byte       { return append(b, h...) }
 
 type handshakeAuthTest struct {
 	input       string
-	isPlain     bool
 	wantVersion uint
 	wantRest    []rlp.RawValue
 }
 
 var eip8HandshakeAuthTests = []handshakeAuthTest{
-	// (Auth₁) RLPx v4 plain encoding
-	{
-		input: `
-			048ca79ad18e4b0659fab4853fe5bc58eb83992980f4c9cc147d2aa31532efd29a3d3dc6a3d89eaf
-			913150cfc777ce0ce4af2758bf4810235f6e6ceccfee1acc6b22c005e9e3a49d6448610a58e98744
-			ba3ac0399e82692d67c1f58849050b3024e21a52c9d3b01d871ff5f210817912773e610443a9ef14
-			2e91cdba0bd77b5fdf0769b05671fc35f83d83e4d3b0b000c6b2a1b1bba89e0fc51bf4e460df3105
-			c444f14be226458940d6061c296350937ffd5e3acaceeaaefd3c6f74be8e23e0f45163cc7ebd7622
-			0f0128410fd05250273156d548a414444ae2f7dea4dfca2d43c057adb701a715bf59f6fb66b2d1d2
-			0f2c703f851cbf5ac47396d9ca65b6260bd141ac4d53e2de585a73d1750780db4c9ee4cd4d225173
-			a4592ee77e2bd94d0be3691f3b406f9bba9b591fc63facc016bfa8
-		`,
-		isPlain:     true,
-		wantVersion: 4,
-	},
 	// (Auth₂) EIP-8 encoding
 	{
 		input: `
@@ -233,18 +219,6 @@ type handshakeAckTest struct {
 }
 
 var eip8HandshakeRespTests = []handshakeAckTest{
-	// (Ack₁) RLPx v4 plain encoding
-	{
-		input: `
-			049f8abcfa9c0dc65b982e98af921bc0ba6e4243169348a236abe9df5f93aa69d99cadddaa387662
-			b0ff2c08e9006d5a11a278b1b3331e5aaabf0a32f01281b6f4ede0e09a2d5f585b26513cb794d963
-			5a57563921c04a9090b4f14ee42be1a5461049af4ea7a7f49bf4c97a352d39c8d02ee4acc416388c
-			1c66cec761d2bc1c72da6ba143477f049c9d2dde846c252c111b904f630ac98e51609b3b1f58168d
-			dca6505b7196532e5f85b259a20c45e1979491683fee108e9660edbf38f3add489ae73e3dda2c71b
-			d1497113d5c755e942d1
-		`,
-		wantVersion: 4,
-	},
 	// (Ack₂) EIP-8 encoding
 	{
 		input: `
@@ -287,10 +261,13 @@ var eip8HandshakeRespTests = []handshakeAckTest{
 	},
 }
 
+var (
+	keyA, _ = crypto.HexToECDSA("49a7b37aa6f6645917e7b807e9d1c00d4fa71f18343b0d4122a4d2df64dd6fee")
+	keyB, _ = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")
+)
+
 func TestHandshakeForwardCompatibility(t *testing.T) {
 	var (
-		keyA, _       = crypto.HexToECDSA("49a7b37aa6f6645917e7b807e9d1c00d4fa71f18343b0d4122a4d2df64dd6fee")
-		keyB, _       = crypto.HexToECDSA("b71c71a67e1177ad4e901695e1b4b9ee17ae16c6668d313eac2f96dbcda3f291")
 		pubA          = crypto.FromECDSAPub(&keyA.PublicKey)[1:]
 		pubB          = crypto.FromECDSAPub(&keyB.PublicKey)[1:]
 		ephA, _       = crypto.HexToECDSA("869d6ecf5211f1cc60418a13b9d870b22959d0c16f02bec714c960dd2298a32d")
@@ -304,7 +281,7 @@ func TestHandshakeForwardCompatibility(t *testing.T) {
 		_             = authSignature
 	)
 	makeAuth := func(test handshakeAuthTest) *authMsgV4 {
-		msg := &authMsgV4{Version: test.wantVersion, Rest: test.wantRest, gotPlain: test.isPlain}
+		msg := &authMsgV4{Version: test.wantVersion, Rest: test.wantRest}
 		copy(msg.Signature[:], authSignature)
 		copy(msg.InitiatorPubkey[:], pubA)
 		copy(msg.Nonce[:], nonceA)
@@ -319,9 +296,10 @@ func TestHandshakeForwardCompatibility(t *testing.T) {
 
 	// check auth msg parsing
 	for _, test := range eip8HandshakeAuthTests {
+		var h handshakeState
 		r := bytes.NewReader(unhex(test.input))
 		msg := new(authMsgV4)
-		ciphertext, err := readHandshakeMsg(msg, encAuthMsgLen, keyB, r)
+		ciphertext, err := h.readMsg(msg, keyB, r)
 		if err != nil {
 			t.Errorf("error for input %x:\n  %v", unhex(test.input), err)
 			continue
@@ -337,10 +315,11 @@ func TestHandshakeForwardCompatibility(t *testing.T) {
 
 	// check auth resp parsing
 	for _, test := range eip8HandshakeRespTests {
+		var h handshakeState
 		input := unhex(test.input)
 		r := bytes.NewReader(input)
 		msg := new(authRespV4)
-		ciphertext, err := readHandshakeMsg(msg, encAuthRespLen, keyA, r)
+		ciphertext, err := h.readMsg(msg, keyA, r)
 		if err != nil {
 			t.Errorf("error for input %x:\n  %v", input, err)
 			continue
@@ -356,14 +335,14 @@ func TestHandshakeForwardCompatibility(t *testing.T) {
 
 	// check derivation for (Auth₂, Ack₂) on recipient side
 	var (
-		hs = &encHandshake{
+		hs = &handshakeState{
 			initiator:     false,
 			respNonce:     nonceB,
 			randomPrivKey: ecies.ImportECDSA(ephB),
 		}
-		authCiphertext     = unhex(eip8HandshakeAuthTests[1].input)
-		authRespCiphertext = unhex(eip8HandshakeRespTests[1].input)
-		authMsg            = makeAuth(eip8HandshakeAuthTests[1])
+		authCiphertext     = unhex(eip8HandshakeAuthTests[0].input)
+		authRespCiphertext = unhex(eip8HandshakeRespTests[0].input)
+		authMsg            = makeAuth(eip8HandshakeAuthTests[0])
 		wantAES            = unhex("80e8632c05fed6fc2a13b0f8d31a3cf645366239170ea067065aba8e28bac487")
 		wantMAC            = unhex("2ea74ec5dae199227dff1af715362700e989d889d7a493cb0639691efb8e5f98")
 		wantFooIngressHash = unhex("0c7ec6340062cc46f5e9f1e3cf86f8c8c403c5a0964f5df0ebd34a75ddc86db5")
@@ -388,6 +367,74 @@ func TestHandshakeForwardCompatibility(t *testing.T) {
 	}
 }
 
+func BenchmarkHandshakeRead(b *testing.B) {
+	var input = unhex(eip8HandshakeAuthTests[0].input)
+
+	for i := 0; i < b.N; i++ {
+		var (
+			h   handshakeState
+			r   = bytes.NewReader(input)
+			msg = new(authMsgV4)
+		)
+		if _, err := h.readMsg(msg, keyB, r); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func BenchmarkThroughput(b *testing.B) {
+	pipe1, pipe2, err := pipes.TCPPipe()
+	if err != nil {
+		b.Fatal(err)
+	}
+
+	var (
+		conn1, conn2  = NewConn(pipe1, nil), NewConn(pipe2, &keyA.PublicKey)
+		handshakeDone = make(chan error, 1)
+		msgdata       = make([]byte, 1024)
+		rand          = rand.New(rand.NewSource(1337))
+	)
+	rand.Read(msgdata)
+
+	// Server side.
+	go func() {
+		defer conn1.Close()
+		// Perform handshake.
+		_, err := conn1.Handshake(keyA)
+		handshakeDone <- err
+		if err != nil {
+			return
+		}
+		conn1.SetSnappy(true)
+		// Keep sending messages until connection closed.
+		for {
+			if _, err := conn1.Write(0, msgdata); err != nil {
+				return
+			}
+		}
+	}()
+
+	// Set up client side.
+	defer conn2.Close()
+	if _, err := conn2.Handshake(keyB); err != nil {
+		b.Fatal("client handshake error:", err)
+	}
+	conn2.SetSnappy(true)
+	if err := <-handshakeDone; err != nil {
+		b.Fatal("server hanshake error:", err)
+	}
+
+	// Read N messages.
+	b.SetBytes(int64(len(msgdata)))
+	b.ReportAllocs()
+	for i := 0; i < b.N; i++ {
+		_, _, _, err := conn2.Read()
+		if err != nil {
+			b.Fatal("read error:", err)
+		}
+	}
+}
+
 func unhex(str string) []byte {
 	r := strings.NewReplacer("\t", "", " ", "", "\n", "")
 	b, err := hex.DecodeString(r.Replace(str))
diff --git a/p2p/transport.go b/p2p/transport.go
index 3f1cd7d64..d59425986 100644
--- a/p2p/transport.go
+++ b/p2p/transport.go
@@ -25,6 +25,7 @@ import (
 	"sync"
 	"time"
 
+	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/common/bitutil"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/p2p/rlpx"
@@ -62,6 +63,10 @@ func (t *rlpxTransport) ReadMsg() (Msg, error) {
 	t.conn.SetReadDeadline(time.Now().Add(frameReadTimeout))
 	code, data, wireSize, err := t.conn.Read()
 	if err == nil {
+		// Protocol messages are dispatched to subprotocol handlers asynchronously,
+		// but package rlpx may reuse the returned 'data' buffer on the next call
+		// to Read. Copy the message data to avoid this being an issue.
+		data = common.CopyBytes(data)
 		msg = Msg{
 			ReceivedAt: time.Now(),
 			Code:       code,
diff --git a/rlp/raw.go b/rlp/raw.go
index 3071e99ca..f355efc14 100644
--- a/rlp/raw.go
+++ b/rlp/raw.go
@@ -34,6 +34,14 @@ func ListSize(contentSize uint64) uint64 {
 	return uint64(headsize(contentSize)) + contentSize
 }
 
+// IntSize returns the encoded size of the integer x.
+func IntSize(x uint64) int {
+	if x < 0x80 {
+		return 1
+	}
+	return 1 + intsize(x)
+}
+
 // Split returns the content of first RLP value and any
 // bytes after the value as subslices of b.
 func Split(b []byte) (k Kind, content, rest []byte, err error) {
diff --git a/rlp/raw_test.go b/rlp/raw_test.go
index c976c4f73..185e269d0 100644
--- a/rlp/raw_test.go
+++ b/rlp/raw_test.go
@@ -263,6 +263,12 @@ func TestAppendUint64(t *testing.T) {
 		if !bytes.Equal(x, unhex(test.output)) {
 			t.Errorf("AppendUint64(%v, %d): got %x, want %s", test.slice, test.input, x, test.output)
 		}
+
+		// Check that IntSize returns the appended size.
+		length := len(x) - len(test.slice)
+		if s := IntSize(test.input); s != length {
+			t.Errorf("IntSize(%d): got %d, want %d", test.input, s, length)
+		}
 	}
 }
 
