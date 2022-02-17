commit 54f6b77462137e8ac8e0fb60eb78282a798d9b29
Author: Szymon Kulec <scooletz@gmail.com>
Date:   Mon Nov 9 11:45:57 2020 +0100

    JsonRPC performance improvements (#2435)
    
    * one ToArray gone
    
    * BoundedModulePool uses a cheaper concurrent structure
    
    * BoundedModulePool is async-ready
    
    * RpcModuleProvider uses TryGetValue instead of Contains and a lookup

diff --git a/src/Nethermind/Nethermind.JsonRpc.Test/Modules/BoundedModulePoolTests.cs b/src/Nethermind/Nethermind.JsonRpc.Test/Modules/BoundedModulePoolTests.cs
index 2e16480e8..323b90bfb 100644
--- a/src/Nethermind/Nethermind.JsonRpc.Test/Modules/BoundedModulePoolTests.cs
+++ b/src/Nethermind/Nethermind.JsonRpc.Test/Modules/BoundedModulePoolTests.cs
@@ -76,95 +76,90 @@ namespace Nethermind.JsonRpc.Test.Modules
         }
 
         [Test]
-        public void Ensure_concurrency()
+        public async Task Ensure_concurrency()
         {
-            _modulePool.GetModule(false);
+            await _modulePool.GetModule(false);
         }
 
         [Test]
-        public void Ensure_limited_exclusive()
+        public async Task Ensure_limited_exclusive()
         {
-            _modulePool.GetModule(false);
-            Assert.Throws<TimeoutException>(() => _modulePool.GetModule(false));
+            await _modulePool.GetModule(false);
+            Assert.ThrowsAsync<TimeoutException>(() => _modulePool.GetModule(false));
         }
         
         [Test]
-        public void Ensure_returning_shared_does_not_change_concurrency()
+        public async Task Ensure_returning_shared_does_not_change_concurrency()
         {
-            IEthModule shared = _modulePool.GetModule(true);
+            IEthModule shared = await _modulePool.GetModule(true);
             _modulePool.ReturnModule(shared);
-            _modulePool.GetModule(false);
-            Assert.Throws<TimeoutException>(() => _modulePool.GetModule(false));
+            await _modulePool.GetModule(false);
+            Assert.ThrowsAsync<TimeoutException>(() => _modulePool.GetModule(false));
         }
 
         [Test]
-        public void Ensure_unlimited_shared()
+        public async Task Ensure_unlimited_shared()
         {
             for (int i = 0; i < 1000; i++)
             {
-                _modulePool.GetModule(true);
+                await _modulePool.GetModule(true);
             }
         }
 
         [Test]
         public async Task Ensure_that_shared_is_never_returned_as_exclusive()
         {
-            IEthModule sharedModule = _modulePool.GetModule(true);
+            IEthModule sharedModule = await _modulePool.GetModule(true);
             _modulePool.ReturnModule(sharedModule);
 
             const int iterations = 1000;
-            Action rentReturnShared = () =>
+            Func<Task> rentReturnShared = async () =>
             {
                 for (int i = 0; i < iterations; i++)
                 {
                     TestContext.Out.WriteLine($"Rent shared {i}");
-                    IEthModule ethModule = _modulePool.GetModule(true);
+                    IEthModule ethModule = await _modulePool.GetModule(true);
                     Assert.AreSame(sharedModule, ethModule);
                     _modulePool.ReturnModule(ethModule);
                     TestContext.Out.WriteLine($"Return shared {i}");
                 }
             };
 
-            Action rentReturnExclusive = () =>
+            Func<Task> rentReturnExclusive = async () =>
             {
                 for (int i = 0; i < iterations; i++)
                 {
                     TestContext.Out.WriteLine($"Rent exclusive {i}");
-                    IEthModule ethModule = _modulePool.GetModule(false);
+                    IEthModule ethModule = await _modulePool.GetModule(false);
                     Assert.AreNotSame(sharedModule, ethModule);
                     _modulePool.ReturnModule(ethModule);
                     TestContext.Out.WriteLine($"Return exclusive {i}");
                 }
             };
 
-            Task a = new Task(rentReturnExclusive);
-            Task b = new Task(rentReturnExclusive);
-            Task c = new Task(rentReturnShared);
-            Task d = new Task(rentReturnShared);
-
-            a.Start();
-            b.Start();
-            c.Start();
-            d.Start();
+            Task a = Task.Run(rentReturnExclusive);
+            Task b = Task.Run(rentReturnExclusive);
+            Task c = Task.Run(rentReturnShared);
+            Task d = Task.Run(rentReturnShared);
 
             await Task.WhenAll(a, b, c, d);
         }
 
         [TestCase(true)]
         [TestCase(false)]
-        public void Can_rent_and_return(bool canBeShared)
+        public async Task Can_rent_and_return(bool canBeShared)
         {
-            IEthModule ethModule = _modulePool.GetModule(canBeShared);
+            IEthModule ethModule = await _modulePool.GetModule(canBeShared);
             _modulePool.ReturnModule(ethModule);
         }
 
         [TestCase(true)]
         [TestCase(false)]
-        public void Can_rent_and_return_in_a_loop(bool canBeShared)
+        public async Task Can_rent_and_return_in_a_loop(bool canBeShared)
         {
             for (int i = 0; i < 1000; i++)
             {
-                IEthModule ethModule = _modulePool.GetModule(canBeShared);
+                IEthModule ethModule = await _modulePool.GetModule(canBeShared);
                 _modulePool.ReturnModule(ethModule);
             }
         }
diff --git a/src/Nethermind/Nethermind.JsonRpc.Test/Modules/TestRpcModuleProvider.cs b/src/Nethermind/Nethermind.JsonRpc.Test/Modules/TestRpcModuleProvider.cs
index 769dc2527..68f6947f6 100644
--- a/src/Nethermind/Nethermind.JsonRpc.Test/Modules/TestRpcModuleProvider.cs
+++ b/src/Nethermind/Nethermind.JsonRpc.Test/Modules/TestRpcModuleProvider.cs
@@ -1,4 +1,4 @@
-﻿//  Copyright (c) 2018 Demerzel Solutions Limited
+//  Copyright (c) 2018 Demerzel Solutions Limited
 //  This file is part of the Nethermind library.
 // 
 //  The Nethermind library is free software: you can redistribute it and/or modify
@@ -17,6 +17,7 @@
 using System.Collections.Generic;
 using System.IO.Abstractions;
 using System.Reflection;
+using System.Threading.Tasks;
 using Nethermind.JsonRpc.Modules;
 using Nethermind.JsonRpc.Modules.DebugModule;
 using Nethermind.JsonRpc.Modules.Eth;
@@ -62,7 +63,7 @@ namespace Nethermind.JsonRpc.Test.Modules
             return _provider.Resolve(methodName);
         }
 
-        public IModule Rent(string methodName, bool readOnly)
+        public Task<IModule> Rent(string methodName, bool readOnly)
         {
             return _provider.Rent(methodName, readOnly);
         }
@@ -72,4 +73,4 @@ namespace Nethermind.JsonRpc.Test.Modules
             _provider.Return(methodName, module);
         }
     }
-}
\ No newline at end of file
+}
diff --git a/src/Nethermind/Nethermind.JsonRpc/JsonRpcService.cs b/src/Nethermind/Nethermind.JsonRpc/JsonRpcService.cs
index 89bef7230..b61164353 100644
--- a/src/Nethermind/Nethermind.JsonRpc/JsonRpcService.cs
+++ b/src/Nethermind/Nethermind.JsonRpc/JsonRpcService.cs
@@ -1,4 +1,4 @@
-﻿//  Copyright (c) 2018 Demerzel Solutions Limited
+//  Copyright (c) 2018 Demerzel Solutions Limited
 //  This file is part of the Nethermind library.
 // 
 //  The Nethermind library is free software: you can redistribute it and/or modify
@@ -153,7 +153,7 @@ namespace Nethermind.JsonRpc
 
             //execute method
             IResultWrapper resultWrapper = null;
-            IModule module = _rpcModuleProvider.Rent(methodName, method.ReadOnly);
+            IModule module = await _rpcModuleProvider.Rent(methodName, method.ReadOnly);
             bool returnImmediately = methodName != "eth_getLogs";
             Action returnAction = returnImmediately ? (Action) null : () => _rpcModuleProvider.Return(methodName, module);
             try
diff --git a/src/Nethermind/Nethermind.JsonRpc/Modules/BoundedModulePool.cs b/src/Nethermind/Nethermind.JsonRpc/Modules/BoundedModulePool.cs
index cba5f16d2..5079ab900 100644
--- a/src/Nethermind/Nethermind.JsonRpc/Modules/BoundedModulePool.cs
+++ b/src/Nethermind/Nethermind.JsonRpc/Modules/BoundedModulePool.cs
@@ -17,15 +17,17 @@
 using System;
 using System.Collections.Concurrent;
 using System.Threading;
+using System.Threading.Tasks;
 
 namespace Nethermind.JsonRpc.Modules
 {
     public class BoundedModulePool<T> : IRpcModulePool<T> where T : IModule
     {
         private readonly int _timeout;
-        private T _shared;
-        private ConcurrentBag<T> _bag = new ConcurrentBag<T>();
-        private SemaphoreSlim _semaphore;
+        private readonly T _shared;
+        private readonly Task<T> _sharedAsTask;
+        private readonly ConcurrentQueue<T> _pool = new ConcurrentQueue<T>();
+        private readonly SemaphoreSlim _semaphore;
 
         public BoundedModulePool(IRpcModuleFactory<T> factory, int exclusiveCapacity, int timeout)
         {
@@ -35,25 +37,26 @@ namespace Nethermind.JsonRpc.Modules
             _semaphore = new SemaphoreSlim(exclusiveCapacity);
             for (int i = 0; i < exclusiveCapacity; i++)
             {
-                _bag.Add(Factory.Create());
+                _pool.Enqueue(Factory.Create());
             }
 
             _shared = factory.Create();
+            _sharedAsTask = Task.FromResult(_shared);
         }
         
-        public T GetModule(bool canBeShared)
+        public Task<T> GetModule(bool canBeShared)
         {
-            if (canBeShared)
-            {
-                return _shared;
-            }
-            
-            if (!_semaphore.Wait(_timeout))
+            return canBeShared ? _sharedAsTask : SlowPath();
+        }
+
+        private async Task<T> SlowPath()
+        {
+            if (! await _semaphore.WaitAsync(_timeout))
             {
                 throw new TimeoutException($"Unable to rent an instance of {typeof(T).Name}. Too many concurrent requests.");
             }
 
-            _bag.TryTake(out T result);
+            _pool.TryDequeue(out T result);
             return result;
         }
 
@@ -64,7 +67,7 @@ namespace Nethermind.JsonRpc.Modules
                 return;
             }
             
-            _bag.Add(module);
+            _pool.Enqueue(module);
             _semaphore.Release();
         }
 
diff --git a/src/Nethermind/Nethermind.JsonRpc/Modules/IRpcModulePool.cs b/src/Nethermind/Nethermind.JsonRpc/Modules/IRpcModulePool.cs
index 39b57ff2a..b1e0f37f2 100644
--- a/src/Nethermind/Nethermind.JsonRpc/Modules/IRpcModulePool.cs
+++ b/src/Nethermind/Nethermind.JsonRpc/Modules/IRpcModulePool.cs
@@ -14,14 +14,16 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Threading.Tasks;
+
 namespace Nethermind.JsonRpc.Modules
 {
     public interface IRpcModulePool<T> where T : IModule
     {
-        T GetModule(bool canBeShared);
+        Task<T> GetModule(bool canBeShared);
         
         void ReturnModule(T module);
 
         IRpcModuleFactory<T> Factory { get; set; }
     }
-}
\ No newline at end of file
+}
diff --git a/src/Nethermind/Nethermind.JsonRpc/Modules/IRpcModuleProvider.cs b/src/Nethermind/Nethermind.JsonRpc/Modules/IRpcModuleProvider.cs
index 4f695df53..88dbe297d 100644
--- a/src/Nethermind/Nethermind.JsonRpc/Modules/IRpcModuleProvider.cs
+++ b/src/Nethermind/Nethermind.JsonRpc/Modules/IRpcModuleProvider.cs
@@ -1,4 +1,4 @@
-﻿//  Copyright (c) 2018 Demerzel Solutions Limited
+//  Copyright (c) 2018 Demerzel Solutions Limited
 //  This file is part of the Nethermind library.
 // 
 //  The Nethermind library is free software: you can redistribute it and/or modify
@@ -16,6 +16,7 @@
 
 using System.Collections.Generic;
 using System.Reflection;
+using System.Threading.Tasks;
 using Newtonsoft.Json;
 
 namespace Nethermind.JsonRpc.Modules
@@ -34,8 +35,8 @@ namespace Nethermind.JsonRpc.Modules
         
         (MethodInfo MethodInfo, bool ReadOnly) Resolve(string methodName);
         
-        IModule Rent(string methodName, bool canBeShared);
+        Task<IModule> Rent(string methodName, bool canBeShared);
         
         void Return(string methodName, IModule module);
     }
-}
\ No newline at end of file
+}
diff --git a/src/Nethermind/Nethermind.JsonRpc/Modules/NullModuleProvider.cs b/src/Nethermind/Nethermind.JsonRpc/Modules/NullModuleProvider.cs
index c17c719a3..6b9e7f018 100644
--- a/src/Nethermind/Nethermind.JsonRpc/Modules/NullModuleProvider.cs
+++ b/src/Nethermind/Nethermind.JsonRpc/Modules/NullModuleProvider.cs
@@ -1,4 +1,4 @@
-﻿//  Copyright (c) 2018 Demerzel Solutions Limited
+//  Copyright (c) 2018 Demerzel Solutions Limited
 //  This file is part of the Nethermind library.
 // 
 //  The Nethermind library is free software: you can redistribute it and/or modify
@@ -17,6 +17,7 @@
 using System;
 using System.Collections.Generic;
 using System.Reflection;
+using System.Threading.Tasks;
 using Newtonsoft.Json;
 
 namespace Nethermind.JsonRpc.Modules
@@ -24,6 +25,7 @@ namespace Nethermind.JsonRpc.Modules
     public class NullModuleProvider : IRpcModuleProvider
     {
         public static NullModuleProvider Instance = new NullModuleProvider();
+        private static Task<IModule> Null = Task.FromResult(default(IModule));
 
         private NullModuleProvider()
         {
@@ -49,13 +51,13 @@ namespace Nethermind.JsonRpc.Modules
             return (null, false);
         }
 
-        public IModule Rent(string methodName, bool canBeShared)
+        public Task<IModule> Rent(string methodName, bool canBeShared)
         {
-            return null;
+            return Null;
         }
 
         public void Return(string methodName, IModule module)
         {
         }
     }
-}
\ No newline at end of file
+}
diff --git a/src/Nethermind/Nethermind.JsonRpc/Modules/RpcModuleProvider.cs b/src/Nethermind/Nethermind.JsonRpc/Modules/RpcModuleProvider.cs
index 975f87d10..6acd74839 100644
--- a/src/Nethermind/Nethermind.JsonRpc/Modules/RpcModuleProvider.cs
+++ b/src/Nethermind/Nethermind.JsonRpc/Modules/RpcModuleProvider.cs
@@ -1,4 +1,4 @@
-﻿//  Copyright (c) 2018 Demerzel Solutions Limited
+//  Copyright (c) 2018 Demerzel Solutions Limited
 //  This file is part of the Nethermind library.
 // 
 //  The Nethermind library is free software: you can redistribute it and/or modify
@@ -20,6 +20,7 @@ using System.IO;
 using System.IO.Abstractions;
 using System.Linq;
 using System.Reflection;
+using System.Threading.Tasks;
 using Nethermind.Logging;
 using Newtonsoft.Json;
 
@@ -36,8 +37,8 @@ namespace Nethermind.JsonRpc.Modules
         private Dictionary<string, ResolvedMethodInfo> _methods
             = new Dictionary<string, ResolvedMethodInfo>(StringComparer.InvariantCulture);
         
-        private Dictionary<ModuleType, (Func<bool, IModule> RentModule, Action<IModule> ReturnModule)> _pools
-            = new Dictionary<ModuleType, (Func<bool, IModule> RentModule, Action<IModule> ReturnModule)>();
+        private Dictionary<ModuleType, (Func<bool, Task<IModule>> RentModule, Action<IModule> ReturnModule)> _pools
+            = new Dictionary<ModuleType, (Func<bool, Task<IModule>> RentModule, Action<IModule> ReturnModule)>();
         
         private IRpcMethodFilter _filter = NullRpcMethodFilter.Instance;
 
@@ -70,7 +71,7 @@ namespace Nethermind.JsonRpc.Modules
             
             ModuleType moduleType = attribute.ModuleType;
 
-            _pools[moduleType] = (canBeShared => pool.GetModule(canBeShared), m => pool.ReturnModule((T) m));
+            _pools[moduleType] = (async canBeShared => await pool.GetModule(canBeShared), m => pool.ReturnModule((T) m));
             _modules.Add(moduleType);
 
             ((List<JsonConverter>) Converters).AddRange(pool.Factory.GetConverters());
@@ -92,34 +93,30 @@ namespace Nethermind.JsonRpc.Modules
 
         public ModuleResolution Check(string methodName)
         {
-            if (!_methods.ContainsKey(methodName)) return ModuleResolution.Unknown;
+            if (!_methods.TryGetValue(methodName, out ResolvedMethodInfo result)) return ModuleResolution.Unknown;
 
-            ResolvedMethodInfo result = _methods[methodName];
             return _enabledModules.Contains(result.ModuleType) ? ModuleResolution.Enabled : ModuleResolution.Disabled;
         }
 
         public (MethodInfo, bool) Resolve(string methodName)
         {
-            if (!_methods.ContainsKey(methodName)) return (null, false);
+            if (!_methods.TryGetValue(methodName, out ResolvedMethodInfo result)) return (null, false);
 
-            ResolvedMethodInfo result = _methods[methodName];
             return (result.MethodInfo, result.ReadOnly);
         }
 
-        public IModule Rent(string methodName, bool canBeShared)
+        public Task<IModule> Rent(string methodName, bool canBeShared)
         {
-            if (!_methods.ContainsKey(methodName)) return null;
+            if (!_methods.TryGetValue(methodName, out ResolvedMethodInfo result)) return null;
 
-            ResolvedMethodInfo result = _methods[methodName];
             return _pools[result.ModuleType].RentModule(canBeShared);
         }
 
         public void Return(string methodName, IModule module)
         {
-            if (!_methods.ContainsKey(methodName))
+            if (!_methods.TryGetValue(methodName, out ResolvedMethodInfo result))
                 throw new InvalidOperationException("Not possible to return an unresolved module");
 
-            ResolvedMethodInfo result = _methods[methodName];
             _pools[result.ModuleType].ReturnModule(module);
         }
 
diff --git a/src/Nethermind/Nethermind.JsonRpc/Modules/SingletonModulePool.cs b/src/Nethermind/Nethermind.JsonRpc/Modules/SingletonModulePool.cs
index 055c33b95..7761dc5d9 100644
--- a/src/Nethermind/Nethermind.JsonRpc/Modules/SingletonModulePool.cs
+++ b/src/Nethermind/Nethermind.JsonRpc/Modules/SingletonModulePool.cs
@@ -15,18 +15,21 @@
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
 using System;
+using System.Threading.Tasks;
 
 namespace Nethermind.JsonRpc.Modules
 {
     public class SingletonModulePool<T> : IRpcModulePool<T> where T : IModule
     {
         private readonly T _onlyInstance;
+        private readonly Task<T> _onlyInstanceAsTask;
         private readonly bool _allowExclusive;
 
         public SingletonModulePool(T module, bool allowExclusive = true)
         {
             Factory = new SingletonFactory<T>(module);
             _onlyInstance = module;
+            _onlyInstanceAsTask = Task.FromResult(_onlyInstance);
             _allowExclusive = allowExclusive;
         }
 
@@ -37,14 +40,14 @@ namespace Nethermind.JsonRpc.Modules
             _allowExclusive = allowExclusive;
         }
         
-        public T GetModule(bool canBeShared)
+        public Task<T> GetModule(bool canBeShared)
         {
             if (!canBeShared && !_allowExclusive)
             {
                 throw new InvalidOperationException($"{nameof(SingletonModulePool<T>)} can only return shareable modules");
             }
             
-            return _onlyInstance;
+            return _onlyInstanceAsTask;
         }
 
         public void ReturnModule(T module)
@@ -53,4 +56,4 @@ namespace Nethermind.JsonRpc.Modules
 
         public IRpcModuleFactory<T> Factory { get; set; }
     }
-}
\ No newline at end of file
+}
diff --git a/src/Nethermind/Nethermind.JsonRpc/WebSockets/JsonRpcWebSocketsClient.cs b/src/Nethermind/Nethermind.JsonRpc/WebSockets/JsonRpcWebSocketsClient.cs
index a964f1e59..d0deece34 100644
--- a/src/Nethermind/Nethermind.JsonRpc/WebSockets/JsonRpcWebSocketsClient.cs
+++ b/src/Nethermind/Nethermind.JsonRpc/WebSockets/JsonRpcWebSocketsClient.cs
@@ -57,7 +57,7 @@ namespace Nethermind.JsonRpc.WebSockets
             }
 
             Stopwatch stopwatch = Stopwatch.StartNew();
-            using JsonRpcResult result = await _jsonRpcProcessor.ProcessAsync(Encoding.UTF8.GetString(data.ToArray()));
+            using JsonRpcResult result = await _jsonRpcProcessor.ProcessAsync(Encoding.UTF8.GetString(data.Span));
 
             string resultData;
 
