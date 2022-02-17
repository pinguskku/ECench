commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
commit 1611815b8dc7e5168823a0bb5785a65f59579ec9
Author: SjonHortensius <SjonHortensius@users.noreply.github.com>
Date:   Tue Sep 3 10:43:35 2019 +0200

    cmd/utils: reduce light.maxpeers default for clients to 1/10th (#19933)
    
    Currently light.maxpeers is 100 - after this change it's 10 for non-servers.
    
    Fixes #19820

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index d553b662c..773207339 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -1109,6 +1109,11 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	if ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
 		lightPeers = ctx.GlobalInt(LightMaxPeersFlag.Name)
 	}
+	if lightClient && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
+		// dynamic default - for clients we use 1/10th of the default for servers
+		lightPeers /= 10
+	}
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
 		if lightServer && !ctx.GlobalIsSet(LightLegacyPeersFlag.Name) && !ctx.GlobalIsSet(LightMaxPeersFlag.Name) {
