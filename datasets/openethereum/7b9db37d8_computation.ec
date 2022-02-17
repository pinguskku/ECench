commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
commit 7b9db37d84dfe34e209dd5c0489b7ace08b413d7
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Jun 20 16:29:04 2016 +0200

    removed unnecessary logs

diff --git a/parity/configuration.rs b/parity/configuration.rs
index 7c42f06e1..a20d6cdd2 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -270,9 +270,8 @@ impl Configuration {
 
 			let from = GethDirectory::open(dir_type);
 			let to = DiskDirectory::create(self.keys_path()).unwrap();
-			if let Err(e) = import_accounts(&from, &to) {
-				warn!("Could not import accounts {}", e);
-			}
+			// ignore error, cause geth may not exist
+			let _ = import_accounts(&from, &to);
 		}
 
 		let dir = Box::new(DiskDirectory::create(self.keys_path()).unwrap());
diff --git a/parity/migration.rs b/parity/migration.rs
index acfd32ffd..e2a25723f 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -151,8 +151,6 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 		return Ok(())
 	}
 
-	println!("Migrating database {} from version {} to {}", path.to_string_lossy(), version, CURRENT_VERSION);
-
 	let temp_path = temp_database_path(&path);
 	let backup_path = backup_database_path(&path);
 	// remote the dir if it exists
@@ -187,20 +185,26 @@ fn migrate_database(version: u32, path: PathBuf, migrations: MigrationManager) -
 
 	// remove backup
 	try!(fs::remove_dir_all(&backup_path));
-	println!("Migration finished");
 
 	Ok(())
 }
 
+fn exists(path: &PathBuf) -> bool {
+	fs::metadata(path).is_ok()
+}
+
 /// Migrates the database.
 pub fn migrate(path: &PathBuf) -> Result<(), Error> {
 	// read version file.
 	let version = try!(current_version(path));
 
 	// migrate the databases.
-	if version != CURRENT_VERSION {
+	// main db directory may already exists, so let's check if we have blocks dir
+	if version != CURRENT_VERSION && exists(&blocks_database_path(path)) {
+		println!("Migrating database from version {} to {}", version, CURRENT_VERSION);
 		try!(migrate_database(version, blocks_database_path(path), try!(blocks_database_migrations())));
 		try!(migrate_database(version, extras_database_path(path), try!(extras_database_migrations())));
+		println!("Migration finished");
 	}
 
 	// update version file.
