commit e32b600530d99722ffdb720174dabc031703ac18
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Tue Feb 27 18:29:43 2018 +0100

    improve quality of vote_collector module (#7984)

diff --git a/ethcore/src/engines/tendermint/mod.rs b/ethcore/src/engines/tendermint/mod.rs
index d09396fb0..dfac00bea 100644
--- a/ethcore/src/engines/tendermint/mod.rs
+++ b/ethcore/src/engines/tendermint/mod.rs
@@ -223,7 +223,7 @@ impl Tendermint {
 			(Some(validator), Ok(signature)) => {
 				let message_rlp = message_full_rlp(&signature, &vote_info);
 				let message = ConsensusMessage::new(signature, h, r, s, block_hash);
-				self.votes.vote(message.clone(), &validator);
+				self.votes.vote(message.clone(), validator);
 				debug!(target: "engine", "Generated {:?} as {}.", message, validator);
 				self.handle_valid_message(&message);
 
@@ -493,7 +493,7 @@ impl Engine<EthereumMachine> for Tendermint {
 		if let Ok(signature) = self.sign(keccak(&vote_info)).map(Into::into) {
 			// Insert Propose vote.
 			debug!(target: "engine", "Submitting proposal {} at height {} view {}.", header.bare_hash(), height, view);
-			self.votes.vote(ConsensusMessage::new(signature, height, view, Step::Propose, bh), author);
+			self.votes.vote(ConsensusMessage::new(signature, height, view, Step::Propose, bh), *author);
 			// Remember the owned block.
 			*self.last_proposed.write() = header.bare_hash();
 			// Remember proposal for later seal submission.
@@ -527,7 +527,7 @@ impl Engine<EthereumMachine> for Tendermint {
 				return Err(EngineError::NotAuthorized(sender));
 			}
 			self.broadcast_message(rlp.as_raw().to_vec());
-			if let Some(double) = self.votes.vote(message.clone(), &sender) {
+			if let Some(double) = self.votes.vote(message.clone(), sender) {
 				let height = message.vote_step.height as BlockNumber;
 				self.validators.report_malicious(&sender, height, height, ::rlp::encode(&double).into_vec());
 				return Err(EngineError::DoubleVote(sender));
@@ -719,7 +719,7 @@ impl Engine<EthereumMachine> for Tendermint {
 			*self.proposal.write() = proposal.block_hash.clone();
 			*self.proposal_parent.write() = header.parent_hash().clone();
 		}
-		self.votes.vote(proposal, &proposer);
+		self.votes.vote(proposal, proposer);
 		true
 	}
 
diff --git a/ethcore/src/engines/vote_collector.rs b/ethcore/src/engines/vote_collector.rs
index 6a4fee3d5..7af66b30c 100644
--- a/ethcore/src/engines/vote_collector.rs
+++ b/ethcore/src/engines/vote_collector.rs
@@ -45,18 +45,18 @@ pub struct VoteCollector<M: Message> {
 #[derive(Debug, Default)]
 struct StepCollector<M: Message> {
 	voted: HashMap<Address, M>,
-	pub block_votes: HashMap<Option<H256>, HashMap<H520, Address>>,
+	block_votes: HashMap<Option<H256>, HashMap<H520, Address>>,
 	messages: HashSet<M>,
 }
 
 #[derive(Debug)]
-pub struct DoubleVote<'a, M: Message> {
-	pub author: &'a Address,
+pub struct DoubleVote<M: Message> {
+	author: Address,
 	vote_one: M,
 	vote_two: M,
 }
 
-impl<'a, M: Message> Encodable for DoubleVote<'a, M> {
+impl<M: Message> Encodable for DoubleVote<M> {
 	fn rlp_append(&self, s: &mut RlpStream) {
 		s.begin_list(2)
 			.append(&self.vote_one)
@@ -66,10 +66,10 @@ impl<'a, M: Message> Encodable for DoubleVote<'a, M> {
 
 impl <M: Message> StepCollector<M> {
 	/// Returns Some(&Address) when validator is double voting.
-	fn insert<'a>(&mut self, message: M, address: &'a Address) -> Option<DoubleVote<'a, M>> {
+	fn insert(&mut self, message: M, address: Address) -> Option<DoubleVote<M>> {
 		// Do nothing when message was seen.
 		if self.messages.insert(message.clone()) {
-			if let Some(previous) = self.voted.insert(address.clone(), message.clone()) {
+			if let Some(previous) = self.voted.insert(address, message.clone()) {
 				// Bad validator sent a different message.
 				return Some(DoubleVote {
 					author: address,
@@ -81,7 +81,7 @@ impl <M: Message> StepCollector<M> {
 					.block_votes
 					.entry(message.block_hash())
 					.or_insert_with(HashMap::new)
-					.insert(message.signature(), address.clone());
+					.insert(message.signature(), address);
 			}
 		}
 		None
@@ -124,7 +124,7 @@ impl <M: Message + Default> Default for VoteCollector<M> {
 
 impl <M: Message + Default + Encodable + Debug> VoteCollector<M> {
 	/// Insert vote if it is newer than the oldest one.
-	pub fn vote<'a>(&self, message: M, voter: &'a Address) -> Option<DoubleVote<'a, M>> {
+	pub fn vote(&self, message: M, voter: Address) -> Option<DoubleVote<M>> {
 		self
 			.votes
 			.write()
@@ -198,12 +198,6 @@ impl <M: Message + Default + Encodable + Debug> VoteCollector<M> {
 		let guard = self.votes.read();
 		guard.get(&message.round()).and_then(|c| c.block_votes.get(&message.block_hash())).and_then(|origins| origins.get(&message.signature()).cloned())
 	}
-
-	/// Count the number of total rounds kept track of.
-	#[cfg(test)]
-	pub fn len(&self) -> usize {
-		self.votes.read().len()
-	}
 }
 
 #[cfg(test)]
@@ -244,10 +238,10 @@ mod tests {
 	}
 
 	fn random_vote(collector: &VoteCollector<TestMessage>, signature: H520, step: TestStep, block_hash: Option<H256>) -> bool {
-		full_vote(collector, signature, step, block_hash, &H160::random())
+		full_vote(collector, signature, step, block_hash, H160::random())
 	}
 
-	fn full_vote<'a>(collector: &VoteCollector<TestMessage>, signature: H520, step: TestStep, block_hash: Option<H256>, address: &'a Address) -> bool {
+	fn full_vote(collector: &VoteCollector<TestMessage>, signature: H520, step: TestStep, block_hash: Option<H256>, address: Address) -> bool {
 		collector.vote(TestMessage { signature: signature, step: step, block_hash: block_hash }, address).is_none()
 	}
 
@@ -335,7 +329,11 @@ mod tests {
 		vote(1, Some(keccak("1")));
 
 		collector.throw_out_old(&7);
-		assert_eq!(collector.len(), 2);
+		assert_eq!(collector.count_round_votes(&1), 0);
+		assert_eq!(collector.count_round_votes(&3), 0);
+		assert_eq!(collector.count_round_votes(&6), 0);
+		assert_eq!(collector.count_round_votes(&7), 1);
+		assert_eq!(collector.count_round_votes(&8), 1);
 	}
 
 	#[test]
@@ -343,9 +341,9 @@ mod tests {
 		let collector = VoteCollector::default();
 		let round = 3;
 		// Vote is inserted fine.
-		assert!(full_vote(&collector, H520::random(), round, Some(keccak("0")), &Address::default()));
+		assert!(full_vote(&collector, H520::random(), round, Some(keccak("0")), Address::default()));
 		// Returns the double voting address.
-		assert!(!full_vote(&collector, H520::random(), round, Some(keccak("1")), &Address::default()));
+		assert!(!full_vote(&collector, H520::random(), round, Some(keccak("1")), Address::default()));
 		assert_eq!(collector.count_round_votes(&round), 1);
 	}
 }
