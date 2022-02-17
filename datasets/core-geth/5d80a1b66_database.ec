commit 5d80a1b6652b1c5eb50b73e9582d9000829d7c9a
Author: Guillaume Ballet <gballet@gmail.com>
Date:   Tue Nov 20 20:14:37 2018 +0100

    whisper/mailserver: reduce the max number of opened files (#18142)
    
    This should reduce the occurences of travis failures on MacOS
    
    Also fix some linter warnings

diff --git a/whisper/mailserver/mailserver.go b/whisper/mailserver/mailserver.go
index af9418d9f..d7af4baae 100644
--- a/whisper/mailserver/mailserver.go
+++ b/whisper/mailserver/mailserver.go
@@ -14,6 +14,7 @@
 // You should have received a copy of the GNU Lesser General Public License
 // along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
 
+// Package mailserver provides a naive, example mailserver implementation
 package mailserver
 
 import (
@@ -26,9 +27,11 @@ import (
 	"github.com/ethereum/go-ethereum/rlp"
 	whisper "github.com/ethereum/go-ethereum/whisper/whisperv6"
 	"github.com/syndtr/goleveldb/leveldb"
+	"github.com/syndtr/goleveldb/leveldb/opt"
 	"github.com/syndtr/goleveldb/leveldb/util"
 )
 
+// WMailServer represents the state data of the mailserver.
 type WMailServer struct {
 	db  *leveldb.DB
 	w   *whisper.Whisper
@@ -42,6 +45,8 @@ type DBKey struct {
 	raw       []byte
 }
 
+// NewDbKey is a helper function that creates a levelDB
+// key from a hash and an integer.
 func NewDbKey(t uint32, h common.Hash) *DBKey {
 	const sz = common.HashLength + 4
 	var k DBKey
@@ -53,6 +58,7 @@ func NewDbKey(t uint32, h common.Hash) *DBKey {
 	return &k
 }
 
+// Init initializes the mail server.
 func (s *WMailServer) Init(shh *whisper.Whisper, path string, password string, pow float64) error {
 	var err error
 	if len(path) == 0 {
@@ -63,7 +69,7 @@ func (s *WMailServer) Init(shh *whisper.Whisper, path string, password string, p
 		return fmt.Errorf("password is not specified")
 	}
 
-	s.db, err = leveldb.OpenFile(path, nil)
+	s.db, err = leveldb.OpenFile(path, &opt.Options{OpenFilesCacheCapacity: 32})
 	if err != nil {
 		return fmt.Errorf("open DB file: %s", err)
 	}
@@ -82,12 +88,14 @@ func (s *WMailServer) Init(shh *whisper.Whisper, path string, password string, p
 	return nil
 }
 
+// Close cleans up before shutdown.
 func (s *WMailServer) Close() {
 	if s.db != nil {
 		s.db.Close()
 	}
 }
 
+// Archive stores the
 func (s *WMailServer) Archive(env *whisper.Envelope) {
 	key := NewDbKey(env.Expiry-env.TTL, env.Hash())
 	rawEnvelope, err := rlp.EncodeToBytes(env)
@@ -101,6 +109,8 @@ func (s *WMailServer) Archive(env *whisper.Envelope) {
 	}
 }
 
+// DeliverMail responds with saved messages upon request by the
+// messages' owner.
 func (s *WMailServer) DeliverMail(peer *whisper.Peer, request *whisper.Envelope) {
 	if peer == nil {
 		log.Error("Whisper peer is nil")
