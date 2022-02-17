commit 7052fda3be6a2d37bba6c4e8469c40460701a929
Author: Adrian Sutton <adrian.sutton@consensys.net>
Date:   Thu Nov 21 16:28:31 2019 +1000

    Shutdown vertx instance created within BesuCommand so BesuCommandTest doesn't leak file descriptors. (#209)
    
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/besu/src/main/java/org/hyperledger/besu/cli/BesuCommand.java b/besu/src/main/java/org/hyperledger/besu/cli/BesuCommand.java
index 271736e3c..3007ba52f 100644
--- a/besu/src/main/java/org/hyperledger/besu/cli/BesuCommand.java
+++ b/besu/src/main/java/org/hyperledger/besu/cli/BesuCommand.java
@@ -1453,7 +1453,7 @@ public class BesuCommand implements DefaultCommandValues, Runnable {
     final ObservableMetricsSystem metricsSystem = this.metricsSystem.get();
     final Runner runner =
         runnerBuilder
-            .vertx(Vertx.vertx(createVertxOptions(metricsSystem)))
+            .vertx(createVertx(createVertxOptions(metricsSystem)))
             .besuController(controller)
             .p2pEnabled(p2pEnabled)
             .natMethod(natMethod)
@@ -1483,6 +1483,10 @@ public class BesuCommand implements DefaultCommandValues, Runnable {
     runner.awaitStop();
   }
 
+  protected Vertx createVertx(final VertxOptions vertxOptions) {
+    return Vertx.vertx(vertxOptions);
+  }
+
   private VertxOptions createVertxOptions(final MetricsSystem metricsSystem) {
     return new VertxOptions()
         .setMetricsOptions(
diff --git a/besu/src/test/java/org/hyperledger/besu/cli/CommandTestAbstract.java b/besu/src/test/java/org/hyperledger/besu/cli/CommandTestAbstract.java
index 627071e4a..a2091d4de 100644
--- a/besu/src/test/java/org/hyperledger/besu/cli/CommandTestAbstract.java
+++ b/besu/src/test/java/org/hyperledger/besu/cli/CommandTestAbstract.java
@@ -67,13 +67,20 @@ import java.io.IOException;
 import java.io.InputStream;
 import java.io.PrintStream;
 import java.nio.file.Path;
+import java.util.ArrayList;
 import java.util.Collection;
 import java.util.HashMap;
+import java.util.List;
 import java.util.Map;
 import java.util.Optional;
+import java.util.concurrent.TimeUnit;
+import java.util.concurrent.atomic.AtomicBoolean;
 
+import io.vertx.core.Vertx;
+import io.vertx.core.VertxOptions;
 import org.apache.logging.log4j.LogManager;
 import org.apache.logging.log4j.Logger;
+import org.awaitility.Awaitility;
 import org.junit.After;
 import org.junit.Before;
 import org.junit.Rule;
@@ -100,6 +107,8 @@ public abstract class CommandTestAbstract {
   private final PrintStream errPrintStream = new PrintStream(commandErrorOutput);
   private final HashMap<String, String> environment = new HashMap<>();
 
+  private final List<TestBesuCommand> besuCommands = new ArrayList<>();
+
   @Mock protected RunnerBuilder mockRunnerBuilder;
   @Mock protected Runner mockRunner;
 
@@ -229,6 +238,7 @@ public abstract class CommandTestAbstract {
 
     errPrintStream.close();
     commandErrorOutput.close();
+    besuCommands.forEach(TestBesuCommand::close);
   }
 
   protected void setEnvironemntVariable(final String name, final String value) {
@@ -270,6 +280,7 @@ public abstract class CommandTestAbstract {
             mockBesuPluginContext,
             environment,
             storageService);
+    besuCommands.add(besuCommand);
 
     besuCommand.setBesuConfiguration(commonPluginConfiguration);
 
@@ -287,6 +298,7 @@ public abstract class CommandTestAbstract {
 
     @CommandLine.Spec CommandLine.Model.CommandSpec spec;
     private final PublicKeySubCommand.KeyLoader keyLoader;
+    private Vertx vertx;
 
     @Override
     protected PublicKeySubCommand.KeyLoader getKeyLoader() {
@@ -322,6 +334,12 @@ public abstract class CommandTestAbstract {
       // For testing, don't actually query for networking interfaces to validate this option
     }
 
+    @Override
+    protected Vertx createVertx(final VertxOptions vertxOptions) {
+      vertx = super.createVertx(vertxOptions);
+      return vertx;
+    }
+
     public CommandSpec getSpec() {
       return spec;
     }
@@ -349,5 +367,13 @@ public abstract class CommandTestAbstract {
     public MetricsCLIOptions getMetricsCLIOptions() {
       return metricsCLIOptions;
     }
+
+    public void close() {
+      if (vertx != null) {
+        final AtomicBoolean closed = new AtomicBoolean(false);
+        vertx.close(event -> closed.set(true));
+        Awaitility.waitAtMost(30, TimeUnit.SECONDS).until(closed::get);
+      }
+    }
   }
 }