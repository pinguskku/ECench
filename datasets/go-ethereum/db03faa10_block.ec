commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
commit db03faa10d402bcc70054aa2d3e70eecc37a57e2
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 7 17:50:58 2021 +0100

    core, eth: improve delivery speed on header requests (#23105)
    
    This PR reduces the amount of work we do when answering header queries, e.g. when a peer
    is syncing from us.
    
    For some items, e.g block bodies, when we read the rlp-data from database, we plug it
    directly into the response package. We didn't do that for headers, but instead read
    headers-rlp, decode to types.Header, and re-encode to rlp. This PR changes that to keep it
    in RLP-form as much as possible. When a node is syncing from us, it typically requests 192
    contiguous headers. On master it has the following effect:
    
    - For headers not in ancient: 2 db lookups. One for translating hash->number (even though
      the request is by number), and another for reading by hash (this latter one is sometimes
      cached).
    
    - For headers in ancient: 1 file lookup/syscall for translating hash->number (even though
      the request is by number), and another for reading the header itself. After this, it
      also performes a hashing of the header, to ensure that the hash is what it expected. In
      this PR, I instead move the logic for "give me a sequence of blocks" into the lower
      layers, where the database can determine how and what to read from leveldb and/or
      ancients.
    
    There are basically four types of requests; three of them are improved this way. The
    fourth, by hash going backwards, is more tricky to optimize. However, since we know that
    the gap is 0, we can look up by the parentHash, and stlil shave off all the number->hash
    lookups.
    
    The gapped collection can be optimized similarly, as a follow-up, at least in three out of
    four cases.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain_reader.go b/core/blockchain_reader.go
index beaa57b0c..9e966df4e 100644
--- a/core/blockchain_reader.go
+++ b/core/blockchain_reader.go
@@ -73,6 +73,12 @@ func (bc *BlockChain) GetHeaderByNumber(number uint64) *types.Header {
 	return bc.hc.GetHeaderByNumber(number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+func (bc *BlockChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	return bc.hc.GetHeadersFrom(number, count)
+}
+
 // GetBody retrieves a block body (transactions and uncles) from the database by
 // hash, caching it if found.
 func (bc *BlockChain) GetBody(hash common.Hash) *types.Body {
diff --git a/core/headerchain.go b/core/headerchain.go
index 335945d48..99364f638 100644
--- a/core/headerchain.go
+++ b/core/headerchain.go
@@ -33,6 +33,7 @@ import (
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 	lru "github.com/hashicorp/golang-lru"
 )
 
@@ -498,6 +499,46 @@ func (hc *HeaderChain) GetHeaderByNumber(number uint64) *types.Header {
 	return hc.GetHeader(hash, number)
 }
 
+// GetHeadersFrom returns a contiguous segment of headers, in rlp-form, going
+// backwards from the given number.
+// If the 'number' is higher than the highest local header, this method will
+// return a best-effort response, containing the headers that we do have.
+func (hc *HeaderChain) GetHeadersFrom(number, count uint64) []rlp.RawValue {
+	// If the request is for future headers, we still return the portion of
+	// headers that we are able to serve
+	if current := hc.CurrentHeader().Number.Uint64(); current < number {
+		if count > number-current {
+			count -= number - current
+			number = current
+		} else {
+			return nil
+		}
+	}
+	var headers []rlp.RawValue
+	// If we have some of the headers in cache already, use that before going to db.
+	hash := rawdb.ReadCanonicalHash(hc.chainDb, number)
+	if hash == (common.Hash{}) {
+		return nil
+	}
+	for count > 0 {
+		header, ok := hc.headerCache.Get(hash)
+		if !ok {
+			break
+		}
+		h := header.(*types.Header)
+		rlpData, _ := rlp.EncodeToBytes(h)
+		headers = append(headers, rlpData)
+		hash = h.ParentHash
+		count--
+		number--
+	}
+	// Read remaining from db
+	if count > 0 {
+		headers = append(headers, rawdb.ReadHeaderRange(hc.chainDb, number, count)...)
+	}
+	return headers
+}
+
 func (hc *HeaderChain) GetCanonicalHash(number uint64) common.Hash {
 	return rawdb.ReadCanonicalHash(hc.chainDb, number)
 }
diff --git a/core/rawdb/accessors_chain.go b/core/rawdb/accessors_chain.go
index 82d3f5c0c..7f46f9d72 100644
--- a/core/rawdb/accessors_chain.go
+++ b/core/rawdb/accessors_chain.go
@@ -279,6 +279,56 @@ func WriteFastTxLookupLimit(db ethdb.KeyValueWriter, number uint64) {
 	}
 }
 
+// ReadHeaderRange returns the rlp-encoded headers, starting at 'number', and going
+// backwards towards genesis. This method assumes that the caller already has
+// placed a cap on count, to prevent DoS issues.
+// Since this method operates in head-towards-genesis mode, it will return an empty
+// slice in case the head ('number') is missing. Hence, the caller must ensure that
+// the head ('number') argument is actually an existing header.
+//
+// N.B: Since the input is a number, as opposed to a hash, it's implicit that
+// this method only operates on canon headers.
+func ReadHeaderRange(db ethdb.Reader, number uint64, count uint64) []rlp.RawValue {
+	var rlpHeaders []rlp.RawValue
+	if count == 0 {
+		return rlpHeaders
+	}
+	i := number
+	if count-1 > number {
+		// It's ok to request block 0, 1 item
+		count = number + 1
+	}
+	limit, _ := db.Ancients()
+	// First read live blocks
+	if i >= limit {
+		// If we need to read live blocks, we need to figure out the hash first
+		hash := ReadCanonicalHash(db, number)
+		for ; i >= limit && count > 0; i-- {
+			if data, _ := db.Get(headerKey(i, hash)); len(data) > 0 {
+				rlpHeaders = append(rlpHeaders, data)
+				// Get the parent hash for next query
+				hash = types.HeaderParentHashFromRLP(data)
+			} else {
+				break // Maybe got moved to ancients
+			}
+			count--
+		}
+	}
+	if count == 0 {
+		return rlpHeaders
+	}
+	// read remaining from ancients
+	max := count * 700
+	data, err := db.AncientRange(freezerHeaderTable, i+1-count, count, max)
+	if err == nil && uint64(len(data)) == count {
+		// the data is on the order [h, h+1, .., n] -- reordering needed
+		for i := range data {
+			rlpHeaders = append(rlpHeaders, data[len(data)-1-i])
+		}
+	}
+	return rlpHeaders
+}
+
 // ReadHeaderRLP retrieves a block header in its raw RLP database encoding.
 func ReadHeaderRLP(db ethdb.Reader, hash common.Hash, number uint64) rlp.RawValue {
 	var data []byte
diff --git a/core/rawdb/accessors_chain_test.go b/core/rawdb/accessors_chain_test.go
index 50b0d5390..2c36de898 100644
--- a/core/rawdb/accessors_chain_test.go
+++ b/core/rawdb/accessors_chain_test.go
@@ -883,3 +883,67 @@ func BenchmarkDecodeRLPLogs(b *testing.B) {
 		}
 	})
 }
+
+func TestHeadersRLPStorage(t *testing.T) {
+	// Have N headers in the freezer
+	frdir, err := ioutil.TempDir("", "")
+	if err != nil {
+		t.Fatalf("failed to create temp freezer dir: %v", err)
+	}
+	defer os.Remove(frdir)
+
+	db, err := NewDatabaseWithFreezer(NewMemoryDatabase(), frdir, "", false)
+	if err != nil {
+		t.Fatalf("failed to create database with ancient backend")
+	}
+	defer db.Close()
+	// Create blocks
+	var chain []*types.Block
+	var pHash common.Hash
+	for i := 0; i < 100; i++ {
+		block := types.NewBlockWithHeader(&types.Header{
+			Number:      big.NewInt(int64(i)),
+			Extra:       []byte("test block"),
+			UncleHash:   types.EmptyUncleHash,
+			TxHash:      types.EmptyRootHash,
+			ReceiptHash: types.EmptyRootHash,
+			ParentHash:  pHash,
+		})
+		chain = append(chain, block)
+		pHash = block.Hash()
+	}
+	var receipts []types.Receipts = make([]types.Receipts, 100)
+	// Write first half to ancients
+	WriteAncientBlocks(db, chain[:50], receipts[:50], big.NewInt(100))
+	// Write second half to db
+	for i := 50; i < 100; i++ {
+		WriteCanonicalHash(db, chain[i].Hash(), chain[i].NumberU64())
+		WriteBlock(db, chain[i])
+	}
+	checkSequence := func(from, amount int) {
+		headersRlp := ReadHeaderRange(db, uint64(from), uint64(amount))
+		if have, want := len(headersRlp), amount; have != want {
+			t.Fatalf("have %d headers, want %d", have, want)
+		}
+		for i, headerRlp := range headersRlp {
+			var header types.Header
+			if err := rlp.DecodeBytes(headerRlp, &header); err != nil {
+				t.Fatal(err)
+			}
+			if have, want := header.Number.Uint64(), uint64(from-i); have != want {
+				t.Fatalf("wrong number, have %d want %d", have, want)
+			}
+		}
+	}
+	checkSequence(99, 20)  // Latest block and 19 parents
+	checkSequence(99, 50)  // Latest block -> all db blocks
+	checkSequence(99, 51)  // Latest block -> one from ancients
+	checkSequence(99, 52)  // Latest blocks -> two from ancients
+	checkSequence(50, 2)   // One from db, one from ancients
+	checkSequence(49, 1)   // One from ancients
+	checkSequence(49, 50)  // All ancient ones
+	checkSequence(99, 100) // All blocks
+	checkSequence(0, 1)    // Only genesis
+	checkSequence(1, 1)    // Only block 1
+	checkSequence(1, 2)    // Genesis + block 1
+}
diff --git a/core/types/block.go b/core/types/block.go
index 92e5cb772..f38c55c1f 100644
--- a/core/types/block.go
+++ b/core/types/block.go
@@ -389,3 +389,21 @@ func (b *Block) Hash() common.Hash {
 }
 
 type Blocks []*Block
+
+// HeaderParentHashFromRLP returns the parentHash of an RLP-encoded
+// header. If 'header' is invalid, the zero hash is returned.
+func HeaderParentHashFromRLP(header []byte) common.Hash {
+	// parentHash is the first list element.
+	listContent, _, err := rlp.SplitList(header)
+	if err != nil {
+		return common.Hash{}
+	}
+	parentHash, _, err := rlp.SplitString(listContent)
+	if err != nil {
+		return common.Hash{}
+	}
+	if len(parentHash) != 32 {
+		return common.Hash{}
+	}
+	return common.BytesToHash(parentHash)
+}
diff --git a/core/types/block_test.go b/core/types/block_test.go
index 0b9a4def8..5cdea3fc0 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -281,3 +281,64 @@ func makeBenchBlock() *Block {
 	}
 	return NewBlock(header, txs, uncles, receipts, newHasher())
 }
+
+func TestRlpDecodeParentHash(t *testing.T) {
+	// A minimum one
+	want := common.HexToHash("0x112233445566778899001122334455667788990011223344556677889900aabb")
+	if rlpData, err := rlp.EncodeToBytes(Header{ParentHash: want}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// And a maximum one
+	// | Difficulty  | dynamic| *big.Int       | 0x5ad3c2c71bbff854908 (current mainnet TD: 76 bits) |
+	// | Number      | dynamic| *big.Int       | 64 bits               |
+	// | Extra       | dynamic| []byte         | 65+32 byte (clique)   |
+	// | BaseFee     | dynamic| *big.Int       | 64 bits               |
+	mainnetTd := new(big.Int)
+	mainnetTd.SetString("5ad3c2c71bbff854908", 16)
+	if rlpData, err := rlp.EncodeToBytes(Header{
+		ParentHash: want,
+		Difficulty: mainnetTd,
+		Number:     new(big.Int).SetUint64(math.MaxUint64),
+		Extra:      make([]byte, 65+32),
+		BaseFee:    new(big.Int).SetUint64(math.MaxUint64),
+	}); err != nil {
+		t.Fatal(err)
+	} else {
+		if have := HeaderParentHashFromRLP(rlpData); have != want {
+			t.Fatalf("have %x, want %x", have, want)
+		}
+	}
+	// Also test a very very large header.
+	{
+		// The rlp-encoding of the heder belowCauses _total_ length of 65540,
+		// which is the first to blow the fast-path.
+		h := Header{
+			ParentHash: want,
+			Extra:      make([]byte, 65041),
+		}
+		if rlpData, err := rlp.EncodeToBytes(h); err != nil {
+			t.Fatal(err)
+		} else {
+			if have := HeaderParentHashFromRLP(rlpData); have != want {
+				t.Fatalf("have %x, want %x", have, want)
+			}
+		}
+	}
+	{
+		// Test some invalid erroneous stuff
+		for i, rlpData := range [][]byte{
+			nil,
+			common.FromHex("0x"),
+			common.FromHex("0x01"),
+			common.FromHex("0x3031323334"),
+		} {
+			if have, want := HeaderParentHashFromRLP(rlpData), (common.Hash{}); have != want {
+				t.Fatalf("invalid %d: have %x, want %x", i, have, want)
+			}
+		}
+	}
+}
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 3e78a0bb7..70c6a5121 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -154,12 +154,24 @@ func (dlp *downloadTesterPeer) Head() (common.Hash, *big.Int) {
 	return head.Hash(), dlp.chain.GetTd(head.Hash(), head.NumberU64())
 }
 
+func unmarshalRlpHeaders(rlpdata []rlp.RawValue) []*types.Header {
+	var headers = make([]*types.Header, len(rlpdata))
+	for i, data := range rlpdata {
+		var h types.Header
+		if err := rlp.DecodeBytes(data, &h); err != nil {
+			panic(err)
+		}
+		headers[i] = &h
+	}
+	return headers
+}
+
 // RequestHeadersByHash constructs a GetBlockHeaders function based on a hashed
 // origin; associated with a particular peer in the download tester. The returned
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Hash: origin,
 		},
@@ -167,7 +179,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
@@ -203,7 +215,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByHash(origin common.Hash, amount i
 // function can be used to retrieve batches of headers from the particular peer.
 func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int, skip int, reverse bool, sink chan *eth.Response) (*eth.Request, error) {
 	// Service the header query via the live handler code
-	headers := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
+	rlpHeaders := eth.ServiceGetBlockHeadersQuery(dlp.chain, &eth.GetBlockHeadersPacket{
 		Origin: eth.HashOrNumber{
 			Number: origin,
 		},
@@ -211,7 +223,7 @@ func (dlp *downloadTesterPeer) RequestHeadersByNumber(origin uint64, amount int,
 		Skip:    uint64(skip),
 		Reverse: reverse,
 	}, nil)
-
+	headers := unmarshalRlpHeaders(rlpHeaders)
 	// If a malicious peer is simulated withholding headers, delete them
 	for hash := range dlp.withholdHeaders {
 		for i, header := range headers {
diff --git a/eth/handler_eth_test.go b/eth/handler_eth_test.go
index b826ed7a9..6e1c57cb6 100644
--- a/eth/handler_eth_test.go
+++ b/eth/handler_eth_test.go
@@ -38,6 +38,7 @@ import (
 	"github.com/ethereum/go-ethereum/p2p"
 	"github.com/ethereum/go-ethereum/p2p/enode"
 	"github.com/ethereum/go-ethereum/params"
+	"github.com/ethereum/go-ethereum/rlp"
 )
 
 // testEthHandler is a mock event handler to listen for inbound network requests
@@ -560,15 +561,17 @@ func testCheckpointChallenge(t *testing.T, syncmode downloader.SyncMode, checkpo
 		// Create a block to reply to the challenge if no timeout is simulated.
 		if !timeout {
 			if empty {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{}); err != nil {
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else if match {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{response}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(response)
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			} else {
-				if err := remote.ReplyBlockHeaders(request.RequestId, []*types.Header{{Number: response.Number}}); err != nil {
+				responseRlp, _ := rlp.EncodeToBytes(types.Header{Number: response.Number})
+				if err := remote.ReplyBlockHeadersRLP(request.RequestId, []rlp.RawValue{responseRlp}); err != nil {
 					t.Fatalf("failed to answer challenge: %v", err)
 				}
 			}
diff --git a/eth/protocols/eth/handler.go b/eth/protocols/eth/handler.go
index 6e0fc4a37..81d45d8b8 100644
--- a/eth/protocols/eth/handler.go
+++ b/eth/protocols/eth/handler.go
@@ -35,9 +35,6 @@ const (
 	// softResponseLimit is the target maximum size of replies to data retrievals.
 	softResponseLimit = 2 * 1024 * 1024
 
-	// estHeaderSize is the approximate size of an RLP encoded block header.
-	estHeaderSize = 500
-
 	// maxHeadersServe is the maximum number of block headers to serve. This number
 	// is there to limit the number of disk lookups.
 	maxHeadersServe = 1024
diff --git a/eth/protocols/eth/handler_test.go b/eth/protocols/eth/handler_test.go
index 5192f043d..7d9b37883 100644
--- a/eth/protocols/eth/handler_test.go
+++ b/eth/protocols/eth/handler_test.go
@@ -136,11 +136,13 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		query  *GetBlockHeadersPacket // The query to execute for header retrieval
 		expect []common.Hash          // The hashes of the block whose headers are expected
 	}{
-		// A single random block should be retrievable by hash and number too
+		// A single random block should be retrievable by hash
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Hash: backend.chain.GetBlockByNumber(limit / 2).Hash()}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
-		}, {
+		},
+		// A single random block should be retrievable by number
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: limit / 2}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(limit / 2).Hash()},
 		},
@@ -180,10 +182,15 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: 0}, Amount: 1},
 			[]common.Hash{backend.chain.GetBlockByNumber(0).Hash()},
-		}, {
+		},
+		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 1},
 			[]common.Hash{backend.chain.CurrentBlock().Hash()},
 		},
+		{ // If the peer requests a bit into the future, we deliver what we have
+			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64()}, Amount: 10},
+			[]common.Hash{backend.chain.CurrentBlock().Hash()},
+		},
 		// Ensure protocol limits are honored
 		{
 			&GetBlockHeadersPacket{Origin: HashOrNumber{Number: backend.chain.CurrentBlock().NumberU64() - 1}, Amount: limit + 10, Reverse: true},
@@ -280,7 +287,7 @@ func testGetBlockHeaders(t *testing.T, protocol uint) {
 					RequestId:          456,
 					BlockHeadersPacket: headers,
 				}); err != nil {
-					t.Errorf("test %d: headers mismatch: %v", i, err)
+					t.Errorf("test %d by hash: headers mismatch: %v", i, err)
 				}
 			}
 		}
diff --git a/eth/protocols/eth/handlers.go b/eth/protocols/eth/handlers.go
index 503e572a8..8fc966e7a 100644
--- a/eth/protocols/eth/handlers.go
+++ b/eth/protocols/eth/handlers.go
@@ -36,12 +36,21 @@ func handleGetBlockHeaders66(backend Backend, msg Decoder, peer *Peer) error {
 		return fmt.Errorf("%w: message %v: %v", errDecode, msg, err)
 	}
 	response := ServiceGetBlockHeadersQuery(backend.Chain(), query.GetBlockHeadersPacket, peer)
-	return peer.ReplyBlockHeaders(query.RequestId, response)
+	return peer.ReplyBlockHeadersRLP(query.RequestId, response)
 }
 
 // ServiceGetBlockHeadersQuery assembles the response to a header query. It is
 // exposed to allow external packages to test protocol behavior.
-func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []*types.Header {
+func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
+	if query.Skip == 0 {
+		// The fast path: when the request is for a contiguous segment of headers.
+		return serviceContiguousBlockHeaderQuery(chain, query)
+	} else {
+		return serviceNonContiguousBlockHeaderQuery(chain, query, peer)
+	}
+}
+
+func serviceNonContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket, peer *Peer) []rlp.RawValue {
 	hashMode := query.Origin.Hash != (common.Hash{})
 	first := true
 	maxNonCanonical := uint64(100)
@@ -49,7 +58,7 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	// Gather headers until the fetch or network limits is reached
 	var (
 		bytes   common.StorageSize
-		headers []*types.Header
+		headers []rlp.RawValue
 		unknown bool
 		lookups int
 	)
@@ -74,9 +83,12 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 		if origin == nil {
 			break
 		}
-		headers = append(headers, origin)
-		bytes += estHeaderSize
-
+		if rlpData, err := rlp.EncodeToBytes(origin); err != nil {
+			log.Crit("Unable to decode our own headers", "err", err)
+		} else {
+			headers = append(headers, rlp.RawValue(rlpData))
+			bytes += common.StorageSize(len(rlpData))
+		}
 		// Advance to the next header of the query
 		switch {
 		case hashMode && query.Reverse:
@@ -127,6 +139,69 @@ func ServiceGetBlockHeadersQuery(chain *core.BlockChain, query *GetBlockHeadersP
 	return headers
 }
 
+func serviceContiguousBlockHeaderQuery(chain *core.BlockChain, query *GetBlockHeadersPacket) []rlp.RawValue {
+	count := query.Amount
+	if count > maxHeadersServe {
+		count = maxHeadersServe
+	}
+	if query.Origin.Hash == (common.Hash{}) {
+		// Number mode, just return the canon chain segment. The backend
+		// delivers in [N, N-1, N-2..] descending order, so we need to
+		// accommodate for that.
+		from := query.Origin.Number
+		if !query.Reverse {
+			from = from + count - 1
+		}
+		headers := chain.GetHeadersFrom(from, count)
+		if !query.Reverse {
+			for i, j := 0, len(headers)-1; i < j; i, j = i+1, j-1 {
+				headers[i], headers[j] = headers[j], headers[i]
+			}
+		}
+		return headers
+	}
+	// Hash mode.
+	var (
+		headers []rlp.RawValue
+		hash    = query.Origin.Hash
+		header  = chain.GetHeaderByHash(hash)
+	)
+	if header != nil {
+		rlpData, _ := rlp.EncodeToBytes(header)
+		headers = append(headers, rlpData)
+	} else {
+		// We don't even have the origin header
+		return headers
+	}
+	num := header.Number.Uint64()
+	if !query.Reverse {
+		// Theoretically, we are tasked to deliver header by hash H, and onwards.
+		// However, if H is not canon, we will be unable to deliver any descendants of
+		// H.
+		if canonHash := chain.GetCanonicalHash(num); canonHash != hash {
+			// Not canon, we can't deliver descendants
+			return headers
+		}
+		descendants := chain.GetHeadersFrom(num+count-1, count-1)
+		for i, j := 0, len(descendants)-1; i < j; i, j = i+1, j-1 {
+			descendants[i], descendants[j] = descendants[j], descendants[i]
+		}
+		headers = append(headers, descendants...)
+		return headers
+	}
+	{ // Last mode: deliver ancestors of H
+		for i := uint64(1); header != nil && i < count; i++ {
+			header = chain.GetHeaderByHash(header.ParentHash)
+			if header == nil {
+				break
+			}
+			rlpData, _ := rlp.EncodeToBytes(header)
+			headers = append(headers, rlpData)
+		}
+		return headers
+	}
+}
+
 func handleGetBlockBodies66(backend Backend, msg Decoder, peer *Peer) error {
 	// Decode the block body retrieval message
 	var query GetBlockBodiesPacket66
diff --git a/eth/protocols/eth/peer.go b/eth/protocols/eth/peer.go
index b61dc25af..4161420f3 100644
--- a/eth/protocols/eth/peer.go
+++ b/eth/protocols/eth/peer.go
@@ -297,10 +297,10 @@ func (p *Peer) AsyncSendNewBlock(block *types.Block, td *big.Int) {
 }
 
 // ReplyBlockHeaders is the eth/66 version of SendBlockHeaders.
-func (p *Peer) ReplyBlockHeaders(id uint64, headers []*types.Header) error {
-	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersPacket66{
-		RequestId:          id,
-		BlockHeadersPacket: headers,
+func (p *Peer) ReplyBlockHeadersRLP(id uint64, headers []rlp.RawValue) error {
+	return p2p.Send(p.rw, BlockHeadersMsg, BlockHeadersRLPPacket66{
+		RequestId:             id,
+		BlockHeadersRLPPacket: headers,
 	})
 }
 
diff --git a/eth/protocols/eth/protocol.go b/eth/protocols/eth/protocol.go
index 3c3da30fa..a8420ad68 100644
--- a/eth/protocols/eth/protocol.go
+++ b/eth/protocols/eth/protocol.go
@@ -175,6 +175,16 @@ type BlockHeadersPacket66 struct {
 	BlockHeadersPacket
 }
 
+// BlockHeadersRLPPacket represents a block header response, to use when we already
+// have the headers rlp encoded.
+type BlockHeadersRLPPacket []rlp.RawValue
+
+// BlockHeadersPacket represents a block header response over eth/66.
+type BlockHeadersRLPPacket66 struct {
+	RequestId uint64
+	BlockHeadersRLPPacket
+}
+
 // NewBlockPacket is the network packet for the block propagation message.
 type NewBlockPacket struct {
 	Block *types.Block
