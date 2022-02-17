commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
    This commit makes it consistent again. Both types now support the %v,
    %s, %q format verbs for 0x-prefixed hex output. %x, %X creates
    unprefixed hex output. %d is also supported and returns the decimal
    notation "[1 2 3...]".
    
    For Address, the case of hex characters in %v, %s, %q output is
    determined using the EIP-55 checksum. Using %x, %X with Address
    disables checksumming.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/common/types.go b/common/types.go
index 94cf622e8..d920e8b1f 100644
--- a/common/types.go
+++ b/common/types.go
@@ -17,6 +17,7 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/hex"
 	"encoding/json"
@@ -84,10 +85,34 @@ func (h Hash) String() string {
 	return h.Hex()
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Hash supports the %v, %s, %v, %x, %X and %d format verbs.
 func (h Hash) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), h[:])
+	hexb := make([]byte, 2+len(h)*2)
+	copy(hexb, "0x")
+	hex.Encode(hexb[2:], h[:])
+
+	switch c {
+	case 'x', 'X':
+		if !s.Flag('#') {
+			hexb = hexb[2:]
+		}
+		if c == 'X' {
+			hexb = bytes.ToUpper(hexb)
+		}
+		fallthrough
+	case 'v', 's':
+		s.Write(hexb)
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(hexb)
+		s.Write(q)
+	case 'd':
+		fmt.Fprint(s, ([len(h)]byte)(h))
+	default:
+		fmt.Fprintf(s, "%%!%c(hash=%x)", c, h)
+	}
 }
 
 // UnmarshalText parses a hash in hex syntax.
@@ -208,35 +233,68 @@ func (a Address) Hash() Hash { return BytesToHash(a[:]) }
 
 // Hex returns an EIP55-compliant hex string representation of the address.
 func (a Address) Hex() string {
-	unchecksummed := hex.EncodeToString(a[:])
+	return string(a.checksumHex())
+}
+
+// String implements fmt.Stringer.
+func (a Address) String() string {
+	return a.Hex()
+}
+
+func (a *Address) checksumHex() []byte {
+	buf := a.hex()
+
+	// compute checksum
 	sha := sha3.NewLegacyKeccak256()
-	sha.Write([]byte(unchecksummed))
+	sha.Write(buf[2:])
 	hash := sha.Sum(nil)
-
-	result := []byte(unchecksummed)
-	for i := 0; i < len(result); i++ {
-		hashByte := hash[i/2]
+	for i := 2; i < len(buf); i++ {
+		hashByte := hash[(i-2)/2]
 		if i%2 == 0 {
 			hashByte = hashByte >> 4
 		} else {
 			hashByte &= 0xf
 		}
-		if result[i] > '9' && hashByte > 7 {
-			result[i] -= 32
+		if buf[i] > '9' && hashByte > 7 {
+			buf[i] -= 32
 		}
 	}
-	return "0x" + string(result)
+	return buf[:]
 }
 
-// String implements fmt.Stringer.
-func (a Address) String() string {
-	return a.Hex()
+func (a Address) hex() []byte {
+	var buf [len(a)*2 + 2]byte
+	copy(buf[:2], "0x")
+	hex.Encode(buf[2:], a[:])
+	return buf[:]
 }
 
-// Format implements fmt.Formatter, forcing the byte slice to be formatted as is,
-// without going through the stringer interface used for logging.
+// Format implements fmt.Formatter.
+// Address supports the %v, %s, %v, %x, %X and %d format verbs.
 func (a Address) Format(s fmt.State, c rune) {
-	fmt.Fprintf(s, "%"+string(c), a[:])
+	switch c {
+	case 'v', 's':
+		s.Write(a.checksumHex())
+	case 'q':
+		q := []byte{'"'}
+		s.Write(q)
+		s.Write(a.checksumHex())
+		s.Write(q)
+	case 'x', 'X':
+		// %x disables the checksum.
+		hex := a.hex()
+		if !s.Flag('#') {
+			hex = hex[2:]
+		}
+		if c == 'X' {
+			hex = bytes.ToUpper(hex)
+		}
+		s.Write(hex)
+	case 'd':
+		fmt.Fprint(s, ([len(a)]byte)(a))
+	default:
+		fmt.Fprintf(s, "%%!%c(address=%x)", c, a)
+	}
 }
 
 // SetBytes sets the address to the value of b.
diff --git a/common/types_test.go b/common/types_test.go
index fffd673c6..318e985f8 100644
--- a/common/types_test.go
+++ b/common/types_test.go
@@ -17,8 +17,10 @@
 package common
 
 import (
+	"bytes"
 	"database/sql/driver"
 	"encoding/json"
+	"fmt"
 	"math/big"
 	"reflect"
 	"strings"
@@ -371,3 +373,167 @@ func TestAddress_Value(t *testing.T) {
 		})
 	}
 }
+
+func TestAddress_Format(t *testing.T) {
+	b := []byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+	}
+	var addr Address
+	addr.SetBytes(b)
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", addr)
+				return buf.String()
+			}(),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", addr),
+			want: `"0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", addr),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", addr),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", addr),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", addr),
+			want: "0xB26f2b342AAb24BCF63ea218c6A9274D30Ab9A15",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", addr),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", addr),
+			want: "%!t(address=b26f2b342aab24bcf63ea218c6a9274d30ab9a15)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
+
+func TestHash_Format(t *testing.T) {
+	var hash Hash
+	hash.SetBytes([]byte{
+		0xb2, 0x6f, 0x2b, 0x34, 0x2a, 0xab, 0x24, 0xbc, 0xf6, 0x3e,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0xa2, 0x18, 0xc6, 0xa9, 0x27, 0x4d, 0x30, 0xab, 0x9a, 0x15,
+		0x10, 0x00,
+	})
+
+	tests := []struct {
+		name string
+		out  string
+		want string
+	}{
+		{
+			name: "println",
+			out:  fmt.Sprintln(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000\n",
+		},
+		{
+			name: "print",
+			out:  fmt.Sprint(hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-s",
+			out: func() string {
+				buf := new(bytes.Buffer)
+				fmt.Fprintf(buf, "%s", hash)
+				return buf.String()
+			}(),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-q",
+			out:  fmt.Sprintf("%q", hash),
+			want: `"0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000"`,
+		},
+		{
+			name: "printf-x",
+			out:  fmt.Sprintf("%x", hash),
+			want: "b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-X",
+			out:  fmt.Sprintf("%X", hash),
+			want: "B26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-#x",
+			out:  fmt.Sprintf("%#x", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		{
+			name: "printf-#X",
+			out:  fmt.Sprintf("%#X", hash),
+			want: "0XB26F2B342AAB24BCF63EA218C6A9274D30AB9A15A218C6A9274D30AB9A151000",
+		},
+		{
+			name: "printf-v",
+			out:  fmt.Sprintf("%v", hash),
+			want: "0xb26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000",
+		},
+		// The original default formatter for byte slice
+		{
+			name: "printf-d",
+			out:  fmt.Sprintf("%d", hash),
+			want: "[178 111 43 52 42 171 36 188 246 62 162 24 198 169 39 77 48 171 154 21 162 24 198 169 39 77 48 171 154 21 16 0]",
+		},
+		// Invalid format char.
+		{
+			name: "printf-t",
+			out:  fmt.Sprintf("%t", hash),
+			want: "%!t(hash=b26f2b342aab24bcf63ea218c6a9274d30ab9a15a218c6a9274d30ab9a151000)",
+		},
+	}
+	for _, tt := range tests {
+		t.Run(tt.name, func(t *testing.T) {
+			if tt.out != tt.want {
+				t.Errorf("%s does not render as expected:\n got %s\nwant %s", tt.name, tt.out, tt.want)
+			}
+		})
+	}
+}
