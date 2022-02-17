commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
