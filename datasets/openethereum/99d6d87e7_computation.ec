commit 99d6d87e78eb960fe9bb17052f95ec521b46cd58
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Sat Oct 29 17:38:34 2016 +0200

    Discovery performance optimization (#2972)

diff --git a/util/network/<std macros> b/util/network/<std macros>
new file mode 100644
index 000000000..e69de29bb
diff --git a/util/network/src/discovery.rs b/util/network/src/discovery.rs
index 595ac7605..d9cd7a4d7 100644
--- a/util/network/src/discovery.rs
+++ b/util/network/src/discovery.rs
@@ -57,6 +57,7 @@ pub struct NodeEntry {
 
 pub struct BucketEntry {
 	pub address: NodeEntry,
+	pub id_hash: H256,
 	pub timeout: Option<u64>,
 }
 
@@ -85,6 +86,7 @@ struct Datagramm {
 
 pub struct Discovery {
 	id: NodeId,
+	id_hash: H256,
 	secret: Secret,
 	public_endpoint: NodeEndpoint,
 	udp_socket: UdpSocket,
@@ -109,6 +111,7 @@ impl Discovery {
 		let socket = UdpSocket::bound(&listen).expect("Error binding UDP socket");
 		Discovery {
 			id: key.public().clone(),
+			id_hash: key.public().sha3(),
 			secret: key.secret().clone(),
 			public_endpoint: public,
 			token: token,
@@ -150,8 +153,9 @@ impl Discovery {
 
 	fn update_node(&mut self, e: NodeEntry) {
 		trace!(target: "discovery", "Inserting {:?}", &e);
+		let id_hash = e.id.sha3();
 		let ping = {
-			let mut bucket = self.node_buckets.get_mut(Discovery::distance(&self.id, &e.id) as usize).unwrap();
+			let mut bucket = self.node_buckets.get_mut(Discovery::distance(&self.id_hash, &id_hash) as usize).unwrap();
 			let updated = if let Some(node) = bucket.nodes.iter_mut().find(|n| n.address.id == e.id) {
 				node.address = e.clone();
 				node.timeout = None;
@@ -159,7 +163,7 @@ impl Discovery {
 			} else { false };
 
 			if !updated {
-				bucket.nodes.push_front(BucketEntry { address: e, timeout: None });
+				bucket.nodes.push_front(BucketEntry { address: e, timeout: None, id_hash: id_hash, });
 			}
 
 			if bucket.nodes.len() > BUCKET_SIZE {
@@ -174,7 +178,7 @@ impl Discovery {
 	}
 
 	fn clear_ping(&mut self, id: &NodeId) {
-		let mut bucket = self.node_buckets.get_mut(Discovery::distance(&self.id, id) as usize).unwrap();
+		let mut bucket = self.node_buckets.get_mut(Discovery::distance(&self.id_hash, &id.sha3()) as usize).unwrap();
 		if let Some(node) = bucket.nodes.iter_mut().find(|n| &n.address.id == id) {
 			node.timeout = None;
 		}
@@ -224,8 +228,8 @@ impl Discovery {
 		self.discovery_round += 1;
 	}
 
-	fn distance(a: &NodeId, b: &NodeId) -> u32 {
-		let d = a.sha3() ^ b.sha3();
+	fn distance(a: &H256, b: &H256) -> u32 {
+		let d = *a ^ *b;
 		let mut ret:u32 = 0;
 		for i in 0..32 {
 			let mut v: u8 = d[i];
@@ -279,11 +283,12 @@ impl Discovery {
 	fn nearest_node_entries(target: &NodeId, buckets: &[NodeBucket]) -> Vec<NodeEntry> {
 		let mut found: BTreeMap<u32, Vec<&NodeEntry>> = BTreeMap::new();
 		let mut count = 0;
+		let target_hash = target.sha3();
 
 		// Sort nodes by distance to target
 		for bucket in buckets {
 			for node in &bucket.nodes {
-				let distance = Discovery::distance(target, &node.address.id);
+				let distance = Discovery::distance(&target_hash, &node.id_hash);
 				found.entry(distance).or_insert_with(Vec::new).push(&node.address);
 				if count == BUCKET_SIZE {
 					// delete the most distant element
@@ -626,7 +631,8 @@ mod tests {
 		for _ in 0..(16 + 10) {
 			buckets[0].nodes.push_back(BucketEntry {
 				address: NodeEntry { id: NodeId::new(), endpoint: ep.clone() },
-				timeout: None
+				timeout: None,
+				id_hash: NodeId::new().sha3(),
 			});
 		}
 		let nearest = Discovery::nearest_node_entries(&NodeId::new(), &buckets);
diff --git a/util/network/src/host.rs b/util/network/src/host.rs
index 177a44843..d6e530d6f 100644
--- a/util/network/src/host.rs
+++ b/util/network/src/host.rs
@@ -61,7 +61,7 @@ const SYS_TIMER: usize = LAST_SESSION + 1;
 
 // Timeouts
 const MAINTENANCE_TIMEOUT: u64 = 1000;
-const DISCOVERY_REFRESH_TIMEOUT: u64 = 7200;
+const DISCOVERY_REFRESH_TIMEOUT: u64 = 60_000;
 const DISCOVERY_ROUND_TIMEOUT: u64 = 300;
 const NODE_TABLE_TIMEOUT: u64 = 300_000;
 
