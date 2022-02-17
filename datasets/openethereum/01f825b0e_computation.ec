commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
commit 01f825b0e1f1c4c420197b51fc801cbe89284b29
Author: Jim Posen <jim.posen@gmail.com>
Date:   Wed Jul 11 12:22:06 2018 -0700

    Multiple improvements to discovery ping handling (#8771)
    
    * discovery: Only add nodes to routing table after receiving pong.
    
    Previously the discovery algorithm would add nodes to the routing table
    before confirming that the endpoint is participating in the protocol. This
    now tracks in-flight pings and adds to the routing table only after receiving
    a response.
    
    * discovery: Refactor packet creation into its own function.
    
    This function is useful inside unit tests.
    
    * discovery: Additional testing for new add_node behavior.
    
    * discovery: Track expiration of pings to non-yet-in-bucket nodes.
    
    Now that we may ping nodes before adding to a k-bucket, the timeout tracking
    must be separate from BucketEntry.
    
    * discovery: Verify echo hash on pong packets.
    
    Stores packet hash with in-flight requests and matches with pong response.
    
    * discovery: Track timeouts on FIND_NODE requests.
    
    * discovery: Retry failed pings with exponential backoff.
    
    UDP packets may get dropped, so instead of immediately booting nodes that fail
    to respond to a ping, retry 4 times with exponential backoff.
    
    * !fixup Use slice instead of Vec for request_backoff.

diff --git a/util/network-devp2p/src/discovery.rs b/util/network-devp2p/src/discovery.rs
index 3bf7aee1e..bc808c398 100644
--- a/util/network-devp2p/src/discovery.rs
+++ b/util/network-devp2p/src/discovery.rs
@@ -17,11 +17,12 @@
 use parity_bytes::Bytes;
 use std::net::SocketAddr;
 use std::collections::{HashSet, HashMap, VecDeque};
+use std::collections::hash_map::Entry;
 use std::default::Default;
 use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
 use hash::keccak;
 use ethereum_types::{H256, H520};
-use rlp::{Rlp, RlpStream, encode_list};
+use rlp::{Rlp, RlpStream};
 use node_table::*;
 use network::{Error, ErrorKind};
 use ethkey::{Secret, KeyPair, sign, recover};
@@ -42,7 +43,15 @@ const PACKET_FIND_NODE: u8 = 3;
 const PACKET_NEIGHBOURS: u8 = 4;
 
 const PING_TIMEOUT: Duration = Duration::from_millis(300);
+const FIND_NODE_TIMEOUT: Duration = Duration::from_secs(2);
+const EXPIRY_TIME: Duration = Duration::from_secs(60);
 const MAX_NODES_PING: usize = 32; // Max nodes to add/ping at once
+const REQUEST_BACKOFF: [Duration; 4] = [
+	Duration::from_secs(1),
+	Duration::from_secs(4),
+	Duration::from_secs(16),
+	Duration::from_secs(64)
+];
 
 #[derive(Clone, Debug)]
 pub struct NodeEntry {
@@ -53,13 +62,35 @@ pub struct NodeEntry {
 pub struct BucketEntry {
 	pub address: NodeEntry,
 	pub id_hash: H256,
-	pub timeout: Option<Instant>,
+	pub last_seen: Instant,
+	backoff_until: Instant,
+	fail_count: usize,
+}
+
+impl BucketEntry {
+	fn new(address: NodeEntry) -> Self {
+		let now = Instant::now();
+		BucketEntry {
+			id_hash: keccak(address.id),
+			address: address,
+			last_seen: now,
+			backoff_until: now,
+			fail_count: 0,
+		}
+	}
 }
 
 pub struct NodeBucket {
 	nodes: VecDeque<BucketEntry>, //sorted by last active
 }
 
+struct PendingRequest {
+	packet_id: u8,
+	sent_at: Instant,
+	packet_hash: H256,
+	response_count: usize, // Some requests (eg. FIND_NODE) have multi-packet responses
+}
+
 impl Default for NodeBucket {
 	fn default() -> Self {
 		NodeBucket::new()
@@ -79,7 +110,7 @@ pub struct Datagram {
 	pub address: SocketAddr,
 }
 
-pub struct Discovery {
+pub struct Discovery<'a> {
 	id: NodeId,
 	id_hash: H256,
 	secret: Secret,
@@ -88,10 +119,14 @@ pub struct Discovery {
 	discovery_id: NodeId,
 	discovery_nodes: HashSet<NodeId>,
 	node_buckets: Vec<NodeBucket>,
+	in_flight_requests: HashMap<NodeId, PendingRequest>,
+	expiring_pings: VecDeque<(NodeId, Instant)>,
+	expiring_finds: VecDeque<(NodeId, Instant)>,
 	send_queue: VecDeque<Datagram>,
 	check_timestamps: bool,
 	adding_nodes: Vec<NodeEntry>,
 	ip_filter: IpFilter,
+	request_backoff: &'a [Duration],
 }
 
 pub struct TableUpdates {
@@ -99,8 +134,8 @@ pub struct TableUpdates {
 	pub removed: HashSet<NodeId>,
 }
 
-impl Discovery {
-	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery {
+impl<'a> Discovery<'a> {
+	pub fn new(key: &KeyPair, public: NodeEndpoint, ip_filter: IpFilter) -> Discovery<'static> {
 		Discovery {
 			id: key.public().clone(),
 			id_hash: keccak(key.public()),
@@ -110,86 +145,80 @@ impl Discovery {
 			discovery_id: NodeId::new(),
 			discovery_nodes: HashSet::new(),
 			node_buckets: (0..ADDRESS_BITS).map(|_| NodeBucket::new()).collect(),
+			in_flight_requests: HashMap::new(),
+			expiring_pings: VecDeque::new(),
+			expiring_finds: VecDeque::new(),
 			send_queue: VecDeque::new(),
 			check_timestamps: true,
 			adding_nodes: Vec::new(),
 			ip_filter: ip_filter,
+			request_backoff: &REQUEST_BACKOFF,
 		}
 	}
 
 	/// Add a new node to discovery table. Pings the node.
 	pub fn add_node(&mut self, e: NodeEntry) {
-		if self.is_allowed(&e) {
-			let endpoint = e.endpoint.clone();
-			self.update_node(e);
-			self.ping(&endpoint);
+		// If distance returns None, then we are trying to add ourself.
+		let id_hash = keccak(e.id);
+		if let Some(dist) = Discovery::distance(&self.id_hash, &id_hash) {
+			if self.node_buckets[dist].nodes.iter().any(|n| n.id_hash == id_hash) {
+				return;
+			}
+			self.try_ping(e);
 		}
 	}
 
 	/// Add a list of nodes. Pings a few nodes each round
 	pub fn add_node_list(&mut self, nodes: Vec<NodeEntry>) {
-		self.adding_nodes = nodes;
-		self.update_new_nodes();
+		for node in nodes {
+			self.add_node(node);
+		}
 	}
 
 	/// Add a list of known nodes to the table.
-	pub fn init_node_list(&mut self, mut nodes: Vec<NodeEntry>) {
-		for n in nodes.drain(..) {
+	pub fn init_node_list(&mut self, nodes: Vec<NodeEntry>) {
+		for n in nodes {
 			if self.is_allowed(&n) {
 				self.update_node(n);
 			}
 		}
 	}
 
-	fn update_node(&mut self, e: NodeEntry) {
+	fn update_node(&mut self, e: NodeEntry) -> Option<TableUpdates> {
 		trace!(target: "discovery", "Inserting {:?}", &e);
 		let id_hash = keccak(e.id);
 		let dist = match Discovery::distance(&self.id_hash, &id_hash) {
 			Some(dist) => dist,
 			None => {
 				debug!(target: "discovery", "Attempted to update own entry: {:?}", e);
-				return;
+				return None;
 			}
 		};
 
+		let mut added_map = HashMap::new();
 		let ping = {
 			let bucket = &mut self.node_buckets[dist];
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
-				node.timeout = None;
+				node.last_seen = Instant::now();
+				node.backoff_until = Instant::now();
+				node.fail_count = 0;
 				true
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
-			}
+				added_map.insert(e.id, e.clone());
+				bucket.nodes.push_front(BucketEntry::new(e));
 
-			if bucket.nodes.len() > BUCKET_SIZE {
-				//ping least active node
-				let last = bucket.nodes.back_mut().expect("Last item is always present when len() > 0");
-				last.timeout = Some(Instant::now());
-				Some(last.address.endpoint.clone())
+				if bucket.nodes.len() > BUCKET_SIZE {
+					select_bucket_ping(bucket.nodes.iter())
+				} else { None }
 			} else { None }
 		};
-		if let Some(endpoint) = ping {
-			self.ping(&endpoint);
-		}
-	}
-
-	/// Removes the timeout of a given NodeId if it can be found in one of the discovery buckets
-	fn clear_ping(&mut self, id: &NodeId) {
-		let dist = match Discovery::distance(&self.id_hash, &keccak(id)) {
-			Some(dist) => dist,
-			None => {
-				debug!(target: "discovery", "Received ping from self");
-				return
-			}
-		};
-
-		let bucket = &mut self.node_buckets[dist];
-		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
-			node.timeout = None;
+		if let Some(node) = ping {
+			self.try_ping(node);
 		}
+		Some(TableUpdates { added: added_map, removed: HashSet::new() })
 	}
 
 	/// Starts the discovery process at round 0
@@ -201,11 +230,11 @@ impl Discovery {
 	}
 
 	fn update_new_nodes(&mut self) {
-		let mut count = 0usize;
-		while !self.adding_nodes.is_empty() && count < MAX_NODES_PING {
-			let node = self.adding_nodes.pop().expect("pop is always Some if not empty; qed");
-			self.add_node(node);
-			count += 1;
+		while self.in_flight_requests.len() < MAX_NODES_PING {
+			match self.adding_nodes.pop() {
+				Some(next) => self.try_ping(next),
+				None => break,
+			}
 		}
 	}
 
@@ -219,13 +248,17 @@ impl Discovery {
 		{
 			let nearest = self.nearest_node_entries(&self.discovery_id).into_iter();
 			let nearest = nearest.filter(|x| !self.discovery_nodes.contains(&x.id)).take(ALPHA).collect::<Vec<_>>();
+			let target = self.discovery_id.clone();
 			for r in nearest {
-				let rlp = encode_list(&(&[self.discovery_id.clone()][..]));
-				self.send_packet(PACKET_FIND_NODE, &r.endpoint.udp_address(), &rlp)
-					.unwrap_or_else(|e| warn!("Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e));
-				self.discovery_nodes.insert(r.id.clone());
-				tried_count += 1;
-				trace!(target: "discovery", "Sent FindNode to {:?}", &r.endpoint);
+				match self.send_find_node(&r, &target) {
+					Ok(()) => {
+						self.discovery_nodes.insert(r.id.clone());
+						tried_count += 1;
+					},
+					Err(e) => {
+						warn!(target: "discovery", "Error sending node discovery packet for {:?}: {:?}", &r.endpoint, e);
+					},
+				};
 			}
 		}
 
@@ -251,46 +284,71 @@ impl Discovery {
 		None // a and b are equal, so log distance is -inf
 	}
 
-	fn ping(&mut self, node: &NodeEndpoint) {
-		let mut rlp = RlpStream::new_list(3);
+	fn try_ping(&mut self, node: NodeEntry) {
+		if !self.is_allowed(&node) ||
+			self.in_flight_requests.contains_key(&node.id) ||
+			self.adding_nodes.iter().any(|n| n.id == node.id)
+		{
+			return;
+		}
+
+		if self.in_flight_requests.len() < MAX_NODES_PING {
+			self.ping(&node)
+				.unwrap_or_else(|e| {
+					warn!(target: "discovery", "Error sending Ping packet: {:?}", e);
+				});
+		} else {
+			self.adding_nodes.push(node);
+		}
+	}
+
+	fn ping(&mut self, node: &NodeEntry) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(4);
 		rlp.append(&PROTOCOL_VERSION);
 		self.public_endpoint.to_rlp_list(&mut rlp);
-		node.to_rlp_list(&mut rlp);
-		trace!(target: "discovery", "Sent Ping to {:?}", &node);
-		self.send_packet(PACKET_PING, &node.udp_address(), &rlp.drain())
-			.unwrap_or_else(|e| warn!("Error sending Ping packet: {:?}", e))
-	}
-
-	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<(), Error> {
-		let mut rlp = RlpStream::new();
-		rlp.append_raw(&[packet_id], 1);
-		let source = Rlp::new(payload);
-		rlp.begin_list(source.item_count()? + 1);
-		for i in 0 .. source.item_count()? {
-			rlp.append_raw(source.at(i)?.as_raw(), 1);
-		}
-		let timestamp = 60 + SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
-		rlp.append(&timestamp);
-
-		let bytes = rlp.drain();
-		let hash = keccak(bytes.as_ref());
-		let signature = match sign(&self.secret, &hash) {
-			Ok(s) => s,
-			Err(e) => {
-				warn!("Error signing UDP packet");
-				return Err(Error::from(e));
-			}
+		node.endpoint.to_rlp_list(&mut rlp);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_PING, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_PING,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
 		};
-		let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65);
-		packet.extend(hash.iter());
-		packet.extend(signature.iter());
-		packet.extend(bytes.iter());
-		let signed_hash = keccak(&packet[32..]);
-		packet[0..32].clone_from_slice(&signed_hash);
-		self.send_to(packet, address.clone());
+		self.expiring_pings.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent Ping to {:?}", &node.endpoint);
+		Ok(())
+	}
+
+	fn send_find_node(&mut self, node: &NodeEntry, target: &NodeId) -> Result<(), Error> {
+		let mut rlp = RlpStream::new_list(2);
+		rlp.append(target);
+		append_expiration(&mut rlp);
+		let hash = self.send_packet(PACKET_FIND_NODE, &node.endpoint.udp_address(), &rlp.drain())?;
+
+		let request_info = PendingRequest {
+			packet_id: PACKET_FIND_NODE,
+			sent_at: Instant::now(),
+			packet_hash: hash,
+			response_count: 0,
+		};
+		self.expiring_finds.push_back((node.id, request_info.sent_at));
+		self.in_flight_requests.insert(node.id, request_info);
+
+		trace!(target: "discovery", "Sent FindNode to {:?}", &node.endpoint);
 		Ok(())
 	}
 
+	fn send_packet(&mut self, packet_id: u8, address: &SocketAddr, payload: &[u8]) -> Result<H256, Error> {
+		let packet = assemble_packet(packet_id, payload, &self.secret)?;
+		let hash = H256::from(&packet[0..32]);
+		self.send_to(packet, address.clone());
+		Ok(hash)
+	}
+
 	fn nearest_node_entries(&self, target: &NodeId) -> Vec<NodeEntry> {
 		let target_hash = keccak(target);
 		let target_distance = self.id_hash ^ target_hash;
@@ -396,37 +454,57 @@ impl Discovery {
 		let dest = NodeEndpoint::from_rlp(&rlp.at(2)?)?;
 		let timestamp: u64 = rlp.val_at(3)?;
 		self.check_timestamp(timestamp)?;
-		let mut added_map = HashMap::new();
+
+		let mut response = RlpStream::new_list(3);
+		dest.to_rlp_list(&mut response);
+		response.append(&echo_hash);
+		append_expiration(&mut response);
+		self.send_packet(PACKET_PONG, from, &response.drain())?;
+
 		let entry = NodeEntry { id: node.clone(), endpoint: source.clone() };
 		if !entry.endpoint.is_valid() {
 			debug!(target: "discovery", "Got bad address: {:?}", entry);
 		} else if !self.is_allowed(&entry) {
 			debug!(target: "discovery", "Address not allowed: {:?}", entry);
 		} else {
-			self.update_node(entry.clone());
-			added_map.insert(node.clone(), entry);
+			self.add_node(entry.clone());
 		}
-		let mut response = RlpStream::new_list(2);
-		dest.to_rlp_list(&mut response);
-		response.append(&echo_hash);
-		self.send_packet(PACKET_PONG, from, &response.drain())?;
 
-		Ok(Some(TableUpdates { added: added_map, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn on_pong(&mut self, rlp: &Rlp, node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+	fn on_pong(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
 		trace!(target: "discovery", "Got Pong from {:?}", &from);
-		// TODO: validate pong packet in rlp.val_at(1)
 		let dest = NodeEndpoint::from_rlp(&rlp.at(0)?)?;
+		let echo_hash: H256 = rlp.val_at(1)?;
 		let timestamp: u64 = rlp.val_at(2)?;
 		self.check_timestamp(timestamp)?;
-		let mut entry = NodeEntry { id: node.clone(), endpoint: dest };
-		if !entry.endpoint.is_valid() {
-			debug!(target: "discovery", "Bad address: {:?}", entry);
-			entry.endpoint.address = from.clone();
+		let mut node = NodeEntry { id: node_id.clone(), endpoint: dest };
+		if !node.endpoint.is_valid() {
+			debug!(target: "discovery", "Bad address: {:?}", node);
+			node.endpoint.address = from.clone();
+		}
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(entry) => {
+				let is_expected = {
+					let request = entry.get();
+					request.packet_id == PACKET_PING && request.packet_hash == echo_hash
+				};
+				if is_expected {
+					entry.remove();
+				}
+				is_expected
+			},
+			Entry::Vacant(_) => false
+		};
+
+		if is_expected {
+			Ok(self.update_node(node))
+		} else {
+			debug!(target: "discovery", "Got unexpected Pong from {:?}", &from);
+			Ok(None)
 		}
-		self.clear_ping(node);
-		Ok(None)
 	}
 
 	fn on_find_node(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
@@ -450,22 +528,49 @@ impl Discovery {
 		let limit = (MAX_DATAGRAM_SIZE - 109) / 90;
 		let chunks = nearest.chunks(limit);
 		let packets = chunks.map(|c| {
-			let mut rlp = RlpStream::new_list(1);
+			let mut rlp = RlpStream::new_list(2);
 			rlp.begin_list(c.len());
 			for n in 0 .. c.len() {
 				rlp.begin_list(4);
 				c[n].endpoint.to_rlp(&mut rlp);
 				rlp.append(&c[n].id);
 			}
+			append_expiration(&mut rlp);
 			rlp.out()
 		});
 		packets.collect()
 	}
 
-	fn on_neighbours(&mut self, rlp: &Rlp, _node: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
-		// TODO: validate packet
-		let mut added = HashMap::new();
-		trace!(target: "discovery", "Got {} Neighbours from {:?}", rlp.at(0)?.item_count()?, &from);
+	fn on_neighbours(&mut self, rlp: &Rlp, node_id: &NodeId, from: &SocketAddr) -> Result<Option<TableUpdates>, Error> {
+		let results_count = rlp.at(0)?.item_count()?;
+
+		let is_expected = match self.in_flight_requests.entry(*node_id) {
+			Entry::Occupied(mut entry) => {
+				let result = {
+					let request = entry.get_mut();
+					if request.packet_id == PACKET_FIND_NODE &&
+						request.response_count + results_count <= BUCKET_SIZE
+					{
+						request.response_count += results_count;
+						true
+					} else {
+						false
+					}
+				};
+				if entry.get().response_count == BUCKET_SIZE {
+					entry.remove();
+				}
+				result
+			}
+			Entry::Vacant(_) => false,
+		};
+
+		if !is_expected {
+			debug!(target: "discovery", "Got unexpected Neighbors from {:?}", &from);
+			return Ok(None);
+		}
+
+		trace!(target: "discovery", "Got {} Neighbours from {:?}", results_count, &from);
 		for r in rlp.at(0)?.iter() {
 			let endpoint = NodeEndpoint::from_rlp(&r)?;
 			if !endpoint.is_valid() {
@@ -481,35 +586,62 @@ impl Discovery {
 				debug!(target: "discovery", "Address not allowed: {:?}", entry);
 				continue;
 			}
-			added.insert(node_id, entry.clone());
-			self.ping(&entry.endpoint);
-			self.update_node(entry);
+			self.add_node(entry);
 		}
-		Ok(Some(TableUpdates { added: added, removed: HashSet::new() }))
+		Ok(None)
 	}
 
-	fn check_expired(&mut self, force: bool) -> HashSet<NodeId> {
-		let now = Instant::now();
+	fn check_expired(&mut self, time: Instant) -> HashSet<NodeId> {
 		let mut removed: HashSet<NodeId> = HashSet::new();
-		for bucket in &mut self.node_buckets {
-			bucket.nodes.retain(|node| {
-				if let Some(timeout) = node.timeout {
-					if !force && now.duration_since(timeout) < PING_TIMEOUT {
-						true
-					}
-					else {
-						trace!(target: "discovery", "Removed expired node {:?}", &node.address);
-						removed.insert(node.address.id.clone());
-						false
-					}
-				} else { true }
-			});
+		while let Some((node_id, sent_at)) = self.expiring_pings.pop_front() {
+			if time.duration_since(sent_at) <= PING_TIMEOUT {
+				self.expiring_pings.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
+		}
+		while let Some((node_id, sent_at)) = self.expiring_finds.pop_front() {
+			if time.duration_since(sent_at) <= FIND_NODE_TIMEOUT {
+				self.expiring_finds.push_front((node_id, sent_at));
+				break;
+			}
+			self.expire_in_flight_request(node_id, sent_at, &mut removed);
 		}
 		removed
 	}
 
+	fn expire_in_flight_request(&mut self, node_id: NodeId, sent_at: Instant, removed: &mut HashSet<NodeId>) {
+		if let Entry::Occupied(entry) = self.in_flight_requests.entry(node_id) {
+			if entry.get().sent_at == sent_at {
+				entry.remove();
+
+				// Attempt to remove from bucket if in one.
+				let id_hash = keccak(&node_id);
+				let dist = Discovery::distance(&self.id_hash, &id_hash)
+					.expect("distance is None only if id hashes are equal; will never send request to self; qed");
+				let bucket = &mut self.node_buckets[dist];
+				if let Some(index) = bucket.nodes.iter().position(|n| n.id_hash == id_hash) {
+					if bucket.nodes[index].fail_count < self.request_backoff.len() {
+						let node = &mut bucket.nodes[index];
+						node.backoff_until = Instant::now() + self.request_backoff[node.fail_count];
+						node.fail_count += 1;
+						trace!(
+							target: "discovery",
+							"Requests to node {:?} timed out {} consecutive time(s)",
+							&node.address, node.fail_count
+						);
+					} else {
+						removed.insert(node_id);
+						let node = bucket.nodes.remove(index).expect("index was located in if condition");
+						debug!(target: "discovery", "Removed expired node {:?}", &node.address);
+					}
+				}
+			}
+		}
+	}
+
 	pub fn round(&mut self) -> Option<TableUpdates> {
-		let removed = self.check_expired(false);
+		let removed = self.check_expired(Instant::now());
 		self.discover();
 		if !removed.is_empty() {
 			Some(TableUpdates { added: HashMap::new(), removed: removed })
@@ -533,10 +665,48 @@ impl Discovery {
 	}
 }
 
+fn append_expiration(rlp: &mut RlpStream) {
+	let expiry = SystemTime::now() + EXPIRY_TIME;
+	let timestamp = expiry.duration_since(UNIX_EPOCH).unwrap_or_default().as_secs() as u32;
+	rlp.append(&timestamp);
+}
+
+fn assemble_packet(packet_id: u8, bytes: &[u8], secret: &Secret) -> Result<Bytes, Error> {
+	let mut packet = Bytes::with_capacity(bytes.len() + 32 + 65 + 1);
+	packet.resize(32 + 65, 0); // Filled in below
+	packet.push(packet_id);
+	packet.extend_from_slice(bytes);
+
+	let hash = keccak(&packet[(32 + 65)..]);
+	let signature = match sign(secret, &hash) {
+		Ok(s) => s,
+		Err(e) => {
+			warn!(target: "discovery", "Error signing UDP packet");
+			return Err(Error::from(e));
+		}
+	};
+	packet[32..(32 + 65)].copy_from_slice(&signature[..]);
+	let signed_hash = keccak(&packet[32..]);
+	packet[0..32].copy_from_slice(&signed_hash);
+	Ok(packet)
+}
+
+// Selects the next node in a bucket to ping. Chooses the eligible node least recently seen.
+fn select_bucket_ping<'a, I>(nodes: I) -> Option<NodeEntry>
+where
+	I: Iterator<Item=&'a BucketEntry>
+{
+	let now = Instant::now();
+	nodes
+		.filter(|n| n.backoff_until < now)
+		.min_by_key(|n| n.last_seen)
+		.map(|n| n.address.clone())
+}
+
 #[cfg(test)]
 mod tests {
 	use super::*;
-	use std::net::{SocketAddr};
+	use std::net::{IpAddr,Ipv4Addr};
 	use node_table::{Node, NodeId, NodeEndpoint};
 
 	use std::str::FromStr;
@@ -560,50 +730,151 @@ mod tests {
 		assert!(packets.last().unwrap().len() > 0);
 	}
 
+	#[test]
+	fn ping_queue() {
+		let key = Random.generate().unwrap();
+		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
+		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		for i in 1..(MAX_NODES_PING+1) {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), i);
+			assert_eq!(discovery.send_queue.len(), i);
+			assert_eq!(discovery.adding_nodes.len(), 0);
+		}
+		for i in 1..20 {
+			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
+			assert_eq!(discovery.in_flight_requests.len(), MAX_NODES_PING);
+			assert_eq!(discovery.send_queue.len(), MAX_NODES_PING);
+			assert_eq!(discovery.adding_nodes.len(), i);
+		}
+	}
+
 	#[test]
 	fn discovery() {
-		let key1 = Random.generate().unwrap();
-		let key2 = Random.generate().unwrap();
-		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40444").unwrap(), udp_port: 40444 };
-		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40445").unwrap(), udp_port: 40445 };
-		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
-		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
+		let mut discovery_handlers = (0..5).map(|i| {
+			let key = Random.generate().unwrap();
+			let ep = NodeEndpoint {
+				address: SocketAddr::new(IpAddr::V4(Ipv4Addr::new(127, 0, 0, 1)), 41000 + i),
+				udp_port: 41000 + i,
+			};
+			Discovery::new(&key, ep, IpFilter::default())
+		})
+			.collect::<Vec<_>>();
 
-		let node1 = Node::from_str("enode://a979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7770").unwrap();
-		let node2 = Node::from_str("enode://b979fb575495b8d6db44f750317d0f4622bf4c2aa3365d6af7c284339968eef29b69ad0dce72a4d8db5ebb4968de0e3bec910127f134779fbcb0cb6d3331163c@127.0.0.1:7771").unwrap();
-		discovery1.add_node(NodeEntry { id: node1.id.clone(), endpoint: node1.endpoint.clone() });
-		discovery1.add_node(NodeEntry { id: node2.id.clone(), endpoint: node2.endpoint.clone() });
+		// Sort inversely by XOR distance to the 0 hash.
+		discovery_handlers.sort_by(|a, b| b.id_hash.cmp(&a.id_hash));
 
-		discovery2.add_node(NodeEntry { id: key1.public().clone(), endpoint: ep1.clone() });
-		discovery2.refresh();
+		// Initialize the routing table of each with the next one in order.
+		for i in 0 .. 5 {
+			let node = NodeEntry {
+				id: discovery_handlers[(i + 1) % 5].id,
+				endpoint: discovery_handlers[(i + 1) % 5].public_endpoint.clone(),
+			};
+			discovery_handlers[i].update_node(node);
+		}
 
-		for _ in 0 .. 10 {
-			while let Some(datagram) = discovery1.dequeue_send() {
-				if datagram.address == ep2.address {
-					discovery2.on_packet(&datagram.payload, ep1.address.clone()).ok();
-				}
-			}
-			while let Some(datagram) = discovery2.dequeue_send() {
-				if datagram.address == ep1.address {
-					discovery1.on_packet(&datagram.payload, ep2.address.clone()).ok();
+		// After 4 discovery rounds, the first one should have learned about the rest.
+		for _round in 0 .. 4 {
+			discovery_handlers[0].round();
+
+			let mut continue_loop = true;
+			while continue_loop {
+				continue_loop = false;
+
+				// Process all queued messages.
+				for i in 0 .. 5 {
+					let src = discovery_handlers[i].public_endpoint.address.clone();
+					while let Some(datagram) = discovery_handlers[i].dequeue_send() {
+						let dest = discovery_handlers.iter_mut()
+							.find(|disc| datagram.address == disc.public_endpoint.address)
+							.unwrap();
+						dest.on_packet(&datagram.payload, src).ok();
+
+						continue_loop = true;
+					}
 				}
 			}
-			discovery2.round();
 		}
-		assert_eq!(discovery2.nearest_node_entries(&NodeId::new()).len(), 3)
+
+		let results = discovery_handlers[0].nearest_node_entries(&NodeId::new());
+		assert_eq!(results.len(), 4);
 	}
 
 	#[test]
 	fn removes_expired() {
 		let key = Random.generate().unwrap();
 		let ep = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40446").unwrap(), udp_port: 40447 };
-		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
-		for _ in 0..1200 {
+		let discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
+
+		let mut discovery = Discovery { request_backoff: &[], ..discovery };
+
+		let total_bucket_nodes = |node_buckets: &Vec<NodeBucket>| -> usize {
+			node_buckets.iter().map(|bucket| bucket.nodes.len()).sum()
+		};
+
+		let node_entries = (0..1200)
+			.map(|_| NodeEntry { id: NodeId::random(), endpoint: ep.clone() })
+			.collect::<Vec<_>>();
+
+		discovery.init_node_list(node_entries.clone());
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200);
+
+		// Requests have not expired yet.
+		let removed = discovery.check_expired(Instant::now()).len();
+		assert_eq!(removed, 0);
+
+		// Expiring pings to bucket nodes removes them from bucket.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert!(removed > 0);
+		assert_eq!(total_bucket_nodes(&discovery.node_buckets), 1200 - removed);
+
+		for _ in 0..100 {
 			discovery.add_node(NodeEntry { id: NodeId::random(), endpoint: ep.clone() });
 		}
-		assert!(discovery.nearest_node_entries(&NodeId::new()).len() <= 16);
-		let removed = discovery.check_expired(true).len();
+		assert!(discovery.in_flight_requests.len() > 0);
+
+		// Expire pings to nodes that are not in buckets.
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 0);
+		assert_eq!(discovery.in_flight_requests.len(), 0);
+
+		let from = SocketAddr::from_str("99.99.99.99:40445").unwrap();
+
+		// FIND_NODE times out because it doesn't receive k results.
+		let key = Random.generate().unwrap();
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..116]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
 		assert!(removed > 0);
+
+		// FIND_NODE does not time out because it receives k results.
+		discovery.send_find_node(&node_entries[100], key.public()).unwrap();
+		for payload in Discovery::prepare_neighbours_packets(&node_entries[101..117]) {
+			let packet = assemble_packet(PACKET_NEIGHBOURS, &payload, &key.secret()).unwrap();
+			discovery.on_packet(&packet, from.clone()).unwrap();
+		}
+
+		let removed = discovery.check_expired(Instant::now() + FIND_NODE_TIMEOUT).len();
+		assert_eq!(removed, 0);
+
+		// Test bucket evictions with retries.
+		let request_backoff = [Duration::new(0, 0); 2];
+		let mut discovery = Discovery { request_backoff: &request_backoff, ..discovery };
+
+		for _ in 0..2 {
+			discovery.ping(&node_entries[101]).unwrap();
+			let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+			assert_eq!(removed, 0);
+		}
+
+		discovery.ping(&node_entries[101]).unwrap();
+		let removed = discovery.check_expired(Instant::now() + PING_TIMEOUT).len();
+		assert_eq!(removed, 1);
 	}
 
 	#[test]
@@ -615,11 +886,8 @@ mod tests {
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
 		for _ in 0..(16 + 10) {
-			discovery.node_buckets[0].nodes.push_back(BucketEntry {
-				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None,
-				id_hash: keccak(NodeId::new()),
-			});
+			let entry = BucketEntry::new(NodeEntry { id: NodeId::new(), endpoint: ep.clone() });
+			discovery.node_buckets[0].nodes.push_back(entry);
 		}
 		let nearest = discovery.nearest_node_entries(&NodeId::new());
 		assert_eq!(nearest.len(), 16)
@@ -674,7 +942,7 @@ mod tests {
 			.unwrap();
 		let mut discovery = Discovery::new(&key, ep.clone(), IpFilter::default());
 
-		node_entries.iter().for_each(|entry| discovery.update_node(entry.clone()));
+		discovery.init_node_list(node_entries.clone());
 
 		let expected_bucket_sizes = vec![
 			0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
@@ -782,17 +1050,70 @@ mod tests {
 	fn test_ping() {
 		let key1 = Random.generate().unwrap();
 		let key2 = Random.generate().unwrap();
+		let key3 = Random.generate().unwrap();
 		let ep1 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40344").unwrap(), udp_port: 40344 };
 		let ep2 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40345").unwrap(), udp_port: 40345 };
+		let ep3 = NodeEndpoint { address: SocketAddr::from_str("127.0.0.1:40346").unwrap(), udp_port: 40345 };
 		let mut discovery1 = Discovery::new(&key1, ep1.clone(), IpFilter::default());
 		let mut discovery2 = Discovery::new(&key2, ep2.clone(), IpFilter::default());
 
-		discovery1.ping(&ep2);
+		discovery1.ping(&NodeEntry { id: discovery2.id, endpoint: ep2.clone() }).unwrap();
 		let ping_data = discovery1.dequeue_send().unwrap();
-		discovery2.on_packet(&ping_data.payload, ep1.address.clone()).ok();
+		assert!(!discovery1.any_sends_queued());
+		let data = &ping_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		if let Some(_) = discovery2.on_packet(&ping_data.payload, ep1.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery2's table");
+		}
 		let pong_data = discovery2.dequeue_send().unwrap();
 		let data = &pong_data.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PONG);
 		let rlp = Rlp::new(&data[1..]);
-		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..])
+		assert_eq!(ping_data.payload[0..32], rlp.val_at::<Vec<u8>>(1).unwrap()[..]);
+
+		// Create a pong packet with incorrect echo hash and assert that it is rejected.
+		let mut incorrect_pong_rlp = RlpStream::new_list(3);
+		ep1.to_rlp_list(&mut incorrect_pong_rlp);
+		incorrect_pong_rlp.append(&H256::default());
+		append_expiration(&mut incorrect_pong_rlp);
+		let incorrect_pong_data = assemble_packet(
+			PACKET_PONG, &incorrect_pong_rlp.drain(), &discovery2.secret
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&incorrect_pong_data, ep2.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table because pong hash is incorrect");
+		}
+
+		// Delivery of valid pong response should add to routing table.
+		if let Some(table_updates) = discovery1.on_packet(&pong_data.payload, ep2.address.clone()).unwrap() {
+			assert_eq!(table_updates.added.len(), 1);
+			assert_eq!(table_updates.removed.len(), 0);
+			assert!(table_updates.added.contains_key(&discovery2.id));
+		} else {
+			panic!("Expected discovery1 to be added to discovery1's table");
+		}
+
+		let ping_back = discovery2.dequeue_send().unwrap();
+		assert!(!discovery2.any_sends_queued());
+		let data = &ping_back.payload[(32 + 65)..];
+		assert_eq!(data[0], PACKET_PING);
+		let rlp = Rlp::new(&data[1..]);
+		assert_eq!(ep2, NodeEndpoint::from_rlp(&rlp.at(1).unwrap()).unwrap());
+		assert_eq!(ep1, NodeEndpoint::from_rlp(&rlp.at(2).unwrap()).unwrap());
+
+		// Deliver an unexpected PONG message to discover1.
+		let mut unexpected_pong_rlp = RlpStream::new_list(3);
+		ep3.to_rlp_list(&mut unexpected_pong_rlp);
+		unexpected_pong_rlp.append(&H256::default());
+		append_expiration(&mut unexpected_pong_rlp);
+		let unexpected_pong = assemble_packet(
+			PACKET_PONG, &unexpected_pong_rlp.drain(), key3.secret()
+		).unwrap();
+		if let Some(_) = discovery1.on_packet(&unexpected_pong, ep3.address.clone()).unwrap() {
+			panic!("Expected no changes to discovery1's table for unexpected pong");
+		}
 	}
 }
diff --git a/util/network-devp2p/src/host.rs b/util/network-devp2p/src/host.rs
index 0fbd64b42..28d6620bc 100644
--- a/util/network-devp2p/src/host.rs
+++ b/util/network-devp2p/src/host.rs
@@ -243,7 +243,7 @@ pub struct Host {
 	udp_socket: Mutex<Option<UdpSocket>>,
 	tcp_listener: Mutex<TcpListener>,
 	sessions: Arc<RwLock<Slab<SharedSession>>>,
-	discovery: Mutex<Option<Discovery>>,
+	discovery: Mutex<Option<Discovery<'static>>>,
 	nodes: RwLock<NodeTable>,
 	handlers: RwLock<HashMap<ProtocolId, Arc<NetworkProtocolHandler + Sync>>>,
 	timers: RwLock<HashMap<TimerToken, ProtocolTimer>>,
diff --git a/util/network-devp2p/src/node_table.rs b/util/network-devp2p/src/node_table.rs
index 087caefe1..2640cec79 100644
--- a/util/network-devp2p/src/node_table.rs
+++ b/util/network-devp2p/src/node_table.rs
@@ -33,7 +33,7 @@ use rand::{self, Rng};
 /// Node public key
 pub type NodeId = H512;
 
-#[derive(Debug, Clone)]
+#[derive(Debug, Clone, PartialEq)]
 /// Node address info
 pub struct NodeEndpoint {
 	/// IP(V4 or V6) address
