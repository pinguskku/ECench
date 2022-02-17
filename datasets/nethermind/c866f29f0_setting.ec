commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
commit c866f29f0545481c11c072097443567a428f1240
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Apr 27 03:25:47 2020 +0100

    improved NLog based on the snakefoot's feedback (#1775)

diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index 2e0ed53ca..a1444bfaf 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -5,103 +5,71 @@
       xsi:schemaLocation="http://www.nlog-project.org/schemas/NLog.xsd NLog.xsd"
       autoReload="true" throwExceptions="false">
 
-  <extensions>
-    <add assembly="NLog.Targets.Seq"/>
-  </extensions>
+    <extensions>
+        <add assembly="NLog.Targets.Seq" />
+    </extensions>
 
-  <targets async="true">
-    <target xsi:type="AsyncWrapper"
-            name="file-async"
-            queueLimit="10000"
-            timeToSleepBetweenBatches="0"
-            batchSize="200"
-            overflowAction="Discard">
-      <target name="file" xsi:type="File"
-              keepFileOpen="true"
-              concurrentWrites="false"
-              fileName="log.txt"
-              archiveAboveSize="32000000"
-              maxArchiveFiles="10"
-              layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
-              <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
-    </target>
+    <targets async="true">
+        <target name="file-async" xsi:type="File"
+                keepFileOpen="true"
+                concurrentWrites="false"
+                fileName="log.txt"
+                archiveAboveSize="32000000"
+                maxArchiveFiles="10"
+                layout="${longdate}|${level:uppercase=true}|${threadid}|${message} ${exception:format=toString}" />
+        <!--layout="${longdate}|${level:uppercase=true}|${threadid}|${logger}|${message} ${exception:format=toString}" />-->
 
-    <target xsi:type="AutoFlushWrapper" name="auto-colored-console-async">
-      <target xsi:type="AsyncWrapper"
-              name="colored-console-async"
-              queueLimit="10000"
-              timeToSleepBetweenBatches="0"
-              batchSize="200"
-              overflowAction="Discard">
-      
         <target xsi:type="ColoredConsole"
-                name="colored-console"
+                autoFlush="true"
+                name="auto-colored-console-async"
                 useDefaultRowHighlightingRules="False"
                 layout="${longdate}|${message} ${exception:format=toString}">
-                <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
-          <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
+            <!-- layout="${longdate}|${threadid}|${message} ${exception:format=toString}"> -->
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Fatal" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Error" foregroundColor="Red" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Warn" foregroundColor="Yellow" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Info" foregroundColor="Cyan" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Debug" foregroundColor="Gray" />
+            <highlight-row backgroundColor="NoChange" condition="level == LogLevel.Trace" foregroundColor="DarkGray" />
         </target>
-      </target>
-    </target>
-    <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
-      <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
-        <property name="ThreadId" value="${threadid}" as="number" />
-        <property name="MachineName" value="${machinename}" />
-        <property name="Logger" value="${logger}" />
-        <property name="Exception" value="${exception}" />
-        <property name="Enode" value="${gdc:item=enode}" />
-        <property name="Chain" value="${gdc:item=chain}" />
-        <property name="ChainID" value="${gdc:item=chainId}" />
-        <property name="Engine" value="${gdc:item=engine}" />
-        <property name="NodeName" value="${gdc:item=nodeName}" />
-      </target>
-    </target>
-  </targets>
-
-  <rules>
-    <!--<logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Blockchain.BlockchainProcessor" minlevel="Debug" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="Blockchain.BlockchainProcessor" final="true"/>-->
+        <target xsi:type="BufferingWrapper" name="seq" bufferSize="1000" flushTimeout="2000">
+            <target xsi:type="Seq" serverUrl="http://localhost:5341" apiKey="">
+                <property name="ThreadId" value="${threadid}" as="number" />
+                <property name="MachineName" value="${machinename}" />
+                <property name="Logger" value="${logger}" />
+                <property name="Exception" value="${exception}" />
+                <property name="Enode" value="${gdc:item=enode}" />
+                <property name="Chain" value="${gdc:item=chain}" />
+                <property name="ChainID" value="${gdc:item=chainId}" />
+                <property name="Engine" value="${gdc:item=engine}" />
+                <property name="NodeName" value="${gdc:item=nodeName}" />
+            </target>
+        </target>
+    </targets>
 
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async"/>
-    <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true"/>
-    <logger name="JsonWebAPI*" final="true"/>
+    <rules>
+        <!-- JsonWebAPI is an internal Kestrel logger for Json, not related to Ethereum JSON RPC -->
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="file-async" />
+        <logger name="JsonWebAPI*" minlevel="Error" writeTo="auto-colored-console-async" final="true" />
+        <logger name="JsonWebAPI*" final="true" />
 
-    <!--<logger name="Network.PeerManager" minlevel="Debug" writeTo="file-async"/>
-    <logger name="Network.PeerManager" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network.PeerManager" final="true"/>-->
+        <!-- you can control JSON RPC logging level here -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="file-async"/> -->
+        <!-- <logger name="JsonRpc.*" minlevel="Error" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="JsonRpc.*" final="true"/> -->
 
-    <!--<logger name="Network*" minlevel="Trace" writeTo="file-async"/>
-    <logger name="Network*" minlevel="Debug" writeTo="auto-colored-console-async"/>
-    <logger name="Network*" final="true"/>-->
-    
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.NodeDataDownloader" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.Synchronization.Synchronizer" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- ~1~ <logger name="Blockchain.Synchronization.Synchronizer" final="true"/> @1@ -->
-    <!-- -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Network.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.*" final="true"/> -->
-    <!-- -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="file-async"/> -->
-    <!-- <logger name="Blockchain.*" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Blockchain.*" final="true"/> -->
+        <!-- big chance that you do not like the peers report - you can disable it here -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" minlevel="Warn" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.Peers.*" final="true"/> -->
 
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="file-async"/> -->
-    <!-- <logger name="Network.Discovery.*" minlevel="Debug" writeTo="auto-colored-console-async"/> -->
-    <!-- <logger name="Network.Discovery.*" final="true"/> -->
+        <!-- if sync get stuck this is the best thing to enable the Trace on -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="file-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" minlevel="Trace" writeTo="auto-colored-console-async"/> -->
+        <!-- <logger name="Synchronization.ParallelSync.MultiSyncModeSelector" final="true"/> -->
 
-    <logger name="*" minlevel="Off" writeTo="seq" />
-    <logger name="*" minlevel="Info" writeTo="file-async"/>
-    <logger name="*" minlevel="Info" writeTo="auto-colored-console-async"/>
-  </rules>
+        <logger name="*" minlevel="Off" writeTo="seq" />
+        <logger name="*" minlevel="Info" writeTo="file-async" />
+        <logger name="*" minlevel="Info" writeTo="auto-colored-console-async" />
+    </rules>
 </nlog>
\ No newline at end of file
