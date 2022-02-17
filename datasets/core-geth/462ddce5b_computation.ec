commit 462ddce5b2a47835d057e3950ee5feb9d6c7bc10
Author: Luke Champine <luke.champine@gmail.com>
Date:   Fri Apr 3 05:57:24 2020 -0400

    crypto/ecies: improve concatKDF (#20836)
    
    This removes a bunch of weird code around the counter overflow check in
    concatKDF and makes it actually work for different hash output sizes.
    
    The overflow check worked as follows: concatKDF applies the hash function N
    times, where N is roundup(kdLen, hashsize) / hashsize. N should not
    overflow 32 bits because that would lead to a repetition in the KDF output.
    
    A couple issues with the overflow check:
    
    - It used the hash.BlockSize, which is wrong because the
      block size is about the input of the hash function. Luckily, all standard
      hash functions have a block size that's greater than the output size, so
      concatKDF didn't crash, it just generated too much key material.
    - The check used big.Int to compare against 2^32-1.
    - The calculation could still overflow before reaching the check.
    
    The new code in concatKDF doesn't check for overflow. Instead, there is a
    new check on ECIESParams which ensures that params.KeyLen is < 512. This
    removes any possibility of overflow.
    
    There are a couple of miscellaneous improvements bundled in with this
    change:
    
    - The key buffer is pre-allocated instead of appending the hash output
      to an initially empty slice.
    - The code that uses concatKDF to derive keys is now shared between Encrypt
      and Decrypt.
    - There was a redundant invocation of IsOnCurve in Decrypt. This is now removed
      because elliptic.Unmarshal already checks whether the input is a valid curve
      point since Go 1.5.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/crypto/ecies/ecies.go b/crypto/ecies/ecies.go
index 147418148..64b5a99d0 100644
--- a/crypto/ecies/ecies.go
+++ b/crypto/ecies/ecies.go
@@ -35,6 +35,7 @@ import (
 	"crypto/elliptic"
 	"crypto/hmac"
 	"crypto/subtle"
+	"encoding/binary"
 	"fmt"
 	"hash"
 	"io"
@@ -44,7 +45,6 @@ import (
 var (
 	ErrImport                     = fmt.Errorf("ecies: failed to import key")
 	ErrInvalidCurve               = fmt.Errorf("ecies: invalid elliptic curve")
-	ErrInvalidParams              = fmt.Errorf("ecies: invalid ECIES parameters")
 	ErrInvalidPublicKey           = fmt.Errorf("ecies: invalid public key")
 	ErrSharedKeyIsPointAtInfinity = fmt.Errorf("ecies: shared key is point at infinity")
 	ErrSharedKeyTooBig            = fmt.Errorf("ecies: shared key params are too big")
@@ -138,57 +138,39 @@ func (prv *PrivateKey) GenerateShared(pub *PublicKey, skLen, macLen int) (sk []b
 }
 
 var (
-	ErrKeyDataTooLong = fmt.Errorf("ecies: can't supply requested key data")
 	ErrSharedTooLong  = fmt.Errorf("ecies: shared secret is too long")
 	ErrInvalidMessage = fmt.Errorf("ecies: invalid message")
 )
 
-var (
-	big2To32   = new(big.Int).Exp(big.NewInt(2), big.NewInt(32), nil)
-	big2To32M1 = new(big.Int).Sub(big2To32, big.NewInt(1))
-)
-
-func incCounter(ctr []byte) {
-	if ctr[3]++; ctr[3] != 0 {
-		return
-	}
-	if ctr[2]++; ctr[2] != 0 {
-		return
-	}
-	if ctr[1]++; ctr[1] != 0 {
-		return
-	}
-	if ctr[0]++; ctr[0] != 0 {
-		return
-	}
-}
-
 // NIST SP 800-56 Concatenation Key Derivation Function (see section 5.8.1).
-func concatKDF(hash hash.Hash, z, s1 []byte, kdLen int) (k []byte, err error) {
-	if s1 == nil {
-		s1 = make([]byte, 0)
-	}
-
-	reps := ((kdLen + 7) * 8) / (hash.BlockSize() * 8)
-	if big.NewInt(int64(reps)).Cmp(big2To32M1) > 0 {
-		fmt.Println(big2To32M1)
-		return nil, ErrKeyDataTooLong
-	}
-
-	counter := []byte{0, 0, 0, 1}
-	k = make([]byte, 0)
-
-	for i := 0; i <= reps; i++ {
-		hash.Write(counter)
+func concatKDF(hash hash.Hash, z, s1 []byte, kdLen int) []byte {
+	counterBytes := make([]byte, 4)
+	k := make([]byte, 0, roundup(kdLen, hash.Size()))
+	for counter := uint32(1); len(k) < kdLen; counter++ {
+		binary.BigEndian.PutUint32(counterBytes, counter)
+		hash.Reset()
+		hash.Write(counterBytes)
 		hash.Write(z)
 		hash.Write(s1)
-		k = append(k, hash.Sum(nil)...)
-		hash.Reset()
-		incCounter(counter)
+		k = hash.Sum(k)
 	}
+	return k[:kdLen]
+}
 
-	k = k[:kdLen]
-	return
+// roundup rounds size up to the next multiple of blocksize.
+func roundup(size, blocksize int) int {
+	return size + blocksize - (size % blocksize)
+}
+
+// deriveKeys creates the encryption and MAC keys using concatKDF.
+func deriveKeys(hash hash.Hash, z, s1 []byte, keyLen int) (Ke, Km []byte) {
+	K := concatKDF(hash, z, s1, 2*keyLen)
+	Ke = K[:keyLen]
+	Km = K[keyLen:]
+	hash.Reset()
+	hash.Write(Km)
+	Km = hash.Sum(Km[:0])
+	return Ke, Km
 }
 
 // messageTag computes the MAC of a message (called the tag) as per
@@ -209,7 +191,6 @@ func generateIV(params *ECIESParams, rand io.Reader) (iv []byte, err error) {
 }
 
 // symEncrypt carries out CTR encryption using the block cipher specified in the
-// parameters.
 func symEncrypt(rand io.Reader, params *ECIESParams, key, m []byte) (ct []byte, err error) {
 	c, err := params.Cipher(key)
 	if err != nil {
@@ -249,36 +230,27 @@ func symDecrypt(params *ECIESParams, key, ct []byte) (m []byte, err error) {
 // ciphertext. s1 is fed into key derivation, s2 is fed into the MAC. If the
 // shared information parameters aren't being used, they should be nil.
 func Encrypt(rand io.Reader, pub *PublicKey, m, s1, s2 []byte) (ct []byte, err error) {
-	params := pub.Params
-	if params == nil {
-		if params = ParamsFromCurve(pub.Curve); params == nil {
-			err = ErrUnsupportedECIESParameters
-			return
-		}
+	params, err := pubkeyParams(pub)
+	if err != nil {
+		return nil, err
 	}
+
 	R, err := GenerateKey(rand, pub.Curve, params)
 	if err != nil {
-		return
+		return nil, err
 	}
 
-	hash := params.Hash()
 	z, err := R.GenerateShared(pub, params.KeyLen, params.KeyLen)
 	if err != nil {
-		return
-	}
-	K, err := concatKDF(hash, z, s1, params.KeyLen+params.KeyLen)
-	if err != nil {
-		return
+		return nil, err
 	}
-	Ke := K[:params.KeyLen]
-	Km := K[params.KeyLen:]
-	hash.Write(Km)
-	Km = hash.Sum(nil)
-	hash.Reset()
+
+	hash := params.Hash()
+	Ke, Km := deriveKeys(hash, z, s1, params.KeyLen)
 
 	em, err := symEncrypt(rand, params, Ke, m)
 	if err != nil || len(em) <= params.BlockSize {
-		return
+		return nil, err
 	}
 
 	d := messageTag(params.Hash, Km, em, s2)
@@ -288,7 +260,7 @@ func Encrypt(rand io.Reader, pub *PublicKey, m, s1, s2 []byte) (ct []byte, err e
 	copy(ct, Rb)
 	copy(ct[len(Rb):], em)
 	copy(ct[len(Rb)+len(em):], d)
-	return
+	return ct, nil
 }
 
 // Decrypt decrypts an ECIES ciphertext.
@@ -296,13 +268,11 @@ func (prv *PrivateKey) Decrypt(c, s1, s2 []byte) (m []byte, err error) {
 	if len(c) == 0 {
 		return nil, ErrInvalidMessage
 	}
-	params := prv.PublicKey.Params
-	if params == nil {
-		if params = ParamsFromCurve(prv.PublicKey.Curve); params == nil {
-			err = ErrUnsupportedECIESParameters
-			return
-		}
+	params, err := pubkeyParams(&prv.PublicKey)
+	if err != nil {
+		return nil, err
 	}
+
 	hash := params.Hash()
 
 	var (
@@ -316,12 +286,10 @@ func (prv *PrivateKey) Decrypt(c, s1, s2 []byte) (m []byte, err error) {
 	case 2, 3, 4:
 		rLen = (prv.PublicKey.Curve.Params().BitSize + 7) / 4
 		if len(c) < (rLen + hLen + 1) {
-			err = ErrInvalidMessage
-			return
+			return nil, ErrInvalidMessage
 		}
 	default:
-		err = ErrInvalidPublicKey
-		return
+		return nil, ErrInvalidPublicKey
 	}
 
 	mStart = rLen
@@ -331,36 +299,19 @@ func (prv *PrivateKey) Decrypt(c, s1, s2 []byte) (m []byte, err error) {
 	R.Curve = prv.PublicKey.Curve
 	R.X, R.Y = elliptic.Unmarshal(R.Curve, c[:rLen])
 	if R.X == nil {
-		err = ErrInvalidPublicKey
-		return
-	}
-	if !R.Curve.IsOnCurve(R.X, R.Y) {
-		err = ErrInvalidCurve
-		return
+		return nil, ErrInvalidPublicKey
 	}
 
 	z, err := prv.GenerateShared(R, params.KeyLen, params.KeyLen)
 	if err != nil {
-		return
+		return nil, err
 	}
-
-	K, err := concatKDF(hash, z, s1, params.KeyLen+params.KeyLen)
-	if err != nil {
-		return
-	}
-
-	Ke := K[:params.KeyLen]
-	Km := K[params.KeyLen:]
-	hash.Write(Km)
-	Km = hash.Sum(nil)
-	hash.Reset()
+	Ke, Km := deriveKeys(hash, z, s1, params.KeyLen)
 
 	d := messageTag(params.Hash, Km, c[mStart:mEnd], s2)
 	if subtle.ConstantTimeCompare(c[mEnd:], d) != 1 {
-		err = ErrInvalidMessage
-		return
+		return nil, ErrInvalidMessage
 	}
 
-	m, err = symDecrypt(params, Ke, c[mStart:mEnd])
-	return
+	return symDecrypt(params, Ke, c[mStart:mEnd])
 }
diff --git a/crypto/ecies/ecies_test.go b/crypto/ecies/ecies_test.go
index b465f076f..0a6aeb2b5 100644
--- a/crypto/ecies/ecies_test.go
+++ b/crypto/ecies/ecies_test.go
@@ -42,17 +42,23 @@ import (
 	"github.com/ethereum/go-ethereum/crypto"
 )
 
-// Ensure the KDF generates appropriately sized keys.
 func TestKDF(t *testing.T) {
-	msg := []byte("Hello, world")
-	h := sha256.New()
-
-	k, err := concatKDF(h, msg, nil, 64)
-	if err != nil {
-		t.Fatal(err)
-	}
-	if len(k) != 64 {
-		t.Fatalf("KDF: generated key is the wrong size (%d instead of 64\n", len(k))
+	tests := []struct {
+		length int
+		output []byte
+	}{
+		{6, decode("858b192fa2ed")},
+		{32, decode("858b192fa2ed4395e2bf88dd8d5770d67dc284ee539f12da8bceaa45d06ebae0")},
+		{48, decode("858b192fa2ed4395e2bf88dd8d5770d67dc284ee539f12da8bceaa45d06ebae0700f1ab918a5f0413b8140f9940d6955")},
+		{64, decode("858b192fa2ed4395e2bf88dd8d5770d67dc284ee539f12da8bceaa45d06ebae0700f1ab918a5f0413b8140f9940d6955f3467fd6672cce1024c5b1effccc0f61")},
+	}
+
+	for _, test := range tests {
+		h := sha256.New()
+		k := concatKDF(h, []byte("input"), nil, test.length)
+		if !bytes.Equal(k, test.output) {
+			t.Fatalf("KDF: generated key %x does not match expected output %x", k, test.output)
+		}
 	}
 }
 
@@ -293,8 +299,8 @@ func TestParamSelection(t *testing.T) {
 
 func testParamSelection(t *testing.T, c testCase) {
 	params := ParamsFromCurve(c.Curve)
-	if params == nil && c.Expected != nil {
-		t.Fatalf("%s (%s)\n", ErrInvalidParams.Error(), c.Name)
+	if params == nil {
+		t.Fatal("ParamsFromCurve returned nil")
 	} else if params != nil && !cmpParams(params, c.Expected) {
 		t.Fatalf("ecies: parameters should be invalid (%s)\n", c.Name)
 	}
@@ -401,7 +407,7 @@ func TestSharedKeyStatic(t *testing.T) {
 		t.Fatal(ErrBadSharedKeys)
 	}
 
-	sk, _ := hex.DecodeString("167ccc13ac5e8a26b131c3446030c60fbfac6aa8e31149d0869f93626a4cdf62")
+	sk := decode("167ccc13ac5e8a26b131c3446030c60fbfac6aa8e31149d0869f93626a4cdf62")
 	if !bytes.Equal(sk1, sk) {
 		t.Fatalf("shared secret mismatch: want: %x have: %x", sk, sk1)
 	}
@@ -414,3 +420,11 @@ func hexKey(prv string) *PrivateKey {
 	}
 	return ImportECDSA(key)
 }
+
+func decode(s string) []byte {
+	bytes, err := hex.DecodeString(s)
+	if err != nil {
+		panic(err)
+	}
+	return bytes
+}
diff --git a/crypto/ecies/params.go b/crypto/ecies/params.go
index 6312daf5a..0bd3877dd 100644
--- a/crypto/ecies/params.go
+++ b/crypto/ecies/params.go
@@ -49,8 +49,14 @@ var (
 	DefaultCurve                  = ethcrypto.S256()
 	ErrUnsupportedECDHAlgorithm   = fmt.Errorf("ecies: unsupported ECDH algorithm")
 	ErrUnsupportedECIESParameters = fmt.Errorf("ecies: unsupported ECIES parameters")
+	ErrInvalidKeyLen              = fmt.Errorf("ecies: invalid key size (> %d) in ECIESParams", maxKeyLen)
 )
 
+// KeyLen is limited to prevent overflow of the counter
+// in concatKDF. While the theoretical limit is much higher,
+// no known cipher uses keys larger than 512 bytes.
+const maxKeyLen = 512
+
 type ECIESParams struct {
 	Hash      func() hash.Hash // hash function
 	hashAlgo  crypto.Hash
@@ -115,3 +121,16 @@ func AddParamsForCurve(curve elliptic.Curve, params *ECIESParams) {
 func ParamsFromCurve(curve elliptic.Curve) (params *ECIESParams) {
 	return paramsFromCurve[curve]
 }
+
+func pubkeyParams(key *PublicKey) (*ECIESParams, error) {
+	params := key.Params
+	if params == nil {
+		if params = ParamsFromCurve(key.Curve); params == nil {
+			return nil, ErrUnsupportedECIESParameters
+		}
+	}
+	if params.KeyLen > maxKeyLen {
+		return nil, ErrInvalidKeyLen
+	}
+	return params, nil
+}
