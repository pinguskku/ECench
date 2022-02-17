commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
commit 924065e19d08cc7e6af0b3a5b5b1ef3785b79bd4
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jan 23 11:05:30 2018 +0100

    consensus/ethash: improve cache/dataset handling (#15864)
    
    * consensus/ethash: add maxEpoch constant
    
    * consensus/ethash: improve cache/dataset handling
    
    There are two fixes in this commit:
    
    Unmap the memory through a finalizer like the libethash wrapper did. The
    release logic was incorrect and freed the memory while it was being
    used, leading to crashes like in #14495 or #14943.
    
    Track caches and datasets using simplelru instead of reinventing LRU
    logic. This should make it easier to see whether it's correct.
    
    * consensus/ethash: restore 'future item' logic in lru
    
    * consensus/ethash: use mmap even in test mode
    
    This makes it possible to shorten the time taken for TestCacheFileEvict.
    
    * consensus/ethash: shuffle func calc*Size comments around
    
    * consensus/ethash: ensure future cache/dataset is in the lru cache
    
    * consensus/ethash: add issue link to the new test
    
    * consensus/ethash: fix vet
    
    * consensus/ethash: fix test
    
    * consensus: tiny issue + nitpick fixes

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 76f19252f..10767bb31 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -355,9 +355,11 @@ func hashimotoFull(dataset []uint32, hash []byte, nonce uint64) ([]byte, []byte)
 	return hashimoto(hash, nonce, uint64(len(dataset))*4, lookup)
 }
 
+const maxEpoch = 2048
+
 // datasetSizes is a lookup table for the ethash dataset size for the first 2048
 // epochs (i.e. 61440000 blocks).
-var datasetSizes = []uint64{
+var datasetSizes = [maxEpoch]uint64{
 	1073739904, 1082130304, 1090514816, 1098906752, 1107293056,
 	1115684224, 1124070016, 1132461952, 1140849536, 1149232768,
 	1157627776, 1166013824, 1174404736, 1182786944, 1191180416,
@@ -771,7 +773,7 @@ var datasetSizes = []uint64{
 
 // cacheSizes is a lookup table for the ethash verification cache size for the
 // first 2048 epochs (i.e. 61440000 blocks).
-var cacheSizes = []uint64{
+var cacheSizes = [maxEpoch]uint64{
 	16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
 	17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
 	18611392, 18742336, 18874304, 19004224, 19135936, 19267264, 19398208,
diff --git a/consensus/ethash/algorithm_go1.7.go b/consensus/ethash/algorithm_go1.7.go
index c34d041c3..c7f7f48e4 100644
--- a/consensus/ethash/algorithm_go1.7.go
+++ b/consensus/ethash/algorithm_go1.7.go
@@ -25,7 +25,7 @@ package ethash
 func cacheSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
@@ -39,7 +39,7 @@ func cacheSize(block uint64) uint64 {
 func datasetSize(block uint64) uint64 {
 	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
 	// We don't have a way to verify primes fast before Go 1.8
diff --git a/consensus/ethash/algorithm_go1.8.go b/consensus/ethash/algorithm_go1.8.go
index d691b758f..975fdffe5 100644
--- a/consensus/ethash/algorithm_go1.8.go
+++ b/consensus/ethash/algorithm_go1.8.go
@@ -20,17 +20,20 @@ package ethash
 
 import "math/big"
 
-// cacheSize calculates and returns the size of the ethash verification cache that
-// belongs to a certain block number. The cache size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// cacheSize returns the size of the ethash verification cache that belongs to a certain
+// block number.
 func cacheSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(cacheSizes) {
+	if epoch < maxEpoch {
 		return cacheSizes[epoch]
 	}
-	// No known cache size, calculate manually (sanity branch only)
+	return calcCacheSize(epoch)
+}
+
+// calcCacheSize calculates the cache size for epoch. The cache size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcCacheSize(epoch int) uint64 {
 	size := cacheInitBytes + cacheGrowthBytes*uint64(epoch) - hashBytes
 	for !new(big.Int).SetUint64(size / hashBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * hashBytes
@@ -38,17 +41,20 @@ func cacheSize(block uint64) uint64 {
 	return size
 }
 
-// datasetSize calculates and returns the size of the ethash mining dataset that
-// belongs to a certain block number. The dataset size grows linearly, however, we
-// always take the highest prime below the linearly growing threshold in order to
-// reduce the risk of accidental regularities leading to cyclic behavior.
+// datasetSize returns the size of the ethash mining dataset that belongs to a certain
+// block number.
 func datasetSize(block uint64) uint64 {
-	// If we have a pre-generated value, use that
 	epoch := int(block / epochLength)
-	if epoch < len(datasetSizes) {
+	if epoch < maxEpoch {
 		return datasetSizes[epoch]
 	}
-	// No known dataset size, calculate manually (sanity branch only)
+	return calcDatasetSize(epoch)
+}
+
+// calcDatasetSize calculates the dataset size for epoch. The dataset size grows linearly,
+// however, we always take the highest prime below the linearly growing threshold in order
+// to reduce the risk of accidental regularities leading to cyclic behavior.
+func calcDatasetSize(epoch int) uint64 {
 	size := datasetInitBytes + datasetGrowthBytes*uint64(epoch) - mixBytes
 	for !new(big.Int).SetUint64(size / mixBytes).ProbablyPrime(1) { // Always accurate for n < 2^64
 		size -= 2 * mixBytes
diff --git a/consensus/ethash/algorithm_go1.8_test.go b/consensus/ethash/algorithm_go1.8_test.go
index a822944a6..6648bd6a9 100644
--- a/consensus/ethash/algorithm_go1.8_test.go
+++ b/consensus/ethash/algorithm_go1.8_test.go
@@ -23,24 +23,15 @@ import "testing"
 // Tests whether the dataset size calculator works correctly by cross checking the
 // hard coded lookup table with the value generated by it.
 func TestSizeCalculations(t *testing.T) {
-	var tests []uint64
-
-	// Verify all the cache sizes from the lookup table
-	defer func(sizes []uint64) { cacheSizes = sizes }(cacheSizes)
-	tests, cacheSizes = cacheSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := cacheSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("cache %d: cache size mismatch: have %d, want %d", i, size, test)
+	// Verify all the cache and dataset sizes from the lookup table.
+	for epoch, want := range cacheSizes {
+		if size := calcCacheSize(epoch); size != want {
+			t.Errorf("cache %d: cache size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
-	// Verify all the dataset sizes from the lookup table
-	defer func(sizes []uint64) { datasetSizes = sizes }(datasetSizes)
-	tests, datasetSizes = datasetSizes, []uint64{}
-
-	for i, test := range tests {
-		if size := datasetSize(uint64(i*epochLength) + 1); size != test {
-			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", i, size, test)
+	for epoch, want := range datasetSizes {
+		if size := calcDatasetSize(epoch); size != want {
+			t.Errorf("dataset %d: dataset size mismatch: have %d, want %d", epoch, size, want)
 		}
 	}
 }
diff --git a/consensus/ethash/consensus.go b/consensus/ethash/consensus.go
index 82d23c92b..92a23d4a4 100644
--- a/consensus/ethash/consensus.go
+++ b/consensus/ethash/consensus.go
@@ -476,7 +476,7 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	}
 	// Sanity check that the block number is below the lookup table size (60M blocks)
 	number := header.Number.Uint64()
-	if number/epochLength >= uint64(len(cacheSizes)) {
+	if number/epochLength >= maxEpoch {
 		// Go < 1.7 cannot calculate new cache/dataset sizes (no fast prime check)
 		return errNonceOutOfRange
 	}
@@ -484,14 +484,18 @@ func (ethash *Ethash) VerifySeal(chain consensus.ChainReader, header *types.Head
 	if header.Difficulty.Sign() <= 0 {
 		return errInvalidDifficulty
 	}
+
 	// Recompute the digest and PoW value and verify against the header
 	cache := ethash.cache(number)
-
 	size := datasetSize(number)
 	if ethash.config.PowMode == ModeTest {
 		size = 32 * 1024
 	}
-	digest, result := hashimotoLight(size, cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	digest, result := hashimotoLight(size, cache.cache, header.HashNoNonce().Bytes(), header.Nonce.Uint64())
+	// Caches are unmapped in a finalizer. Ensure that the cache stays live
+	// until after the call to hashimotoLight so it's not unmapped while being used.
+	runtime.KeepAlive(cache)
+
 	if !bytes.Equal(header.MixDigest[:], digest) {
 		return errInvalidMixDigest
 	}
diff --git a/consensus/ethash/ethash.go b/consensus/ethash/ethash.go
index a78b3a895..91e20112a 100644
--- a/consensus/ethash/ethash.go
+++ b/consensus/ethash/ethash.go
@@ -26,6 +26,7 @@ import (
 	"os"
 	"path/filepath"
 	"reflect"
+	"runtime"
 	"strconv"
 	"sync"
 	"time"
@@ -35,6 +36,7 @@ import (
 	"github.com/ethereum/go-ethereum/consensus"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/rpc"
+	"github.com/hashicorp/golang-lru/simplelru"
 	metrics "github.com/rcrowley/go-metrics"
 )
 
@@ -142,32 +144,82 @@ func memoryMapAndGenerate(path string, size uint64, generator func(buffer []uint
 	return memoryMap(path)
 }
 
+// lru tracks caches or datasets by their last use time, keeping at most N of them.
+type lru struct {
+	what string
+	new  func(epoch uint64) interface{}
+	mu   sync.Mutex
+	// Items are kept in a LRU cache, but there is a special case:
+	// We always keep an item for (highest seen epoch) + 1 as the 'future item'.
+	cache      *simplelru.LRU
+	future     uint64
+	futureItem interface{}
+}
+
+// newlru create a new least-recently-used cache for ither the verification caches
+// or the mining datasets.
+func newlru(what string, maxItems int, new func(epoch uint64) interface{}) *lru {
+	if maxItems <= 0 {
+		maxItems = 1
+	}
+	cache, _ := simplelru.NewLRU(maxItems, func(key, value interface{}) {
+		log.Trace("Evicted ethash "+what, "epoch", key)
+	})
+	return &lru{what: what, new: new, cache: cache}
+}
+
+// get retrieves or creates an item for the given epoch. The first return value is always
+// non-nil. The second return value is non-nil if lru thinks that an item will be useful in
+// the near future.
+func (lru *lru) get(epoch uint64) (item, future interface{}) {
+	lru.mu.Lock()
+	defer lru.mu.Unlock()
+
+	// Get or create the item for the requested epoch.
+	item, ok := lru.cache.Get(epoch)
+	if !ok {
+		if lru.future > 0 && lru.future == epoch {
+			item = lru.futureItem
+		} else {
+			log.Trace("Requiring new ethash "+lru.what, "epoch", epoch)
+			item = lru.new(epoch)
+		}
+		lru.cache.Add(epoch, item)
+	}
+	// Update the 'future item' if epoch is larger than previously seen.
+	if epoch < maxEpoch-1 && lru.future < epoch+1 {
+		log.Trace("Requiring new future ethash "+lru.what, "epoch", epoch+1)
+		future = lru.new(epoch + 1)
+		lru.future = epoch + 1
+		lru.futureItem = future
+	}
+	return item, future
+}
+
 // cache wraps an ethash cache with some metadata to allow easier concurrent use.
 type cache struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch uint64    // Epoch for which this cache is relevant
+	dump  *os.File  // File descriptor of the memory mapped cache
+	mmap  mmap.MMap // Memory map itself to unmap before releasing
+	cache []uint32  // The actual cache data content (may be memory mapped)
+	once  sync.Once // Ensures the cache is generated only once
+}
 
-	cache []uint32   // The actual cache data content (may be memory mapped)
-	used  time.Time  // Timestamp of the last use for smarter eviction
-	once  sync.Once  // Ensures the cache is generated only once
-	lock  sync.Mutex // Ensures thread safety for updating the usage time
+// newCache creates a new ethash verification cache and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newCache(epoch uint64) interface{} {
+	return &cache{epoch: epoch}
 }
 
 // generate ensures that the cache content is generated before use.
 func (c *cache) generate(dir string, limit int, test bool) {
 	c.once.Do(func() {
-		// If we have a testing cache, generate and return
-		if test {
-			c.cache = make([]uint32, 1024/4)
-			generateCache(c.cache, c.epoch, seedHash(c.epoch*epochLength+1))
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		size := cacheSize(c.epoch*epochLength + 1)
 		seed := seedHash(c.epoch*epochLength + 1)
-
+		if test {
+			size = 1024
+		}
+		// If we don't store anything on disk, generate and return.
 		if dir == "" {
 			c.cache = make([]uint32, size/4)
 			generateCache(c.cache, c.epoch, seed)
@@ -181,6 +233,10 @@ func (c *cache) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("cache-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", c.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(c, (*cache).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		c.dump, c.mmap, c.cache, err = memoryMap(path)
@@ -207,49 +263,41 @@ func (c *cache) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (c *cache) release() {
+// finalizer unmaps the memory and closes the file.
+func (c *cache) finalizer() {
 	if c.mmap != nil {
 		c.mmap.Unmap()
-		c.mmap = nil
-	}
-	if c.dump != nil {
 		c.dump.Close()
-		c.dump = nil
+		c.mmap, c.dump = nil, nil
 	}
 }
 
 // dataset wraps an ethash dataset with some metadata to allow easier concurrent use.
 type dataset struct {
-	epoch uint64 // Epoch for which this cache is relevant
-
-	dump *os.File  // File descriptor of the memory mapped cache
-	mmap mmap.MMap // Memory map itself to unmap before releasing
+	epoch   uint64    // Epoch for which this cache is relevant
+	dump    *os.File  // File descriptor of the memory mapped cache
+	mmap    mmap.MMap // Memory map itself to unmap before releasing
+	dataset []uint32  // The actual cache data content
+	once    sync.Once // Ensures the cache is generated only once
+}
 
-	dataset []uint32   // The actual cache data content
-	used    time.Time  // Timestamp of the last use for smarter eviction
-	once    sync.Once  // Ensures the cache is generated only once
-	lock    sync.Mutex // Ensures thread safety for updating the usage time
+// newDataset creates a new ethash mining dataset and returns it as a plain Go
+// interface to be usable in an LRU cache.
+func newDataset(epoch uint64) interface{} {
+	return &dataset{epoch: epoch}
 }
 
 // generate ensures that the dataset content is generated before use.
 func (d *dataset) generate(dir string, limit int, test bool) {
 	d.once.Do(func() {
-		// If we have a testing dataset, generate and return
-		if test {
-			cache := make([]uint32, 1024/4)
-			generateCache(cache, d.epoch, seedHash(d.epoch*epochLength+1))
-
-			d.dataset = make([]uint32, 32*1024/4)
-			generateDataset(d.dataset, d.epoch, cache)
-
-			return
-		}
-		// If we don't store anything on disk, generate and return
 		csize := cacheSize(d.epoch*epochLength + 1)
 		dsize := datasetSize(d.epoch*epochLength + 1)
 		seed := seedHash(d.epoch*epochLength + 1)
-
+		if test {
+			csize = 1024
+			dsize = 32 * 1024
+		}
+		// If we don't store anything on disk, generate and return
 		if dir == "" {
 			cache := make([]uint32, csize/4)
 			generateCache(cache, d.epoch, seed)
@@ -265,6 +313,10 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 		path := filepath.Join(dir, fmt.Sprintf("full-R%d-%x%s", algorithmRevision, seed[:8], endian))
 		logger := log.New("epoch", d.epoch)
 
+		// We're about to mmap the file, ensure that the mapping is cleaned up when the
+		// cache becomes unused.
+		runtime.SetFinalizer(d, (*dataset).finalizer)
+
 		// Try to load the file from disk and memory map it
 		var err error
 		d.dump, d.mmap, d.dataset, err = memoryMap(path)
@@ -294,15 +346,12 @@ func (d *dataset) generate(dir string, limit int, test bool) {
 	})
 }
 
-// release closes any file handlers and memory maps open.
-func (d *dataset) release() {
+// finalizer closes any file handlers and memory maps open.
+func (d *dataset) finalizer() {
 	if d.mmap != nil {
 		d.mmap.Unmap()
-		d.mmap = nil
-	}
-	if d.dump != nil {
 		d.dump.Close()
-		d.dump = nil
+		d.mmap, d.dump = nil, nil
 	}
 }
 
@@ -310,14 +359,12 @@ func (d *dataset) release() {
 func MakeCache(block uint64, dir string) {
 	c := cache{epoch: block / epochLength}
 	c.generate(dir, math.MaxInt32, false)
-	c.release()
 }
 
 // MakeDataset generates a new ethash dataset and optionally stores it to disk.
 func MakeDataset(block uint64, dir string) {
 	d := dataset{epoch: block / epochLength}
 	d.generate(dir, math.MaxInt32, false)
-	d.release()
 }
 
 // Mode defines the type and amount of PoW verification an ethash engine makes.
@@ -347,10 +394,8 @@ type Config struct {
 type Ethash struct {
 	config Config
 
-	caches   map[uint64]*cache   // In memory caches to avoid regenerating too often
-	fcache   *cache              // Pre-generated cache for the estimated future epoch
-	datasets map[uint64]*dataset // In memory datasets to avoid regenerating too often
-	fdataset *dataset            // Pre-generated dataset for the estimated future epoch
+	caches   *lru // In memory caches to avoid regenerating too often
+	datasets *lru // In memory datasets to avoid regenerating too often
 
 	// Mining related fields
 	rand     *rand.Rand    // Properly seeded random source for nonces
@@ -380,8 +425,8 @@ func New(config Config) *Ethash {
 	}
 	return &Ethash{
 		config:   config,
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
+		caches:   newlru("cache", config.CachesInMem, newCache),
+		datasets: newlru("dataset", config.DatasetsInMem, newDataset),
 		update:   make(chan struct{}),
 		hashrate: metrics.NewMeter(),
 	}
@@ -390,16 +435,7 @@ func New(config Config) *Ethash {
 // NewTester creates a small sized ethash PoW scheme useful only for testing
 // purposes.
 func NewTester() *Ethash {
-	return &Ethash{
-		config: Config{
-			CachesInMem: 1,
-			PowMode:     ModeTest,
-		},
-		caches:   make(map[uint64]*cache),
-		datasets: make(map[uint64]*dataset),
-		update:   make(chan struct{}),
-		hashrate: metrics.NewMeter(),
-	}
+	return New(Config{CachesInMem: 1, PowMode: ModeTest})
 }
 
 // NewFaker creates a ethash consensus engine with a fake PoW scheme that accepts
@@ -456,126 +492,40 @@ func NewShared() *Ethash {
 // cache tries to retrieve a verification cache for the specified block number
 // by first checking against a list of in-memory caches, then against caches
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) cache(block uint64) []uint32 {
+func (ethash *Ethash) cache(block uint64) *cache {
 	epoch := block / epochLength
+	currentI, futureI := ethash.caches.get(epoch)
+	current := currentI.(*cache)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.caches[epoch], (*cache)(nil)
-	if current == nil {
-		// No in-memory cache, evict the oldest if the cache limit was reached
-		for len(ethash.caches) > 0 && len(ethash.caches) >= ethash.config.CachesInMem {
-			var evict *cache
-			for _, cache := range ethash.caches {
-				if evict == nil || evict.used.After(cache.used) {
-					evict = cache
-				}
-			}
-			delete(ethash.caches, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash cache", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fcache != nil && ethash.fcache.epoch == epoch {
-			log.Trace("Using pre-generated cache", "epoch", epoch)
-			current, ethash.fcache = ethash.fcache, nil
-		} else {
-			log.Trace("Requiring new ethash cache", "epoch", epoch)
-			current = &cache{epoch: epoch}
-		}
-		ethash.caches[epoch] = current
-
-		// If we just used up the future cache, or need a refresh, regenerate
-		if ethash.fcache == nil || ethash.fcache.epoch <= epoch {
-			if ethash.fcache != nil {
-				ethash.fcache.release()
-			}
-			log.Trace("Requiring new future ethash cache", "epoch", epoch+1)
-			future = &cache{epoch: epoch + 1}
-			ethash.fcache = future
-		}
-		// New current cache, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future cache, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future cache, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*cache)
 		go future.generate(ethash.config.CacheDir, ethash.config.CachesOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.cache
+	return current
 }
 
 // dataset tries to retrieve a mining dataset for the specified block number
 // by first checking against a list of in-memory datasets, then against DAGs
 // stored on disk, and finally generating one if none can be found.
-func (ethash *Ethash) dataset(block uint64) []uint32 {
+func (ethash *Ethash) dataset(block uint64) *dataset {
 	epoch := block / epochLength
+	currentI, futureI := ethash.datasets.get(epoch)
+	current := currentI.(*dataset)
 
-	// If we have a PoW for that epoch, use that
-	ethash.lock.Lock()
-
-	current, future := ethash.datasets[epoch], (*dataset)(nil)
-	if current == nil {
-		// No in-memory dataset, evict the oldest if the dataset limit was reached
-		for len(ethash.datasets) > 0 && len(ethash.datasets) >= ethash.config.DatasetsInMem {
-			var evict *dataset
-			for _, dataset := range ethash.datasets {
-				if evict == nil || evict.used.After(dataset.used) {
-					evict = dataset
-				}
-			}
-			delete(ethash.datasets, evict.epoch)
-			evict.release()
-
-			log.Trace("Evicted ethash dataset", "epoch", evict.epoch, "used", evict.used)
-		}
-		// If we have the new cache pre-generated, use that, otherwise create a new one
-		if ethash.fdataset != nil && ethash.fdataset.epoch == epoch {
-			log.Trace("Using pre-generated dataset", "epoch", epoch)
-			current = &dataset{epoch: ethash.fdataset.epoch} // Reload from disk
-			ethash.fdataset = nil
-		} else {
-			log.Trace("Requiring new ethash dataset", "epoch", epoch)
-			current = &dataset{epoch: epoch}
-		}
-		ethash.datasets[epoch] = current
-
-		// If we just used up the future dataset, or need a refresh, regenerate
-		if ethash.fdataset == nil || ethash.fdataset.epoch <= epoch {
-			if ethash.fdataset != nil {
-				ethash.fdataset.release()
-			}
-			log.Trace("Requiring new future ethash dataset", "epoch", epoch+1)
-			future = &dataset{epoch: epoch + 1}
-			ethash.fdataset = future
-		}
-		// New current dataset, set its initial timestamp
-		current.used = time.Now()
-	}
-	ethash.lock.Unlock()
-
-	// Wait for generation finish, bump the timestamp and finalize the cache
+	// Wait for generation finish.
 	current.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 
-	current.lock.Lock()
-	current.used = time.Now()
-	current.lock.Unlock()
-
-	// If we exhausted the future dataset, now's a good time to regenerate it
-	if future != nil {
+	// If we need a new future dataset, now's a good time to regenerate it.
+	if futureI != nil {
+		future := futureI.(*dataset)
 		go future.generate(ethash.config.DatasetDir, ethash.config.DatasetsOnDisk, ethash.config.PowMode == ModeTest)
 	}
-	return current.dataset
+
+	return current
 }
 
 // Threads returns the number of mining threads currently enabled. This doesn't
diff --git a/consensus/ethash/ethash_test.go b/consensus/ethash/ethash_test.go
index b3a2f32f7..31116da43 100644
--- a/consensus/ethash/ethash_test.go
+++ b/consensus/ethash/ethash_test.go
@@ -17,7 +17,11 @@
 package ethash
 
 import (
+	"io/ioutil"
 	"math/big"
+	"math/rand"
+	"os"
+	"sync"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/core/types"
@@ -38,3 +42,38 @@ func TestTestMode(t *testing.T) {
 		t.Fatalf("unexpected verification error: %v", err)
 	}
 }
+
+// This test checks that cache lru logic doesn't crash under load.
+// It reproduces https://github.com/ethereum/go-ethereum/issues/14943
+func TestCacheFileEvict(t *testing.T) {
+	tmpdir, err := ioutil.TempDir("", "ethash-test")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer os.RemoveAll(tmpdir)
+	e := New(Config{CachesInMem: 3, CachesOnDisk: 10, CacheDir: tmpdir, PowMode: ModeTest})
+
+	workers := 8
+	epochs := 100
+	var wg sync.WaitGroup
+	wg.Add(workers)
+	for i := 0; i < workers; i++ {
+		go verifyTest(&wg, e, i, epochs)
+	}
+	wg.Wait()
+}
+
+func verifyTest(wg *sync.WaitGroup, e *Ethash, workerIndex, epochs int) {
+	defer wg.Done()
+
+	const wiggle = 4 * epochLength
+	r := rand.New(rand.NewSource(int64(workerIndex)))
+	for epoch := 0; epoch < epochs; epoch++ {
+		block := int64(epoch)*epochLength - wiggle/2 + r.Int63n(wiggle)
+		if block < 0 {
+			block = 0
+		}
+		head := &types.Header{Number: big.NewInt(block), Difficulty: big.NewInt(100)}
+		e.VerifySeal(nil, head)
+	}
+}
diff --git a/consensus/ethash/sealer.go b/consensus/ethash/sealer.go
index c2447e473..b5e742d8b 100644
--- a/consensus/ethash/sealer.go
+++ b/consensus/ethash/sealer.go
@@ -97,10 +97,9 @@ func (ethash *Ethash) Seal(chain consensus.ChainReader, block *types.Block, stop
 func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan struct{}, found chan *types.Block) {
 	// Extract some data from the header
 	var (
-		header = block.Header()
-		hash   = header.HashNoNonce().Bytes()
-		target = new(big.Int).Div(maxUint256, header.Difficulty)
-
+		header  = block.Header()
+		hash    = header.HashNoNonce().Bytes()
+		target  = new(big.Int).Div(maxUint256, header.Difficulty)
 		number  = header.Number.Uint64()
 		dataset = ethash.dataset(number)
 	)
@@ -111,13 +110,14 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 	)
 	logger := log.New("miner", id)
 	logger.Trace("Started ethash search for new nonces", "seed", seed)
+search:
 	for {
 		select {
 		case <-abort:
 			// Mining terminated, update stats and abort
 			logger.Trace("Ethash nonce search aborted", "attempts", nonce-seed)
 			ethash.hashrate.Mark(attempts)
-			return
+			break search
 
 		default:
 			// We don't have to update hash rate on every nonce, so update after after 2^X nonces
@@ -127,7 +127,7 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				attempts = 0
 			}
 			// Compute the PoW value of this nonce
-			digest, result := hashimotoFull(dataset, hash, nonce)
+			digest, result := hashimotoFull(dataset.dataset, hash, nonce)
 			if new(big.Int).SetBytes(result).Cmp(target) <= 0 {
 				// Correct nonce found, create a new header with it
 				header = types.CopyHeader(header)
@@ -141,9 +141,12 @@ func (ethash *Ethash) mine(block *types.Block, id int, seed uint64, abort chan s
 				case <-abort:
 					logger.Trace("Ethash nonce found but discarded", "attempts", nonce-seed, "nonce", nonce)
 				}
-				return
+				break search
 			}
 			nonce++
 		}
 	}
+	// Datasets are unmapped in a finalizer. Ensure that the dataset stays live
+	// during sealing so it's not unmapped while being read.
+	runtime.KeepAlive(dataset)
 }
