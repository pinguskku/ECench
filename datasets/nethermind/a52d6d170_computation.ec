commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
commit a52d6d17096689838545b1173bccfe51b6e5ed3b
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Apr 30 01:21:20 2018 +0100

    jump destinations performance improvement

diff --git a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
index 0ca07f3c2..f9ebc6e7f 100644
--- a/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nethermind/Ethereum.VM.Test/VMTestBase.cs
@@ -157,7 +157,7 @@ namespace Ethereum.VM.Test
 
             environment.GasPrice = test.Execution.GasPrice;
             environment.InputData = test.Execution.Data;
-            environment.MachineCode = test.Execution.Code;
+            environment.CodeInfo = new CodeInfo(test.Execution.Code);
             environment.Originator = test.Execution.Origin;
 
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
index 9eea03e0d..f56e16dec 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryManagerTests.cs
@@ -54,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             var privateKey = new PrivateKey(new Hex(TestPrivateKeyHex));
             _publicKey = privateKey.PublicKey;
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             var config = new DiscoveryConfigurationProvider(new NetworkHelper(logger)) { PongTimeout = 100 };
             var configProvider = new ConfigurationProvider();
             
diff --git a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
index 6f31f81b6..a66c69d36 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/DiscoveryMessageSerializerTests.cs
@@ -42,7 +42,7 @@ namespace Nethermind.Discovery.Test
         [SetUp]
         public void Initialize()
         {
-            _config = new DiscoveryConfigurationProvider(new NetworkHelper(new ConsoleAsyncLogger()));
+            _config = new DiscoveryConfigurationProvider(new NetworkHelper(NullLogger.Instance));
             _farAddress = new IPEndPoint(IPAddress.Parse("192.168.1.2"), 1);
             _nearAddress = new IPEndPoint(IPAddress.Parse(_config.MasterExternalIp), _config.MasterPort);            
             _messageSerializationService = Build.A.SerializationService().WithDiscovery(_privateKey).TestObject;
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
index bb48b7f31..f9b6d6b7b 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NetworkHelperTests.cs
@@ -10,7 +10,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void ExternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetExternalIp();
             Assert.IsNotNull(address);
         }
@@ -18,7 +18,7 @@ namespace Nethermind.Discovery.Test
         [Test]
         public void InternalIpTest()
         {
-            var networkHelper = new NetworkHelper(new ConsoleAsyncLogger());
+            var networkHelper = new NetworkHelper(NullLogger.Instance);
             var address = networkHelper.GetLocalIp();
             Assert.IsNotNull(address);
         }
diff --git a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
index 9e9623070..b31adac2e 100644
--- a/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Discovery.Test/NodeLifecycleManagerTests.cs
@@ -17,10 +17,8 @@
  */
 
 using System.Collections.Generic;
-using System.IO;
 using System.Linq;
 using System.Net;
-using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Discovery.Lifecycle;
@@ -56,7 +54,7 @@ namespace Nethermind.Discovery.Test
         {
             SetupNodeIds();
 
-            var logger = new ConsoleAsyncLogger();
+            var logger = NullLogger.Instance;
             //setting config to store 3 nodes in a bucket and for table to have one bucket//setting config to store 3 nodes in a bucket and for table to have one bucket
             _configurationProvider = new DiscoveryConfigurationProvider(new NetworkHelper(logger))
             {
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
new file mode 100644
index 000000000..b11f2b430
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeInfo.cs
@@ -0,0 +1,45 @@
+﻿/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+
+using System.Numerics;
+using Nethermind.Core;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Evm
+{
+    // TODO: it was some work planned for optimization but then another solutions was used, will consider later to refactor EvmState and this class as well
+    public class CodeInfo
+    {
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+        
+        public CodeInfo(Address precompileAddress)
+        {
+            PrecompileAddress = precompileAddress;
+            PrecompileId = PrecompileAddress.Hex.ToUnsignedBigInteger();
+        }
+
+        public bool IsPrecompile => PrecompileAddress != null;
+        public byte[] MachineCode { get; set; }
+        public Address PrecompileAddress { get; set; }
+        public BigInteger PrecompileId { get; set; }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 7d7b7a84c..f755369a5 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -37,7 +37,7 @@ namespace Nethermind.Evm
 
         public BigInteger Value { get; set; }
 
-        public byte[] MachineCode { get; set; }
+        public CodeInfo CodeInfo { get; set; }
 
         public BlockHeader CurrentBlock { get; set; }
 
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
index e5810f3c4..ab7f9cbcd 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessor.cs
@@ -207,7 +207,7 @@ namespace Nethermind.Evm
                     env.CurrentBlock = block;
                     env.GasPrice = gasPrice;
                     env.InputData = data ?? new byte[0];
-                    env.MachineCode = isPrecompile ? (byte[])recipient.Hex : machineCode ?? _stateProvider.GetCode(recipient);
+                    env.CodeInfo = isPrecompile ? new CodeInfo(recipient) : new CodeInfo(machineCode ?? _stateProvider.GetCode(recipient));
                     env.Originator = sender;
 
                     ExecutionType executionType = isPrecompile
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 74bc48b46..b9d965d97 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -267,7 +267,7 @@ namespace Nethermind.Evm
             BigInteger transferValue = state.Env.TransferValue;
             long gasAvailable = state.GasAvailable;
 
-            BigInteger precompileId = state.Env.MachineCode.ToUnsignedBigInteger();
+            BigInteger precompileId = state.Env.CodeInfo.PrecompileId;
             long baseGasCost = _precompiles[precompileId].BaseGasCost();
             long dataGasCost = _precompiles[precompileId].DataGasCost(callData);
 
@@ -360,7 +360,7 @@ namespace Nethermind.Evm
                 stackHead = evmState.StackHead;
                 gasAvailable = evmState.GasAvailable;
                 programCounter = (long)evmState.ProgramCounter;
-                code = env.MachineCode;
+                code = env.CodeInfo.MachineCode;
             }
 
             void UpdateCurrentState()
@@ -617,7 +617,7 @@ namespace Nethermind.Evm
                     throw new InvalidJumpDestinationException();
                 }
             }
-
+            
             void CalculateJumpDestinations()
             {
                 jumpDestinations = new bool[code.Length];
@@ -1225,7 +1225,8 @@ namespace Nethermind.Evm
                             }
 
                             int dest = (int)bigReg;
-                            ValidateJump(dest);
+                            if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
+
                             programCounter = dest;
                             break;
                         }
@@ -1242,7 +1243,7 @@ namespace Nethermind.Evm
                             BigInteger condition = PopUInt();
                             if (condition > BigInteger.Zero)
                             {
-                                ValidateJump(dest);
+                                if (spec.AreJumpDestinationsUsed) ValidateJump(dest);
                                 programCounter = dest;
                             }
 
@@ -1491,7 +1492,7 @@ namespace Nethermind.Evm
                             callEnv.CurrentBlock = env.CurrentBlock;
                             callEnv.GasPrice = env.GasPrice;
                             callEnv.ExecutingAccount = contractAddress;
-                            callEnv.MachineCode = initCode;
+                            callEnv.CodeInfo = new CodeInfo(initCode);
                             callEnv.InputData = Bytes.Empty;
                             EvmState callState = new EvmState(
                                 callGas,
@@ -1666,7 +1667,7 @@ namespace Nethermind.Evm
                             callEnv.TransferValue = transferValue;
                             callEnv.Value = callValue;
                             callEnv.InputData = callData;
-                            callEnv.MachineCode = isPrecompile ? ((byte[])codeSource.Hex) : _state.GetCode(codeSource);
+                            callEnv.CodeInfo = isPrecompile ? new CodeInfo(codeSource) : new CodeInfo(_state.GetCode(codeSource));
 
                             BigInteger callGas = transferValue.IsZero ? gasLimitUl : gasLimitUl + GasCostOf.CallStipend;
                             if (_logger.IsDebugEnabled)
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6771bba45..fcfc57e64 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -129,7 +129,7 @@ namespace Nethermind.PerfTest
             foreach (KeyValuePair<string, (string Code, string Input, int Iterations)> testCase in TestCases)
             {
                 ExecutionEnvironment env = new ExecutionEnvironment();
-                env.MachineCode = Hex.ToBytes(testCase.Value.Code);
+                env.CodeInfo = new CodeInfo(Hex.ToBytes(testCase.Value.Code));
                 env.InputData = Hex.ToBytes(testCase.Value.Input);
                 env.ExecutingAccount = new Address(Keccak.Zero);
 
diff --git a/src/Nethermind/Nethermind.Store/InMemoryDb.cs b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
index 0fd24cead..c3e113190 100644
--- a/src/Nethermind/Nethermind.Store/InMemoryDb.cs
+++ b/src/Nethermind/Nethermind.Store/InMemoryDb.cs
@@ -196,6 +196,11 @@ namespace Nethermind.Store
             {
                 return;
             }
+
+            if (_changes.Length <= _currentPosition + 1)
+            {
+                throw new InvalidOperationException($"{nameof(_currentPosition)} ({_currentPosition}) is outside of the range of {_changes} array (length {_changes.Length})");
+            }
             
             if (_changes[_currentPosition] == null)
             {
