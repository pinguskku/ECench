commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
commit c8b65c769b50545d73a307cbd9eace7ba2faf1d1
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Mon Mar 14 13:54:06 2016 +0100

    Fixed handshake leak

diff --git a/util/src/network/host.rs b/util/src/network/host.rs
index 57aae51d7..02c576424 100644
--- a/util/src/network/host.rs
+++ b/util/src/network/host.rs
@@ -687,6 +687,8 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		if h.expired {
 			return;
 		}
+		io.deregister_stream(token).expect("Error deleting handshake registration");
+		h.set_expired();
 		let originated = h.originated;
 		let mut session = match Session::new(&mut h, &self.info.read().unwrap()) {
 			Ok(s) => s,
@@ -705,8 +707,6 @@ impl<Message> Host<Message> where Message: Send + Sync + Clone {
 		}
 		let result = sessions.insert_with(move |session_token| {
 			session.set_token(session_token);
-			io.deregister_stream(token).expect("Error deleting handshake registration");
-			h.set_expired();
 			io.register_stream(session_token).expect("Error creating session registration");
 			self.stats.inc_sessions();
 			trace!(target: "network", "Creating session {} -> {}", token, session_token);
