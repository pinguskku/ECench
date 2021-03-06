commit cbdb6e64898a1726ccbe2ac01fa6039cb190d300
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Nov 14 17:25:27 2017 +0000

    some performance work

diff --git a/src/Nevermind/Ethereum.Blockchain.Test/BlockchainTestBase.cs b/src/Nevermind/Ethereum.Blockchain.Test/BlockchainTestBase.cs
index 9576637d9..4fd056c87 100644
--- a/src/Nevermind/Ethereum.Blockchain.Test/BlockchainTestBase.cs
+++ b/src/Nevermind/Ethereum.Blockchain.Test/BlockchainTestBase.cs
@@ -1,5 +1,6 @@
 ﻿using System;
 using System.Collections.Generic;
+using System.Diagnostics;
 using System.IO;
 using System.Linq;
 using System.Numerics;
@@ -37,7 +38,7 @@ namespace Ethereum.Blockchain.Test
         public static IEnumerable<BlockchainTest> LoadTests(string testSet)
         {
             Directory.SetCurrentDirectory(AppDomain.CurrentDomain.BaseDirectory);
-            IEnumerable<string> testDirs = Directory.EnumerateDirectories(".", "st" + testSet);
+            IEnumerable<string> testDirs = Directory.EnumerateDirectories(".", "st" + (testSet.StartsWith("st") ? testSet.Substring(2) : testSet));
             Dictionary<string, Dictionary<string, BlockchainTestJson>> testJsons =
                 new Dictionary<string, Dictionary<string, BlockchainTestJson>>();
             foreach (string testDir in testDirs)
@@ -81,7 +82,7 @@ namespace Ethereum.Blockchain.Test
             return state;
         }
 
-        protected void RunTest(BlockchainTest test)
+        protected void RunTest(BlockchainTest test, Stopwatch stopwatch = null)
         {
             foreach (KeyValuePair<Address, AccountState> accountState in test.Pre)
             {
@@ -128,6 +129,8 @@ namespace Ethereum.Blockchain.Test
             List<Transaction> transactions = new List<Transaction>();
 
             BigInteger gasUsedSoFar = 0;
+
+            stopwatch?.Start();
             foreach (IncomingTransaction testTransaction in oneBlock.Transactions)
             {
                 Transaction transaction = new Transaction();
@@ -153,6 +156,8 @@ namespace Ethereum.Blockchain.Test
                 gasUsedSoFar += receipt.GasUsed;
             }
 
+            stopwatch?.Start();
+
             if (!_stateProvider.AccountExists(header.Beneficiary))
             {
                 _stateProvider.CreateAccount(header.Beneficiary, 0);
@@ -205,8 +210,6 @@ namespace Ethereum.Blockchain.Test
 
             Assert.AreEqual(oneHeader.GasUsed, gasUsedSoFar);
 
-            
-
             Keccak receiptsRoot = BlockProcessor.GetReceiptsRoot(receipts.ToArray());
             Keccak transactionsRoot = BlockProcessor.GetTransactionsRoot(transactions.ToArray());
 
diff --git a/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.csproj b/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.csproj
index 22326770c..bc52780d8 100644
--- a/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.csproj
+++ b/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.csproj
@@ -69,12 +69,12 @@
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </EmbeddedResource>
   </ItemGroup>
-  <!--<ItemGroup>
+  <ItemGroup>
     <EmbeddedResource Include="..\..\tests\BlockchainTests\GeneralStateTests\stNonZeroCallsTest*\*.*">
       <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </EmbeddedResource>
-  </ItemGroup>-->
+  </ItemGroup>
   <ItemGroup>
     <EmbeddedResource Include="..\..\tests\BlockchainTests\GeneralStateTests\stSystemOperationsTest*\*.*">
       <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
@@ -189,7 +189,7 @@
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </EmbeddedResource>
   </ItemGroup>
-  <!--<ItemGroup>
+  <ItemGroup>
     <EmbeddedResource Include="..\..\tests\BlockchainTests\GeneralStateTests\stZeroCallsRevert*\*.*">
       <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
@@ -200,7 +200,7 @@
       <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </EmbeddedResource>
-  </ItemGroup>-->
+  </ItemGroup>
   <ItemGroup>
     <Reference Include="JetBrains.Annotations, Version=11.0.0.0, Culture=neutral, PublicKeyToken=1010a0d8d6380325, processorArchitecture=MSIL">
       <HintPath>..\packages\JetBrains.Annotations.11.0.0\lib\net20\JetBrains.Annotations.dll</HintPath>
diff --git a/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.v3.ncrunchproject b/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.v3.ncrunchproject
index bbd3e5cdf..abbef4c1f 100644
--- a/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.v3.ncrunchproject
+++ b/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.v3.ncrunchproject
@@ -1,21 +1,2775 @@
 ﻿<ProjectConfiguration>
   <Settings>
     <IgnoredTests>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call1MB1024Calldepth_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
       <FixtureTestSelector>
         <FixtureName>Ethereum.Blockchain.Test.PreCompiledContractsTests</FixtureName>
       </FixtureTestSelector>
       <FixtureTestSelector>
         <FixtureName>Ethereum.Blockchain.Test.PreCompiledContracts2Tests</FixtureName>
       </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.RefundTests</FixtureName>
+      </FixtureTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest171_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
       <FixtureTestSelector>
         <FixtureName>Ethereum.Blockchain.Test.ZeroCallsRevertTests</FixtureName>
       </FixtureTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.AttackTests.Test(CrashingTransaction_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest624_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d8g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.MemoryTests</FixtureName>
+      </FixtureTestSelector>
       <FixtureTestSelector>
         <FixtureName>Ethereum.Blockchain.Test.ZeroCallsTests</FixtureName>
       </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.BadOpcodeTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.StaticCallTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CodeCopyTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.SpecialTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.ReturnDataTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CreateTests</FixtureName>
+      </FixtureTestSelector>
       <FixtureTestSelector>
         <FixtureName>Ethereum.Blockchain.Test.NonZeroCallTests</FixtureName>
       </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CodeSizeLimitTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.LogTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.InitCodeTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.StackTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.MemoryStressTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CallCreateCallCodeTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CallCodeTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.RecursiveCreateTests</FixtureName>
+      </FixtureTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(TestStoreGasPrices_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(AmbiguousMethod_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(CreateContractFromMethod_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(CallInfiniteLoop_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(TestKeywords_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(ContractInheritance_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(RecursiveCreateContracts_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(CallLowLevelCreatesSolidity_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(RecursiveCreateContractsCreate4Contracts_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(TestBlockAndTransactionProperties_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(TestOverflow_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(CallRecursiveMethods_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d32g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d87g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d65g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d66g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d34g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d23g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d57g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d124g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d50g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d90g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d16g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(UserTransactionZeroCost_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(UserTransactionGasLimitIsTooLowWhenZeroCost_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d51g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d53g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d126g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d9g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(InternalCallHittingGasLimit2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d96g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d103g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d3g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d81g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d71g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(SuicidesAndSendMoneyToItselfEtherDestroyed_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(SuicidesAndInternlCallSuicidesBonusGasAtCallFailed_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionSendingToZero_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d7g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d25g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionFromCoinbaseNotEnoughFounds_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d88g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d60g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionSendingToEmpty_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d63g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d97g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(SuicidesAndInternlCallSuicidesOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d120g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d92g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d101g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d35g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d28g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d19g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d122g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(SuicidesAndInternlCallSuicidesSuccess_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d12g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d43g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(CreateMessageSuccess_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d74g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d11g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d77g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d33g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d37g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d2g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(CreateMessageReverted_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d41g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d121g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d20g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d39g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(SuicidesStopAfterSuicide_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(StoreGasOnCreate_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d113g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d36g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionToItself_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d55g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(InternalCallHittingGasLimitSuccess_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d68g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d108g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d75g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(RefundOverflow2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d111g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d86g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d109g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(InternlCallStoreClearsSucces_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionToAddressh160minusOne_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionToItselfNotEnoughFounds_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d76g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d69g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d106g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d18g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d61g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d95g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d72g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d14g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d10g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionDataCosts652_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(UserTransactionZeroCostWithData_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d1g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d45g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionNonceCheck_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionNonceCheck2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d62g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d118g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d26g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d114g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(InternlCallStoreClearsOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d64g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d83g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d6g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d85g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d89g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d31g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d123g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(HighGasLimit_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d49g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d54g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(SuicidesAndInternlCallSuicidesSuccess_d1g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d44g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d94g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d17g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d4g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d48g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d107g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d127g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d73g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d30g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d22g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d82g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d102g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionFromCoinbaseHittingBlockGasLimit_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(OverflowGasRequire2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d38g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d125g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d78g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d115g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d93g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d70g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(EmptyTransaction2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d56g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d29g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d79g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d84g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(EmptyTransaction_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d104g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(OverflowGasRequire_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d27g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d80g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d110g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(CreateTransactionReverted_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d67g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d98g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(ContractStoreClearsOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d119g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(CreateTransactionSuccess_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d24g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(SuicidesAndInternlCallSuicidesBonusGasAtCall_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d40g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(TransactionFromCoinbaseHittingBlockGasLimit1_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d5g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d47g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(EmptyTransaction3_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(RefundOverflow_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d100g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d116g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d59g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d46g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d42g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d112g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d15g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d91g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(ContractStoreClearsSuccess_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(InternalCallHittingGasLimit_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(UserTransactionZeroCostWithData_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d105g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d21g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d52g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d99g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d58g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d13g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.TransactionTests.Test(Opcodes_TransactionInit_d117g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest518_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest414_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest641_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest620_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest474_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest578_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest538_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest455_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest406_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest600_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest582_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest531_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest539_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest642_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest419_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest547_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest384_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest594_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest542_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest534_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest440_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest480_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest525_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest484_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest647_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest577_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest563_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest415_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest420_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest585_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest399_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest402_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest461_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest535_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest443_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest471_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest511_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest438_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest464_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest477_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest580_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest445_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest491_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest550_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest587_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest397_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest573_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest589_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest483_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest597_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest576_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest506_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest503_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest513_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest430_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest447_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest626_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest468_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest636_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest470_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest621_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest564_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest413_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest586_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest494_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest609_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest602_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest416_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest396_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest556_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest433_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest436_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest607_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest489_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest558_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest466_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest559_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest386_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest565_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest546_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest450_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest404_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest460_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest537_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest505_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest562_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest637_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest510_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest640_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest467_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest446_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest638_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest541_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest395_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest592_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest643_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest469_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest442_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest644_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest437_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest496_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest599_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest646_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest487_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest423_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest554_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest478_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest456_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest401_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest548_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest425_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest498_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest560_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest500_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest482_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest583_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest516_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest502_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest545_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest462_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest604_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest555_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest454_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest391_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest629_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest410_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest612_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest528_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest411_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest523_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest452_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest412_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest509_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest543_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest619_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest517_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest435_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest398_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest645_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest633_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest451_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest596_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest385_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest575_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest405_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest610_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest579_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest504_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest493_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest520_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest448_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest507_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest495_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest472_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest481_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest508_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest501_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest422_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest476_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest417_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest408_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest645_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest552_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest615_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest574_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest601_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest514_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest566_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest458_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest519_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest428_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest628_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest639_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest457_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest475_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest569_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest512_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest527_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest488_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest618_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest389_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest549_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest485_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest524_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest439_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest581_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest572_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest421_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest533_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest418_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest473_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest616_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest584_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest426_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest571_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest605_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest630_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest387_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest449_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest544_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest444_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest632_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest526_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest499_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest407_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest625_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest553_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest429_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest388_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest611_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest588_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest567_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest441_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest393_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest627_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest635_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest409_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest465_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest532_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest603_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest497_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest424_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.Random2Tests.Test(randomStatetest521_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest290_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest101_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest54_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest286_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest209_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest305_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest73_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest273_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest200_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest336_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest368_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest85_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest18_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest133_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest335_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest379_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest316_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest67_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest33_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest14_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest294_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest17_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest57_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest27_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest170_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest210_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest259_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest106_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest117_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest110_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest81_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest12_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest270_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest172_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest242_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest88_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest138_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest329_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest321_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest143_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest297_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest288_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest281_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest185_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest246_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest9_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest358_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest295_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest191_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest349_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest300_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest298_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest230_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest227_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest161_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest37_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest118_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest45_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest340_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest364_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest130_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest221_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest83_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest232_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest123_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest250_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest357_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest63_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest236_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest243_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest287_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest283_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest249_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest82_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest207_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest159_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest383_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest102_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest84_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest163_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest266_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest10_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest23_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest59_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest312_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest160_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest252_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest247_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest343_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest92_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest112_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest77_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest31_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest356_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest174_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest3_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest155_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest278_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest333_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest94_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest115_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest149_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest50_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest87_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest299_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest282_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest202_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest254_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest80_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest261_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest183_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest371_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest350_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest48_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest47_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest334_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest352_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest95_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest360_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest229_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest205_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest231_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest38_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest164_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest39_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest245_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest257_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest42_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest20_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest366_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest354_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest197_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest363_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest216_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest60_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest0_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest264_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest49_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest146_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest341_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest318_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest324_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest157_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest280_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest223_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest201_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest78_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest285_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest154_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest361_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest293_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest156_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest204_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest180_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest309_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest139_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest28_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest179_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest274_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest147_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest53_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest120_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest1_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest320_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest219_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest244_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest178_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest198_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest26_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest268_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest129_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest121_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest326_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest15_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest144_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest211_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest5_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest32_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest372_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest292_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest13_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest322_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest173_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest337_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest348_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest265_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest269_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest24_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest248_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest52_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest327_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest302_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest301_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest111_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest303_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest188_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest355_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest176_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest41_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest119_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest122_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest134_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest199_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest380_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest131_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest125_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest97_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest267_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest36_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest195_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest153_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest98_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest310_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest222_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest237_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest304_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest105_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest169_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest339_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest136_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest378_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest150_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest75_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest62_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest6_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest46_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest308_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest175_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest271_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest124_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest238_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest251_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest30_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest89_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest376_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest104_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest126_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest66_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest325_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest189_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest135_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest311_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest187_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest296_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest276_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest74_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest51_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest382_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest167_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest145_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest315_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest116_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest347_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest214_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest55_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest69_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest381_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest194_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest377_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest103_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest29_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest96_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest220_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest162_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest107_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest43_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest370_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest345_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest90_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest367_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest22_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest226_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest332_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest346_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest279_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest208_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest328_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest275_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest19_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest323_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest291_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest228_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest151_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest233_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest241_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest362_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest338_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest108_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest100_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest72_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest215_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest342_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest25_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest177_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest359_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest192_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest353_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest58_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest137_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest369_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest196_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest225_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest11_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest217_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest190_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest365_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest263_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest206_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest212_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest375_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest114_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest351_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest184_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest158_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest260_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest7_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest306_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest64_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest142_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest166_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest16_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest4_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest313_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCallsOnNonEmptyReturnData_d2g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call1MB1024Calldepth_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_ecrec_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_ecrec_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_identity_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_identity_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_identity2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_identity2_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_rip160_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_rip160_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_sha256_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000_sha256_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000bytesContract50_1_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000bytesContract50_1_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000bytesContract50_2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000bytesContract50_2_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000bytesContract50_3_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Call50000bytesContract50_3_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Callcode50000_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Callcode50000_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Create1000_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Create1000_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(QuadraticComplexitySolidity_CallDataCopy_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(QuadraticComplexitySolidity_CallDataCopy_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Return50000_2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Return50000_2_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Return50000_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.QuadraticComplexityTests.Test(Return50000_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(TestContractInteraction_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(TestStructuresAndVariabless_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(TestContractSuicide_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.SolidityTests.Test(TestCryptographicFunctions_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCalls_d1g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d0g2v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(LoopCallsDepthThenRevert_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrecompiledTouchCC_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCallsOnNonEmptyReturnData_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateOOG_d1g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateOOG_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCallsOnNonEmptyReturnData_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInInit_d0g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d2g3v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d3g2v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(PythonRevertTestTue201814-1430_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCallsOnNonEmptyReturnData_d1g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcode_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateAddressCollision_d0g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInInit_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d5g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCallsOnNonEmptyReturnData_d3g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInInit_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d1g2v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d2g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCalls_d2g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d1g2v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(LoopCallsThenRevert_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeWithBigOutputInInit_d0g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d5g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInInit_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d1g3v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d0g3v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCallsOnNonEmptyReturnData_d3g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCalls_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(LoopCallsThenRevert_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeDirectCall_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d2g2v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d1g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateAddressCollision_d1g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeWithBigOutputInInit_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateAddressCollision_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrefoundEmptyCallOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateAddressCollision_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateOOG_d1g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d1g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d3g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d3g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeWithBigOutputInInit_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d2g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeWithBigOutputInInit_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(TouchToEmptyAccountRevert2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertInCallCode_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d1g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(LoopDelegateCallsDepthThenRevert_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCreate_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(LoopCallsDepthThenRevert3_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCreate_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(TouchToEmptyAccountRevert3_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCallsOnNonEmptyReturnData_d2g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrefoundOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeDirectCall_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d3g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCalls_d2g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d2g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertSubCallStorageOOG_d0g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateAddressCollision_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcode_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d3g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrefoundCall_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(LoopCallsDepthThenRevert2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d1g3v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrecompiledTouch_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertSubCallStorageOOG2_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d3g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertInDelegateCall_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCalls_d3g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d1g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertSubCallStorageOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d4g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d3g3v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcode_d0g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateAddressCollision_d1g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrefoundEmptyCall_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCalls_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateOOG_d1g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d2g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d2g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d1g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertSubCallStorageOOG2_d0g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d1g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCreateReturns_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertInStaticCall_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeReturn_d4g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrecompiledTouchDC_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateOOG_d0g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertRemoteSubCallStorageOOG_d0g2v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrefoundCallOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertSubCallStorageOOG_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d3g3v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrefoundEmptyOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d2g2v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeInCallsOnNonEmptyReturnData_d1g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d2g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d0g2v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateAddressCollision_d1g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepth2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertSubCallStorageOOG2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertRemoteSubCallStorageOOG2_d0g2v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d0g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCalls_d3g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeCalls_d1g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d2g3v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrefoundEmpty_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(TouchToEmptyAccountRevert_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateAddressCollision_d1g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d3g2v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateOOG_d0g0v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertDepthCreateOOG_d1g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcode_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d3g1v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertOpcodeMultipleSubCalls_d0g3v1_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertRemoteSubCallStorageOOG2_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertRemoteSubCallStorageOOG_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertSubCallStorageOOG2_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertSubCallStorageOOG_d0g1v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertPrefound_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(NashatyrevSuicideRevert_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertRemoteSubCallStorageOOG_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RevertTests.Test(RevertRemoteSubCallStorageOOG2_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest307_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.AttackTests.Test(ContractCreationSpam_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
     </IgnoredTests>
   </Settings>
 </ProjectConfiguration>
\ No newline at end of file
diff --git a/src/Nevermind/Ethereum.Test.Base/TestStorageProvider.cs b/src/Nevermind/Ethereum.Test.Base/TestStorageProvider.cs
index 59345a6ec..cef80b625 100644
--- a/src/Nevermind/Ethereum.Test.Base/TestStorageProvider.cs
+++ b/src/Nevermind/Ethereum.Test.Base/TestStorageProvider.cs
@@ -21,7 +21,7 @@ namespace Ethereum.Test.Base
         {
             if (!_storages.ContainsKey(address))
             {
-                _storages[address] = new StorageTree(_db);
+                _storages[address] = new StorageTree(new InMemoryDb());
             }
 
             return GetStorage(address);
diff --git a/src/Nevermind/Ethereum.VM.Test/VMTestBase.cs b/src/Nevermind/Ethereum.VM.Test/VMTestBase.cs
index 882e5925a..662b00b65 100644
--- a/src/Nevermind/Ethereum.VM.Test/VMTestBase.cs
+++ b/src/Nevermind/Ethereum.VM.Test/VMTestBase.cs
@@ -163,7 +163,7 @@ namespace Ethereum.VM.Test
                 }
             }
 
-            EvmState state = new EvmState((ulong)test.Execution.Gas, environment);
+            EvmState state = new EvmState((ulong)test.Execution.Gas, environment, ExecutionType.Transaction);
 
             if (test.Out == null)
             {
diff --git a/src/Nevermind/Nevermind.Blockchain.Test.Runner/App.config b/src/Nevermind/Nevermind.Blockchain.Test.Runner/App.config
new file mode 100644
index 000000000..9d2c7adf3
--- /dev/null
+++ b/src/Nevermind/Nevermind.Blockchain.Test.Runner/App.config
@@ -0,0 +1,6 @@
+<?xml version="1.0" encoding="utf-8"?>
+<configuration>
+    <startup> 
+        <supportedRuntime version="v4.0" sku=".NETFramework,Version=v4.7"/>
+    </startup>
+</configuration>
diff --git a/src/Nevermind/Nevermind.Blockchain.Test.Runner/Nevermind.Blockchain.Test.Runner.csproj b/src/Nevermind/Nevermind.Blockchain.Test.Runner/Nevermind.Blockchain.Test.Runner.csproj
new file mode 100644
index 000000000..cf2a0b8cc
--- /dev/null
+++ b/src/Nevermind/Nevermind.Blockchain.Test.Runner/Nevermind.Blockchain.Test.Runner.csproj
@@ -0,0 +1,76 @@
+﻿<?xml version="1.0" encoding="utf-8"?>
+<Project ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
+  <Import Project="$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props" Condition="Exists('$(MSBuildExtensionsPath)\$(MSBuildToolsVersion)\Microsoft.Common.props')" />
+  <PropertyGroup>
+    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
+    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
+    <ProjectGuid>{8413AF93-4F09-45F3-96F9-47040B56B8AF}</ProjectGuid>
+    <OutputType>Exe</OutputType>
+    <RootNamespace>Nevermind.Blockchain.Test.Runner</RootNamespace>
+    <AssemblyName>Nevermind.Blockchain.Test.Runner</AssemblyName>
+    <TargetFrameworkVersion>v4.7</TargetFrameworkVersion>
+    <FileAlignment>512</FileAlignment>
+    <AutoGenerateBindingRedirects>true</AutoGenerateBindingRedirects>
+    <TargetFrameworkProfile />
+  </PropertyGroup>
+  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Debug|AnyCPU' ">
+    <PlatformTarget>AnyCPU</PlatformTarget>
+    <DebugSymbols>true</DebugSymbols>
+    <DebugType>full</DebugType>
+    <Optimize>false</Optimize>
+    <OutputPath>bin\Debug\</OutputPath>
+    <DefineConstants>DEBUG;TRACE</DefineConstants>
+    <ErrorReport>prompt</ErrorReport>
+    <WarningLevel>4</WarningLevel>
+  </PropertyGroup>
+  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
+    <PlatformTarget>AnyCPU</PlatformTarget>
+    <DebugType>pdbonly</DebugType>
+    <Optimize>true</Optimize>
+    <OutputPath>bin\Release\</OutputPath>
+    <DefineConstants>TRACE</DefineConstants>
+    <ErrorReport>prompt</ErrorReport>
+    <WarningLevel>4</WarningLevel>
+  </PropertyGroup>
+  <ItemGroup>
+    <Reference Include="System">
+      <HintPath>..\..\..\..\..\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.7\System.dll</HintPath>
+    </Reference>
+    <Reference Include="System.Core" />
+    <Reference Include="System.Xml.Linq" />
+    <Reference Include="System.Data.DataSetExtensions" />
+    <Reference Include="Microsoft.CSharp" />
+    <Reference Include="System.Data" />
+    <Reference Include="System.Net.Http" />
+    <Reference Include="System.Xml" />
+  </ItemGroup>
+  <ItemGroup>
+    <Compile Include="PerfTest.cs" />
+    <Compile Include="Program.cs" />
+    <Compile Include="Properties\AssemblyInfo.cs" />
+  </ItemGroup>
+  <ItemGroup>
+    <None Include="App.config" />
+  </ItemGroup>
+  <ItemGroup>
+    <EmbeddedResource Include="..\..\tests\BlockchainTests\GeneralStateTests\**\*.*">
+      <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
+      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
+    </EmbeddedResource>
+  </ItemGroup>
+  <ItemGroup>
+    <ProjectReference Include="..\Ethereum.Blockchain.Test\Ethereum.Blockchain.Test.csproj">
+      <Project>{f6a86097-cb14-4d78-b4da-082b163219a8}</Project>
+      <Name>Ethereum.Blockchain.Test</Name>
+    </ProjectReference>
+    <ProjectReference Include="..\Ethereum.Test.Base\Ethereum.Test.Base.csproj">
+      <Project>{72e80636-d6ca-42db-a49f-830cb9bad87d}</Project>
+      <Name>Ethereum.Test.Base</Name>
+    </ProjectReference>
+    <ProjectReference Include="..\Nevermind.Evm\Nevermind.Evm.csproj">
+      <Project>{13911438-F79E-4DA4-B3FF-0649C38D32B1}</Project>
+      <Name>Nevermind.Evm</Name>
+    </ProjectReference>
+  </ItemGroup>
+  <Import Project="$(MSBuildToolsPath)\Microsoft.CSharp.targets" />
+</Project>
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Blockchain.Test.Runner/Nevermind.Blockchain.Test.Runner.v3.ncrunchproject b/src/Nevermind/Nevermind.Blockchain.Test.Runner/Nevermind.Blockchain.Test.Runner.v3.ncrunchproject
new file mode 100644
index 000000000..319cd523c
--- /dev/null
+++ b/src/Nevermind/Nevermind.Blockchain.Test.Runner/Nevermind.Blockchain.Test.Runner.v3.ncrunchproject
@@ -0,0 +1,5 @@
+﻿<ProjectConfiguration>
+  <Settings>
+    <IgnoreThisComponentCompletely>True</IgnoreThisComponentCompletely>
+  </Settings>
+</ProjectConfiguration>
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Blockchain.Test.Runner/PerfTest.cs b/src/Nevermind/Nevermind.Blockchain.Test.Runner/PerfTest.cs
new file mode 100644
index 000000000..2ab0ef8e4
--- /dev/null
+++ b/src/Nevermind/Nevermind.Blockchain.Test.Runner/PerfTest.cs
@@ -0,0 +1,47 @@
+﻿using System;
+using System.Collections.Generic;
+using System.Diagnostics;
+using Ethereum.Blockchain.Test;
+
+namespace Nevermind.Blockchain.Test.Runner
+{
+    public class PerfTest : BlockchainTestBase
+    {
+        public long RunTests(string subset, int iterations = 1)
+        {
+            long totalMs = 0L;
+            Console.WriteLine($"RUNNING {subset}");
+            Stopwatch stopwatch = new Stopwatch();
+            IEnumerable<BlockchainTest> test = LoadTests(subset);
+            foreach (BlockchainTest blockchainTest in test)
+            {
+                stopwatch.Reset();
+                for (int i = 0; i < iterations; i++)
+                {
+                    Setup();
+                    try
+                    {
+                        RunTest(blockchainTest, stopwatch);
+                    }
+                    catch (Exception e)
+                    {
+                        ConsoleColor mem = Console.ForegroundColor;
+                        Console.ForegroundColor = ConsoleColor.Red;
+                        Console.WriteLine($"  EXCEPTION: {e}");
+                        Console.ForegroundColor = mem;
+                    }
+                }
+                
+                long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
+                long ms = 1_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
+                totalMs += ms;
+                Console.WriteLine($"  {blockchainTest.Name, -80}{ns / iterations, 14}ns{ms / iterations, 8}ms");
+            }
+
+            Console.WriteLine();
+            Console.WriteLine();
+            Console.WriteLine();
+            return totalMs;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Blockchain.Test.Runner/Program.cs b/src/Nevermind/Nevermind.Blockchain.Test.Runner/Program.cs
new file mode 100644
index 000000000..6e148414b
--- /dev/null
+++ b/src/Nevermind/Nevermind.Blockchain.Test.Runner/Program.cs
@@ -0,0 +1,64 @@
+﻿using System;
+using System.Diagnostics;
+using Nevermind.Evm;
+
+namespace Nevermind.Blockchain.Test.Runner
+{
+    internal class Program
+    {
+        private const int StandardIterations = 1;
+
+        private static void Main(string[] args)
+        {
+            long totalMs = 0L;
+            ShouldLog.Evm = false;
+            ShouldLog.TransactionProcessor = false;
+            PerfTest perfTest = new PerfTest();
+            //totalMs += perfTest.RunTests("stAttackTest");
+            totalMs += perfTest.RunTests("stBadOpcode", StandardIterations);
+            totalMs += perfTest.RunTests("stCallCodes", StandardIterations);
+            totalMs += perfTest.RunTests("stCallCreateCallCodeTest", StandardIterations);
+            totalMs += perfTest.RunTests("stCallDelegateCodesCallCodeHomestead", StandardIterations);
+            totalMs += perfTest.RunTests("stCallDelegateCodesHomestead", StandardIterations);
+            //totalMs += perfTest.RunTests("stChangedEIP150", StandardIterations);
+            totalMs += perfTest.RunTests("stCodeCopyTest", StandardIterations);
+            totalMs += perfTest.RunTests("stCodeSizeLimit", StandardIterations);
+            totalMs += perfTest.RunTests("stCreateTest", StandardIterations);
+            totalMs += perfTest.RunTests("stDelegatecallTestHomestead", StandardIterations);
+            //totalMs += perfTest.RunTests("stEIP150singleCodeGasPrices", StandardIterations);
+            //totalMs += perfTest.RunTests("stEIP150Specific", StandardIterations);
+            //totalMs += perfTest.RunTests("stEIP158Specific", StandardIterations);
+            totalMs += perfTest.RunTests("stExample", StandardIterations);
+            totalMs += perfTest.RunTests("stHomesteadSpecific", StandardIterations);
+            totalMs += perfTest.RunTests("stInitCodeTest", StandardIterations);
+            totalMs += perfTest.RunTests("stLogTests", StandardIterations);
+            //totalMs += perfTest.RunTests("stMemExpandingEIP150Calls", StandardIterations);
+            totalMs += perfTest.RunTests("stMemoryStressTest", StandardIterations);
+            totalMs += perfTest.RunTests("stMemoryTest", StandardIterations);
+            totalMs += perfTest.RunTests("stNonZeroCallsTest", StandardIterations);
+            totalMs += perfTest.RunTests("stPreCompiledContracts", StandardIterations);
+            totalMs += perfTest.RunTests("stPreCompiledContracts2", StandardIterations);
+            //totalMs += perfTest.RunTests("stQuadraticComplexityTest", StandardIterations);
+            totalMs += perfTest.RunTests("stRandom", StandardIterations);
+            totalMs += perfTest.RunTests("stRandom2", StandardIterations);
+            //totalMs += perfTest.RunTests("stRecursiveCreate", StandardIterations);
+            totalMs += perfTest.RunTests("stRefundTest", StandardIterations);
+            totalMs += perfTest.RunTests("stReturnDataTest", StandardIterations);
+            totalMs += perfTest.RunTests("stRevertTest", StandardIterations);
+            totalMs += perfTest.RunTests("stSolidityTest", StandardIterations);
+            totalMs += perfTest.RunTests("stSpecialTest", StandardIterations);
+            totalMs += perfTest.RunTests("stStackTests", StandardIterations);
+            totalMs += perfTest.RunTests("stStaticCall", StandardIterations);
+            totalMs += perfTest.RunTests("stSystemOperationsTest", StandardIterations);
+            totalMs += perfTest.RunTests("stTransactionTest", StandardIterations);
+            //totalMs += perfTest.RunTests("stTransitionTest", StandardIterations);
+            //totalMs += perfTest.RunTests("stWalletTest", StandardIterations);
+            totalMs += perfTest.RunTests("stZeroCallsRevert", StandardIterations);
+            totalMs += perfTest.RunTests("stZeroCallsTest", StandardIterations);
+            //totalMs += perfTest.RunTests("stZeroKnowledge", StandardIterations);
+            //totalMs += perfTest.RunTests("stZeroKnowledge2", StandardIterations);
+            Console.WriteLine($"FINISHED in {totalMs}ms");
+            Console.ReadLine();
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Blockchain.Test.Runner/Properties/AssemblyInfo.cs b/src/Nevermind/Nevermind.Blockchain.Test.Runner/Properties/AssemblyInfo.cs
new file mode 100644
index 000000000..8ec9f5605
--- /dev/null
+++ b/src/Nevermind/Nevermind.Blockchain.Test.Runner/Properties/AssemblyInfo.cs
@@ -0,0 +1,36 @@
+﻿using System.Reflection;
+using System.Runtime.CompilerServices;
+using System.Runtime.InteropServices;
+
+// General Information about an assembly is controlled through the following
+// set of attributes. Change these attribute values to modify the information
+// associated with an assembly.
+[assembly: AssemblyTitle("Nevermind.Blockchain.Test.Runner")]
+[assembly: AssemblyDescription("")]
+[assembly: AssemblyConfiguration("")]
+[assembly: AssemblyCompany("")]
+[assembly: AssemblyProduct("Nevermind.Blockchain.Test.Runner")]
+[assembly: AssemblyCopyright("Copyright ©  2017")]
+[assembly: AssemblyTrademark("")]
+[assembly: AssemblyCulture("")]
+
+// Setting ComVisible to false makes the types in this assembly not visible
+// to COM components.  If you need to access a type in this assembly from
+// COM, set the ComVisible attribute to true on that type.
+[assembly: ComVisible(false)]
+
+// The following GUID is for the ID of the typelib if this project is exposed to COM
+[assembly: Guid("8413af93-4f09-45f3-96f9-47040b56b8af")]
+
+// Version information for an assembly consists of the following four values:
+//
+//      Major Version
+//      Minor Version
+//      Build Number
+//      Revision
+//
+// You can specify all the values or you can default the Build and Revision Numbers
+// by using the '*' as shown below:
+// [assembly: AssemblyVersion("1.0.*")]
+[assembly: AssemblyVersion("1.0.0.0")]
+[assembly: AssemblyFileVersion("1.0.0.0")]
diff --git a/src/Nevermind/Nevermind.Core/Address.cs b/src/Nevermind/Nevermind.Core/Address.cs
index 6d545634c..33d499d61 100644
--- a/src/Nevermind/Nevermind.Core/Address.cs
+++ b/src/Nevermind/Nevermind.Core/Address.cs
@@ -9,10 +9,10 @@ namespace Nevermind.Core
     {
         private const int AddressLengthInBytes = 20;
 
-        public static Address Zero { get; } = new Address(new byte[20]);
+        public readonly Hex Hex;
 
         public Address(Keccak keccak)
-            :this(keccak.Bytes.Slice(12, 20))
+            : this(keccak.Bytes.Slice(12, 20))
         {
         }
 
@@ -31,16 +31,29 @@ namespace Nevermind.Core
             Hex = hex;
         }
 
+        public static Address Zero { get; } = new Address(new byte[20]);
+
+        public bool Equals(Address other)
+        {
+            if (ReferenceEquals(null, other))
+            {
+                return false;
+            }
+            if (ReferenceEquals(this, other))
+            {
+                return true;
+            }
+            return Equals(Hex, other.Hex);
+        }
+
         public string ToString(bool withEip55Checksum)
         {
             // use inside hex?
             return string.Concat("0x", Hex.FromBytes(Hex, false, false, withEip55Checksum));
         }
 
-        public Hex Hex { get; set; }
-
         /// <summary>
-        /// https://github.com/ethereum/EIPs/issues/55
+        ///     https://github.com/ethereum/EIPs/issues/55
         /// </summary>
         /// <returns></returns>
         public override string ToString()
@@ -48,24 +61,23 @@ namespace Nevermind.Core
             return ToString(false);
         }
 
-        public bool Equals(Address other)
-        {
-            if (ReferenceEquals(null, other)) return false;
-            if (ReferenceEquals(this, other)) return true;
-            return Equals(ToString(), other.ToString());
-        }
-
         public override bool Equals(object obj)
         {
-            if (ReferenceEquals(null, obj)) return false;
-            if (ReferenceEquals(this, obj)) return true;
-            if (obj.GetType() != this.GetType()) return false;
-            return Equals((Address) obj);
+            if (ReferenceEquals(null, obj))
+            {
+                return false;
+            }
+            if (ReferenceEquals(this, obj))
+            {
+                return true;
+            }
+
+            return obj.GetType() == GetType() && Equals((Address)obj);
         }
 
         public override int GetHashCode()
         {
-            return ToString().GetHashCode();
+            return Hex.GetHashCode();
         }
     }
-}
+}
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Core/AddressExtensions.cs b/src/Nevermind/Nevermind.Core/AddressExtensions.cs
new file mode 100644
index 000000000..fdde2fd22
--- /dev/null
+++ b/src/Nevermind/Nevermind.Core/AddressExtensions.cs
@@ -0,0 +1,14 @@
+using System.Numerics;
+using Nevermind.Core.Sugar;
+
+namespace Nevermind.Core
+{
+    public static class AddressExtensions
+    {
+        public static bool IsPrecompiled(this Address address)
+        {
+            BigInteger asInt = address.Hex.ToUnsignedBigInteger();
+            return asInt > 0 && asInt < 4;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Core/Encoding/Hex.cs b/src/Nevermind/Nevermind.Core/Encoding/Hex.cs
index bc6a21f1f..308362015 100644
--- a/src/Nevermind/Nevermind.Core/Encoding/Hex.cs
+++ b/src/Nevermind/Nevermind.Core/Encoding/Hex.cs
@@ -1,5 +1,6 @@
 ﻿using System;
 using System.Diagnostics;
+using System.Diagnostics.CodeAnalysis;
 
 namespace Nevermind.Core.Encoding
 {
@@ -33,6 +34,11 @@ namespace Nevermind.Core.Encoding
                 return false;
             }
 
+            if (_bytes != null && obj._bytes != null)
+            {
+                return Sugar.Bytes.UnsafeCompare(_bytes, obj._bytes);
+            }
+
             if (_hexString != null && obj._hexString != null)
             {
                 return _hexString == obj;
@@ -43,9 +49,9 @@ namespace Nevermind.Core.Encoding
                 return _hexString == obj;
             }
 
-            if (_hexString == null && obj._hexString == null)
+            if (_hexString == null && obj._hexString != null)
             {
-                return this == (string) obj;
+                return this == obj._hexString;
             }
 
             Debug.Assert(false, "one of the conditions should be true");
@@ -66,7 +72,7 @@ namespace Nevermind.Core.Encoding
 
             // this actually depends on whether it is quantity or byte data...
             string trimmed = noLeadingZeros ? _hexString.TrimStart('0') : _hexString;
-            if(trimmed.Length == 0)
+            if (trimmed.Length == 0)
             {
                 trimmed = string.Concat(trimmed, '0');
             }
@@ -74,7 +80,7 @@ namespace Nevermind.Core.Encoding
             return withZeroX ? string.Concat("0x", trimmed) : trimmed;
         }
 
-        public static implicit operator byte[](Hex hex)
+        public static implicit operator byte[] (Hex hex)
         {
             return hex._bytes ?? (hex._bytes = ToBytes(hex._hexString));
         }
@@ -111,13 +117,37 @@ namespace Nevermind.Core.Encoding
                 return false;
             }
 
-            return Equals((Hex) obj);
+            return Equals((Hex)obj);
         }
 
+        [SuppressMessage("ReSharper", "NonReadonlyMemberInGetHashCode")]
         public override int GetHashCode()
         {
-            // ReSharper disable once NonReadonlyMemberInGetHashCode
-            return (_hexString ?? this).GetHashCode();
+            if (_bytes == null)
+            {
+                _bytes = ToBytes(_hexString);
+            }
+
+            if (_bytes.Length == 0)
+            {
+                return 0;
+            }
+
+            unchecked
+            {
+                const int p = 16777619;
+                int hash = (int)2166136261;
+
+                hash = hash ^ _bytes[0] * p;
+                hash = hash ^ _bytes[_bytes.Length - 1] * p;
+
+                hash += hash << 13;
+                hash ^= hash >> 7;
+                hash += hash << 3;
+                hash ^= hash >> 17;
+                hash += hash << 5;
+                return hash;
+            }
         }
 
         private static uint[] CreateLookup32(string format)
@@ -126,7 +156,7 @@ namespace Nevermind.Core.Encoding
             for (int i = 0; i < 256; i++)
             {
                 string s = i.ToString(format);
-                result[i] = s[0] + ((uint) s[1] << 16);
+                result[i] = s[0] + ((uint)s[1] << 16);
             }
             return result;
         }
@@ -152,8 +182,8 @@ namespace Nevermind.Core.Encoding
             for (int i = 0; i < bytes.Length; i++)
             {
                 uint val = Lookup32[bytes[i]];
-                char char1 = (char) val;
-                char char2 = (char) (val >> 16);
+                char char1 = (char)val;
+                char char2 = (char)(val >> 16);
 
                 if (leadingZeros <= i * 2)
                 {
diff --git a/src/Nevermind/Nevermind.Core/Encoding/Keccak.cs b/src/Nevermind/Nevermind.Core/Encoding/Keccak.cs
index a44577413..91030e77a 100644
--- a/src/Nevermind/Nevermind.Core/Encoding/Keccak.cs
+++ b/src/Nevermind/Nevermind.Core/Encoding/Keccak.cs
@@ -5,7 +5,7 @@ using HashLib;
 namespace Nevermind.Core.Encoding
 {
     [DebuggerStepThrough]
-    public class Keccak : IEquatable<Keccak>
+    public struct Keccak : IEquatable<Keccak>
     {
         private static readonly IHash Hash = HashFactory.Crypto.SHA3.CreateKeccak256();
 
@@ -96,45 +96,30 @@ namespace Nevermind.Core.Encoding
 
         public bool Equals(Keccak other)
         {
-            if (ReferenceEquals(null, other)) return false;
-            if (ReferenceEquals(this, other)) return true;
-
-            // timing attacks? probably not
-            for (int i = 0; i < 32; i++)
-            {
-                if (other.Bytes[i] != Bytes[i])
-                {
-                    return false;
-                }
-            }
-
-            return true;
+            return Sugar.Bytes.UnsafeCompare(other.Bytes, Bytes);
         }
 
         public override bool Equals(object obj)
         {
-            if (ReferenceEquals(null, obj)) return false;
-            if (ReferenceEquals(this, obj)) return true;
-            return obj.GetType() == GetType() && Equals((Keccak)obj);
+            return obj?.GetType() == typeof(Keccak) && Equals((Keccak)obj);
         }
 
         public override int GetHashCode()
         {
-            return Bytes[0] ^ Bytes[31];
-        }
-
-        public static bool operator ==(Keccak a, Keccak b)
-        {
-            if (ReferenceEquals(a, b))
+            unchecked
             {
-                return true;
-            }
+                const int p = 16777619;
+                int hash = (int)2166136261;
 
-            if (ReferenceEquals(a, null) || ReferenceEquals(b, null))
-            {
-                return false;
+                hash = hash ^ Bytes[0] * p;
+                hash = hash ^ Bytes[16] * p;
+                hash = hash ^ Bytes[31] * p;
+                return hash;
             }
+        }
 
+        public static bool operator ==(Keccak a, Keccak b)
+        {
             return Sugar.Bytes.UnsafeCompare(a.Bytes, b.Bytes);
         }
 
diff --git a/src/Nevermind/Nevermind.Core/Encoding/Rlp.cs b/src/Nevermind/Nevermind.Core/Encoding/Rlp.cs
index edf770198..f3de8e9a1 100644
--- a/src/Nevermind/Nevermind.Core/Encoding/Rlp.cs
+++ b/src/Nevermind/Nevermind.Core/Encoding/Rlp.cs
@@ -183,6 +183,27 @@ namespace Nevermind.Core.Encoding
             return BitConverter.ToInt32(padded, 0);
         }
 
+        // experimenting
+        public static Rlp Encode(params Keccak[] sequence)
+        {
+            byte[] concatenation = new byte[0];
+            foreach (Keccak item in sequence)
+            {
+                byte[] itemBytes = Encode(item).Bytes;
+                // do that at once (unnecessary objects creation here)
+                concatenation = Sugar.Bytes.Concat(concatenation, itemBytes);
+            }
+
+            if (concatenation.Length < 56)
+            {
+                return new Rlp(Sugar.Bytes.Concat((byte)(192 + concatenation.Length), concatenation));
+            }
+
+            byte[] serializedLength = SerializeLength(concatenation.Length);
+            byte prefix = (byte)(247 + serializedLength.Length);
+            return new Rlp(Sugar.Bytes.Concat(prefix, serializedLength, concatenation));
+        }
+
         [SuppressMessage("ReSharper", "PossibleMultipleEnumeration")]
         public static Rlp Encode(params object[] sequence)
         {
@@ -239,6 +260,11 @@ namespace Nevermind.Core.Encoding
                 return Encode(keccak);
             }
 
+            if (item is Keccak[] keccakArray)
+            {
+                return Encode(keccakArray);
+            }
+
             if (item is Address address)
             {
                 return Encode(address);
@@ -382,7 +408,7 @@ namespace Nevermind.Core.Encoding
 
         public static readonly Rlp OfEmptyByteArray = new Rlp(128);
 
-        public static Rlp OfEmptySequence = Encode();
+        public static Rlp OfEmptySequence = Encode(new object[] {});
 
         private static readonly Dictionary<RuntimeTypeHandle, IRlpDecoder> Decoders =
             new Dictionary<RuntimeTypeHandle, IRlpDecoder>
diff --git a/src/Nevermind/Nevermind.Core/Nevermind.Core.csproj b/src/Nevermind/Nevermind.Core/Nevermind.Core.csproj
index 9d699ab28..99d8e3690 100644
--- a/src/Nevermind/Nevermind.Core/Nevermind.Core.csproj
+++ b/src/Nevermind/Nevermind.Core/Nevermind.Core.csproj
@@ -53,6 +53,7 @@
   </ItemGroup>
   <ItemGroup>
     <Compile Include="Account.cs" />
+    <Compile Include="AddressExtensions.cs" />
     <Compile Include="ChainId.cs" />
     <Compile Include="Difficulty\DifficultyCalculatorFactory.cs" />
     <Compile Include="Difficulty\ByzantiumDifficultyCalculator.cs" />
diff --git a/src/Nevermind/Nevermind.Core/Sugar/Bytes.cs b/src/Nevermind/Nevermind.Core/Sugar/Bytes.cs
index de35f8563..107b9e58c 100644
--- a/src/Nevermind/Nevermind.Core/Sugar/Bytes.cs
+++ b/src/Nevermind/Nevermind.Core/Sugar/Bytes.cs
@@ -2,6 +2,7 @@
 using System.Collections;
 using System.Numerics;
 using System.Runtime.CompilerServices;
+using Nevermind.Core.Encoding;
 
 namespace Nevermind.Core.Sugar
 {
@@ -222,6 +223,11 @@ namespace Nevermind.Core.Sugar
         ////    return new BigInteger(unsignedResult);
         ////}
 
+        public static BigInteger ToUnsignedBigInteger(this Hex hex, Endianness endianness = Endianness.Big, bool noReverse = false)
+        {
+            return ((byte[])hex).ToUnsignedBigInteger();
+        }
+
         public static BigInteger ToUnsignedBigInteger(this byte[] bytes, Endianness endianness = Endianness.Big, bool noReverse = false)
         {
             if (BitConverter.IsLittleEndian && endianness == Endianness.Big)
diff --git a/src/Nevermind/Nevermind.Evm/EvmMemory.cs b/src/Nevermind/Nevermind.Evm/EvmMemory.cs
index da722fc1b..ae4e60e88 100644
--- a/src/Nevermind/Nevermind.Evm/EvmMemory.cs
+++ b/src/Nevermind/Nevermind.Evm/EvmMemory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using System.IO;
 using System.Numerics;
 using Nevermind.Core.Sugar;
 
@@ -6,6 +7,8 @@ namespace Nevermind.Evm
 {
     public class EvmMemory
     {
+        private MemoryStream memory = new MemoryStream();
+
         private const int WordSize = 32;
 
         private byte[] _memory = new byte[0];
diff --git a/src/Nevermind/Nevermind.Evm/EvmState.cs b/src/Nevermind/Nevermind.Evm/EvmState.cs
index 36be43b96..74b0d5a32 100644
--- a/src/Nevermind/Nevermind.Evm/EvmState.cs
+++ b/src/Nevermind/Nevermind.Evm/EvmState.cs
@@ -1,11 +1,13 @@
 using System;
 using System.Collections.Generic;
+using System.Diagnostics;
 using System.Numerics;
 using Nevermind.Core;
 using Nevermind.Store;
 
 namespace Nevermind.Evm
 {
+    [DebuggerDisplay("{ExecutionType} to {Env.CodeOwner}, G {GasAvailable} R {Refund} PC {ProgramCounter} OUT {OutputDestination}:{OutputLength}")]
     public class EvmState
     {
         public readonly byte[][] BytesOnStack = new byte[VirtualMachine.MaxStackSize][];
@@ -15,8 +17,8 @@ namespace Nevermind.Evm
         private ulong _activeWordsInMemory;
         public int StackHead = 0;
 
-        public EvmState(ulong gasAvailable, ExecutionEnvironment env)
-            : this(gasAvailable, env, ExecutionType.TransactionLevel, null, null, BigInteger.Zero, BigInteger.Zero)
+        public EvmState(ulong gasAvailable, ExecutionEnvironment env, ExecutionType executionType)
+            : this(gasAvailable, env, executionType, null, null, BigInteger.Zero, BigInteger.Zero)
         {
             GasAvailable = gasAvailable;
             Env = env;
diff --git a/src/Nevermind/Nevermind.Evm/ExecutionType.cs b/src/Nevermind/Nevermind.Evm/ExecutionType.cs
index 6564d0a95..c0ae0b06b 100644
--- a/src/Nevermind/Nevermind.Evm/ExecutionType.cs
+++ b/src/Nevermind/Nevermind.Evm/ExecutionType.cs
@@ -1,10 +1,11 @@
 namespace Nevermind.Evm
 {
-    internal enum ExecutionType
+    public enum ExecutionType
     {
-        TransactionLevel,
+        Transaction,
         Call,
         Callcode,
-        Create
+        Create,
+        Precompile,
     }
 }
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Evm/ShouldLog.cs b/src/Nevermind/Nevermind.Evm/ShouldLog.cs
index 3399d952c..2a723c89a 100644
--- a/src/Nevermind/Nevermind.Evm/ShouldLog.cs
+++ b/src/Nevermind/Nevermind.Evm/ShouldLog.cs
@@ -2,7 +2,9 @@ namespace Nevermind.Evm
 {
     public static class ShouldLog
     {
+        public static volatile bool TransactionProcessor = true; // marked volatile to make ReSharper think it is not a const
         public static volatile bool Evm = true; // marked volatile to make ReSharper think it is not a const
+        //public const bool TransactionProcessor = false; // no volatile for performance testing
         //public const bool Evm = false; // no volatile for performance testing
     }
 }
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Evm/TransactionProcessor.cs b/src/Nevermind/Nevermind.Evm/TransactionProcessor.cs
index 9397d2894..b7d7350f1 100644
--- a/src/Nevermind/Nevermind.Evm/TransactionProcessor.cs
+++ b/src/Nevermind/Nevermind.Evm/TransactionProcessor.cs
@@ -3,7 +3,6 @@ using System.Collections.Generic;
 using System.Numerics;
 using Nevermind.Core;
 using Nevermind.Core.Encoding;
-using Nevermind.Core.Sugar;
 using Nevermind.Core.Validators;
 using Nevermind.Store;
 
@@ -56,15 +55,18 @@ namespace Nevermind.Evm
             byte[] machineCode = transaction.Init;
             byte[] data = transaction.Data ?? new byte[0];
 
-            Console.WriteLine("IS_CONTRACT_CREATION: " + transaction.IsContractCreation);
-            Console.WriteLine("IS_MESSAGE_CALL: " + transaction.IsMessageCall);
-            Console.WriteLine("IS_TRANSFER: " + transaction.IsTransfer);
-            Console.WriteLine("SENDER: " + sender);
-            Console.WriteLine("TO: " + transaction.To);
-            Console.WriteLine("GAS LIMIT: " + transaction.GasLimit);
-            Console.WriteLine("GAS PRICE: " + transaction.GasPrice);
-            Console.WriteLine("VALUE: " + transaction.Value);
-            Console.WriteLine("DATA_LENGTH: " + (transaction.Data?.Length ?? 0));
+            if (ShouldLog.TransactionProcessor)
+            {
+                Console.WriteLine("IS_CONTRACT_CREATION: " + transaction.IsContractCreation);
+                Console.WriteLine("IS_MESSAGE_CALL: " + transaction.IsMessageCall);
+                Console.WriteLine("IS_TRANSFER: " + transaction.IsTransfer);
+                Console.WriteLine("SENDER: " + sender);
+                Console.WriteLine("TO: " + transaction.To);
+                Console.WriteLine("GAS LIMIT: " + transaction.GasLimit);
+                Console.WriteLine("GAS PRICE: " + transaction.GasPrice);
+                Console.WriteLine("VALUE: " + transaction.Value);
+                Console.WriteLine("DATA_LENGTH: " + (transaction.Data?.Length ?? 0));
+            }
 
             if (sender == null)
             {
@@ -77,7 +79,7 @@ namespace Nevermind.Evm
             }
 
             ulong intrinsicGas = IntrinsicGasCalculator.Calculate(transaction, block.Number);
-            Console.WriteLine("INTRINSIC GAS: " + intrinsicGas);
+            if (ShouldLog.TransactionProcessor) Console.WriteLine("INTRINSIC GAS: " + intrinsicGas);
 
             if (intrinsicGas > block.GasLimit - blockGasUsedSoFar)
             {
@@ -125,16 +127,17 @@ namespace Nevermind.Evm
             Dictionary<Address, StateSnapshot> storageSnapshot = recipient != null ? _storageProvider.TakeSnapshot() : null;
             _stateProvider.UpdateBalance(sender, -value);
 
+            HashSet<Address> destroyedAccounts = new HashSet<Address>();
+            // TODO: can probably merge it with the inner loop in VM
             try
             {
                 if (transaction.IsContractCreation)
                 {
-                    if (ShouldLog.Evm)
+                    if (ShouldLog.TransactionProcessor)
                     {
                         Console.WriteLine("THIS IS CONTRACT CREATION");
                     }
 
-
                     if (_stateProvider.AccountExists(recipient) && !_stateProvider.IsEmptyAccount(recipient))
                     {
                         throw new TransactionCollisionException();
@@ -183,7 +186,7 @@ namespace Nevermind.Evm
                     env.MachineCode = machineCode ?? _stateProvider.GetCode(recipient);
                     env.Originator = sender;
 
-                    EvmState state = new EvmState(gasAvailable, env);
+                    EvmState state = new EvmState(gasAvailable, env, recipient.IsPrecompiled() ? ExecutionType.Precompile : ExecutionType.Transaction);
 
                     if (_protocolSpecification.IsEip170Enabled
                         && transaction.IsContractCreation
@@ -192,8 +195,6 @@ namespace Nevermind.Evm
                         throw new OutOfGasException();
                     }
 
-                    // TODO: precompiles here... !
-
                     (byte[] output, TransactionSubstate substate) = _virtualMachine.Run(state);
                     logEntries.AddRange(substate.Logs);
 
@@ -218,10 +219,11 @@ namespace Nevermind.Evm
                     // pre-final
                     gasSpent = gasLimit - gasAvailable; // TODO: does refund use intrinsic value to calculate cap?
                     BigInteger halfOfGasSpend = BigInteger.Divide(gasSpent, 2);
+
                     ulong destroyRefund = (ulong)substate.DestroyList.Count * RefundOf.Destroy;
                     BigInteger refund = BigInteger.Min(halfOfGasSpend, substate.Refund + destroyRefund);
                     BigInteger gasUnused = gasAvailable + refund;
-                    Console.WriteLine("REFUNDING UNUSED GAS OF " + gasUnused + " AND REFUND OF " + refund);
+                    if (ShouldLog.TransactionProcessor) Console.WriteLine("REFUNDING UNUSED GAS OF " + gasUnused + " AND REFUND OF " + refund);
                     _stateProvider.UpdateBalance(sender, gasUnused * gasPrice);
 
                     gasSpent -= refund;
@@ -230,26 +232,30 @@ namespace Nevermind.Evm
                     foreach (Address toBeDestroyed in substate.DestroyList)
                     {
                         _stateProvider.DeleteAccount(toBeDestroyed);
+                        destroyedAccounts.Add(toBeDestroyed);
                     }
 
                 }
             }
             catch (Exception e)
             {
-                Console.WriteLine($"  EVM EXCEPTION: {e.GetType().Name}");
+                if (ShouldLog.TransactionProcessor) Console.WriteLine($"  EVM EXCEPTION: {e.GetType().Name}");
                 _stateProvider.Restore(snapshot);
                 _storageProvider.Restore(storageSnapshot);
 
-                Console.WriteLine("GAS SPENT: " + gasSpent);
+                if (ShouldLog.TransactionProcessor) Console.WriteLine("GAS SPENT: " + gasSpent);
             }
 
-            if (!_stateProvider.AccountExists(block.Beneficiary))
-            {
-                _stateProvider.CreateAccount(block.Beneficiary, gasSpent * gasPrice);
-            }
-            else
+            if (!destroyedAccounts.Contains(block.Beneficiary))
             {
-                _stateProvider.UpdateBalance(block.Beneficiary, gasSpent * gasPrice);
+                if (!_stateProvider.AccountExists(block.Beneficiary))
+                {
+                    _stateProvider.CreateAccount(block.Beneficiary, gasSpent * gasPrice);
+                }
+                else
+                {
+                    _stateProvider.UpdateBalance(block.Beneficiary, gasSpent * gasPrice);
+                }
             }
 
             TransactionReceipt transferReceipt = new TransactionReceipt();
diff --git a/src/Nevermind/Nevermind.Evm/VirtualMachine.cs b/src/Nevermind/Nevermind.Evm/VirtualMachine.cs
index 3b59127f9..6b5599f13 100644
--- a/src/Nevermind/Nevermind.Evm/VirtualMachine.cs
+++ b/src/Nevermind/Nevermind.Evm/VirtualMachine.cs
@@ -3,6 +3,7 @@ using System.Collections;
 using System.Collections.Generic;
 using System.Numerics;
 using System.Runtime.CompilerServices;
+using System.Text;
 using Nevermind.Core;
 using Nevermind.Core.Encoding;
 using Nevermind.Core.Sugar;
@@ -84,15 +85,23 @@ namespace Nevermind.Evm
                         Console.WriteLine($"BEGIN {currentState.ExecutionType} AT DEPTH {currentState.Env.CallDepth} (at {currentState.Env.CodeOwner})");
                     }
 
-                    CallResult callResult = ExecuteCall(currentState, previousCallResult, previousCallOutput, previousCallOutputDestination);
-                    if (!callResult.IsReturn)
+                    CallResult callResult;
+                    if (currentState.ExecutionType == ExecutionType.Precompile)
                     {
-                        _stateStack.Push(currentState);
-                        currentState = callResult.StateToExecute;
-                        continue;
+                        callResult = ExecutePrecompile(currentState);
+                    }
+                    else
+                    {
+                        callResult = ExecuteCall(currentState, previousCallResult, previousCallOutput, previousCallOutputDestination);
+                        if (!callResult.IsReturn)
+                        {
+                            _stateStack.Push(currentState);
+                            currentState = callResult.StateToExecute;
+                            continue;
+                        }
                     }
 
-                    if (currentState.ExecutionType == ExecutionType.TransactionLevel)
+                    if (currentState.ExecutionType == ExecutionType.Transaction)
                     {
                         return (callResult.Output, new TransactionSubstate(currentState.Refund, currentState.DestroyList, currentState.Logs));
                     }
@@ -138,7 +147,7 @@ namespace Nevermind.Evm
 
                     if (ShouldLog.Evm)
                     {
-                        Console.WriteLine($"END {previousState.ExecutionType} AT DEPTH {previousState.Env.CallDepth} (RESULT {Hex.FromBytes(previousCallResult, true)}) RETURNS ({previousCallOutputDestination} : {Hex.FromBytes(previousCallOutput, true)})");
+                        Console.WriteLine($"END {previousState.ExecutionType} AT DEPTH {previousState.Env.CallDepth} (RESULT {Hex.FromBytes(previousCallResult ?? EmptyBytes, true)}) RETURNS ({previousCallOutputDestination} : {Hex.FromBytes(previousCallOutput, true)})");
                     }
                 }
                 catch (Exception ex) // TODO: catch EVM exceptions only
@@ -154,7 +163,7 @@ namespace Nevermind.Evm
                         _storageProvider.Restore(currentState.StorageSnapshot);
                     }
 
-                    if (currentState.ExecutionType == ExecutionType.TransactionLevel)
+                    if (currentState.ExecutionType == ExecutionType.Transaction)
                     {
                         throw;
                     }
@@ -162,7 +171,13 @@ namespace Nevermind.Evm
                     previousCallResult = BytesZero;
                     previousCallOutput = EmptyBytes;
                     previousCallOutputDestination = BigInteger.Zero;
+
+                    bool removeStipend = currentState.ExecutionType == ExecutionType.Precompile && currentState.Env.Value > 0;
                     currentState = _stateStack.Pop();
+                    if (removeStipend)
+                    {
+                        currentState.GasAvailable -= GasCostOf.CallStipend;
+                    }
                 }
             }
         }
@@ -195,6 +210,63 @@ namespace Nevermind.Evm
             gasAvailable += refund;
         }
 
+        private CallResult ExecutePrecompile(EvmState state)
+        {
+            byte[] callData = state.Env.InputData;
+            BigInteger value = state.Env.Value;
+            ulong gasAvailable = state.GasAvailable;
+
+            Address precompileAddress = state.Env.CodeOwner;
+            BigInteger addressInt = precompileAddress.Hex.ToUnsignedBigInteger();
+            ulong baseGasCost = PrecompiledContracts[addressInt].BaseGasCost();
+            ulong dataGasCost = PrecompiledContracts[addressInt].DataGasCost(callData);
+            if (gasAvailable < dataGasCost + baseGasCost)
+            {
+                throw new OutOfGasException();
+            }
+
+            // confirm this comes only after the gas checks which requires it to be handled slightly different than inside the call
+            if (!_worldStateProvider.AccountExists(state.Env.Caller))
+            {
+                _worldStateProvider.CreateAccount(state.Env.Caller, value);
+            }
+            else
+            {
+                _worldStateProvider.UpdateBalance(state.Env.Caller, value);
+            }
+
+            UpdateGas(baseGasCost, ref gasAvailable);
+            UpdateGas(dataGasCost, ref gasAvailable); // TODO: check EIP-150
+            state.GasAvailable = gasAvailable;
+
+            try
+            {
+                byte[] output = PrecompiledContracts[addressInt].Run(callData);
+                return new CallResult(output);
+
+                //state.Memory.Save(outputOffset, GetPaddedSlice(output, 0, outputLength));
+                //PushInt(BigInteger.One);
+                //if (ShouldLog.Evm) // TODO: log inside precompiled
+                //{
+                //    Console.WriteLine($"  {instruction} SUCCESS PRECOMPILED");
+                //}
+
+                //break;
+            }
+            catch (Exception)
+            {
+                return new CallResult(EmptyBytes); // TODO: check this
+
+                //PushInt(BigInteger.One);
+                //if (ShouldLog.Evm) // TODO: log inside precompiled
+                //{
+                //    Console.WriteLine($"  {instruction} FAIL PRECOMPILED");
+                //}
+
+                //break;
+            }
+        }
+
         private CallResult ExecuteCall(EvmState state, byte[] previousCallResult, byte[] previousCallOutput, BigInteger previousCallOutputDestination)
         {
             // internal state speed-ups
@@ -224,7 +296,7 @@ namespace Nevermind.Evm
                 CalculateJumpDestinations();
             }
 
-            void UpdateState()
+            void UpdateCurrentState()
             {
                 state.ProgramCounter = programCounter;
                 state.GasAvailable = gasAvailable;
@@ -492,7 +564,7 @@ namespace Nevermind.Evm
                 {
                     case Instruction.STOP:
                     {
-                        UpdateState();
+                        UpdateCurrentState();
                         return CallResult.Empty;
                     }
                     case Instruction.ADD:
@@ -937,7 +1009,7 @@ namespace Nevermind.Evm
                     {
                         UpdateGas(GasCostOf.VeryLow, ref gasAvailable);
                         BigInteger memPosition = PopUInt();
-                        UpdateMemoryCost(memPosition, 32);
+                        UpdateMemoryCost(memPosition, BigInt32);
                         byte[] memData = state.Memory.Load(memPosition);
                         PushBytes(memData);
                         break;
@@ -947,7 +1019,7 @@ namespace Nevermind.Evm
                         UpdateGas(GasCostOf.VeryLow, ref gasAvailable);
                         BigInteger memPosition = PopUInt();
                         byte[] data = PopBytes();
-                        UpdateMemoryCost(memPosition, 32);
+                        UpdateMemoryCost(memPosition, BigInt32);
                         state.Memory.SaveWord(memPosition, data);
                         break;
                     }
@@ -956,7 +1028,7 @@ namespace Nevermind.Evm
                         UpdateGas(GasCostOf.VeryLow, ref gasAvailable);
                         BigInteger memPosition = PopUInt();
                         byte[] data = PopBytes();
-                        UpdateMemoryCost(memPosition, data.Length);
+                        UpdateMemoryCost(memPosition, BigInteger.One);
                         state.Memory.SaveByte(memPosition, data);
                         break;
                     }
@@ -1256,7 +1328,7 @@ namespace Nevermind.Evm
                             storageSnapshot,
                             BigInteger.Zero,
                             BigInteger.Zero);
-                        UpdateState();
+                        UpdateCurrentState();
                         return new CallResult(callState);
                     }
                     case Instruction.RETURN:
@@ -1274,7 +1346,7 @@ namespace Nevermind.Evm
                             LogInstructionResult(instruction, gasBefore);
                         }
 
-                        UpdateState();
+                        UpdateCurrentState();
                         return new CallResult(returnData);
                     }
                     case Instruction.CALL:
@@ -1288,9 +1360,10 @@ namespace Nevermind.Evm
                         BigInteger outputOffset = PopUInt();
                         BigInteger outputLength = PopUInt();
 
-                        Address target = instruction == Instruction.CALL
-                            ? ToAddress(toAddress)
-                            : env.CodeOwner; // CALLCODE targets the current contract, CALL targets another contract
+                        // TODO: there is an inconsistency in naming below - target / code owner - will resolve it after adding DELEGATECALL
+                        Address target = instruction == Instruction.CALLCODE
+                            ? env.CodeOwner
+                            : ToAddress(toAddress); // CALLCODE targets the current contract, CALL targets another contract
                         BigInteger addressInt = toAddress.ToUnsignedBigInteger();
                         bool isPrecompile = addressInt <= 4 && addressInt > 0;
 
@@ -1345,60 +1418,30 @@ namespace Nevermind.Evm
                             _worldStateProvider.UpdateBalance(env.CodeOwner, -value); // do not subtract if failed
                         }
 
-                        // TODO: move precompiles somewhere else
+                        ExecutionEnvironment callEnv = new ExecutionEnvironment();
+                        callEnv.CallDepth = env.CallDepth + 1;
+                        callEnv.CurrentBlock = env.CurrentBlock;
+                        callEnv.GasPrice = env.GasPrice;
+                        callEnv.Originator = env.Originator;
+                        callEnv.Caller = isPrecompile ? target : env.CodeOwner;
+                        callEnv.CodeOwner = isPrecompile ? codeSource : target;
+                        callEnv.Value = value;
+                        callEnv.InputData = callData;
+                        callEnv.MachineCode = _worldStateProvider.GetCode(codeSource);
+
                         if (isPrecompile)
                         {
-                            ulong baseGasCost = PrecompiledContracts[addressInt].BaseGasCost();
-                            ulong dataGasCost = PrecompiledContracts[addressInt].DataGasCost(callData);
-                            if (gasLimit < dataGasCost + baseGasCost)
-                            {
-                                if (!value.IsZero)
-                                {
-                                    UpdateGas(GasCostOf.CallStipend, ref gasAvailable);
-                                }
-
-                                UpdateGas((ulong)gasLimit, ref gasAvailable);
-                                PushInt(BigInteger.Zero);
-
-                                _worldStateProvider.Restore(stateSnapshot);
-                                _storageProvider.Restore(storageSnapshot);
-                                break;
-                            }
-
-                            if (!_worldStateProvider.AccountExists(target))
-                            {
-                                _worldStateProvider.CreateAccount(target, value);
-                            }
-                            else
-                            {
-                                _worldStateProvider.UpdateBalance(target, value);
-                            }
-
-                            UpdateGas(baseGasCost, ref gasAvailable);
-                            UpdateGas(dataGasCost, ref gasAvailable); // TODO: check EIP-150
-
-                            try
-                            {
-                                byte[] output = PrecompiledContracts[addressInt].Run(callData);
-                                state.Memory.Save(outputOffset, GetPaddedSlice(output, 0, outputLength));
-                                PushInt(BigInteger.One);
-                                if (ShouldLog.Evm) // TODO: log inside precompiled
-                                {
-                                    Console.WriteLine($"  {instruction} SUCCESS PRECOMPILED");
-                                }
-
-                                break;
-                            }
-                            catch (Exception)
-                            {
-                                PushInt(BigInteger.One);
-                                if (ShouldLog.Evm) // TODO: log inside precompiled
-                                {
-                                    Console.WriteLine($"  {instruction} FAIL PRECOMPILED");
-                                }
-
-                                break;
-                            }
+                            EvmState precompileState = new EvmState(
+                                (ulong)gasLimit,
+                                callEnv,
+                                ExecutionType.Precompile,
+                                stateSnapshot,
+                                storageSnapshot,
+                                outputOffset,
+                                outputLength);
+                            UpdateGas((ulong)gasLimit, ref gasAvailable);
+                            UpdateCurrentState();
+                            return new CallResult(precompileState);
                         }
 
                         if (!_worldStateProvider.AccountExists(target))
@@ -1414,8 +1457,7 @@ namespace Nevermind.Evm
                         if (_protocolSpecification.IsEip150Enabled)
                         {
                             gasCap = gasExtra < gasAvailable
-                                ? Math.Min(gasAvailable - gasExtra - (gasAvailable - gasExtra) / 64,
-                                    (ulong)gasLimit)
+                                ? Math.Min(gasAvailable - gasExtra - (gasAvailable - gasExtra) / 64, (ulong)gasLimit)
                                 : (ulong)gasLimit;
                         }
                         else if (gasAvailable < gasCap)
@@ -1426,16 +1468,6 @@ namespace Nevermind.Evm
                         ulong callGas = value.IsZero ? gasCap : gasCap + GasCostOf.CallStipend;
                         UpdateGas(callGas, ref gasAvailable);
 
-                        ExecutionEnvironment callEnv = new ExecutionEnvironment();
-                        callEnv.CallDepth = env.CallDepth + 1;
-                        callEnv.CurrentBlock = env.CurrentBlock;
-                        callEnv.GasPrice = env.GasPrice;
-                        callEnv.Originator = env.Originator;
-                        callEnv.Caller = env.CodeOwner;
-                        callEnv.CodeOwner = target;
-                        callEnv.Value = value;
-                        callEnv.InputData = callData;
-                        callEnv.MachineCode = _worldStateProvider.GetCode(codeSource);
                         EvmState callState = new EvmState(
                             callGas,
                             callEnv,
@@ -1444,7 +1476,7 @@ namespace Nevermind.Evm
                             storageSnapshot,
                             outputOffset,
                             outputLength);
-                        UpdateState();
+                        UpdateCurrentState();
                         return new CallResult(callState);
                     }
                     case Instruction.INVALID:
@@ -1470,7 +1502,10 @@ namespace Nevermind.Evm
                             }
                             else
                             {
-                                _worldStateProvider.UpdateBalance(inheritor, ownerBalance);
+                                if (!inheritor.Equals(env.CodeOwner))
+                                {
+                                    _worldStateProvider.UpdateBalance(inheritor, ownerBalance);
+                                }
                             }
 
                             _worldStateProvider.UpdateBalance(env.CodeOwner, -ownerBalance);
@@ -1481,7 +1516,7 @@ namespace Nevermind.Evm
                             }
                         }
 
-                        UpdateState();
+                        UpdateCurrentState();
                         return CallResult.Empty;
                     }
                     default:
@@ -1501,7 +1536,7 @@ namespace Nevermind.Evm
                 }
             }
 
-            UpdateState();
+            UpdateCurrentState();
             return CallResult.Empty;
         }
 
diff --git a/src/Nevermind/Nevermind.Evm/WorldStateProvider.cs b/src/Nevermind/Nevermind.Evm/WorldStateProvider.cs
index d67dfc1dd..206b03e94 100644
--- a/src/Nevermind/Nevermind.Evm/WorldStateProvider.cs
+++ b/src/Nevermind/Nevermind.Evm/WorldStateProvider.cs
@@ -86,11 +86,6 @@ namespace Nevermind.Evm
         public void UpdateStorageRoot(Address address, Keccak storageRoot)
         {
             Account account = GetAccount(address);
-            if (ShouldLog.Evm)
-            {
-                Console.WriteLine($"  SETTING STORAGE ROOT of {address} from {account.StorageRoot} to {storageRoot}");
-            }
-
             account.StorageRoot = storageRoot;
             UpdateAccount(address, account);
         }
diff --git a/src/Nevermind/Nevermind.Store/KeccakOrRlp.cs b/src/Nevermind/Nevermind.Store/KeccakOrRlp.cs
index e362dcc49..a9ec2d984 100644
--- a/src/Nevermind/Nevermind.Store/KeccakOrRlp.cs
+++ b/src/Nevermind/Nevermind.Store/KeccakOrRlp.cs
@@ -32,7 +32,12 @@ namespace Nevermind.Store
 
         public Keccak GetOrComputeKeccak()
         {
-            return _keccak ?? (_keccak = Keccak.Compute(_rlp));
+            if (!IsKeccak)
+            {
+                _keccak = Keccak.Compute(_rlp);
+            }
+
+            return _keccak;
         }
 
         public Rlp GetOrEncodeRlp()
diff --git a/src/Nevermind/Nevermind.Store/PatriciaTree.cs b/src/Nevermind/Nevermind.Store/PatriciaTree.cs
index a8fb83549..3392912e3 100644
--- a/src/Nevermind/Nevermind.Store/PatriciaTree.cs
+++ b/src/Nevermind/Nevermind.Store/PatriciaTree.cs
@@ -182,7 +182,17 @@ namespace Nevermind.Store
 
         internal Node GetNode(KeccakOrRlp keccakOrRlp)
         {
-            Rlp rlp = new Rlp(keccakOrRlp.IsKeccak ? _db[keccakOrRlp.GetOrComputeKeccak()] : keccakOrRlp.Bytes);
+            Rlp rlp = null;
+            try
+            {
+
+            
+            rlp = new Rlp(keccakOrRlp.IsKeccak ? _db[keccakOrRlp.GetOrComputeKeccak()] : keccakOrRlp.Bytes);
+            }
+            catch (Exception e)
+            {
+                Console.WriteLine(e);
+            }
             return RlpDecode(rlp);
         }
 
diff --git a/src/Nevermind/Nevermind.Store/StorageTree.cs b/src/Nevermind/Nevermind.Store/StorageTree.cs
index 18592835f..54e951337 100644
--- a/src/Nevermind/Nevermind.Store/StorageTree.cs
+++ b/src/Nevermind/Nevermind.Store/StorageTree.cs
@@ -1,4 +1,5 @@
-﻿using System.Numerics;
+﻿using System.Collections.Generic;
+using System.Numerics;
 using Nevermind.Core.Encoding;
 using Nevermind.Core.Sugar;
 
@@ -6,6 +7,20 @@ namespace Nevermind.Store
 {
     public class StorageTree : PatriciaTree
     {
+        private static readonly BigInteger CacheSize = 8;
+
+        private static readonly int CacheSizeInt = (int)CacheSize;
+
+        public static readonly Dictionary<BigInteger, byte[]> Cache = new Dictionary<BigInteger, byte[]>(CacheSizeInt);
+
+        static StorageTree()
+        {
+            for (int i = 0; i < CacheSizeInt; i++)
+            {
+                Cache[i] = Keccak.Compute(new BigInteger(i).ToBigEndianByteArray(true, 32)).Bytes;
+            }
+        }
+
         public StorageTree(InMemoryDb db) : base(db)
         {
         }
@@ -20,16 +35,23 @@ namespace Nevermind.Store
 
         private byte[] GetKey(BigInteger index)
         {
+            if (index < CacheSize)
+            {
+                return Cache[index];
+            }
+
             return Keccak.Compute(index.ToBigEndianByteArray(true, 32)).Bytes;
         }
 
         public byte[] Get(BigInteger index)
         {
-            byte[] value = Get(GetKey(index));
+            byte[] key = GetKey(index);
+            byte[] value = Get(key);
             if (value == null)
             {
-                return new byte[] { 0 };
+                return new byte[] {0};
             }
+
             Rlp rlp = new Rlp(value);
             return (byte[])Rlp.Decode(rlp);
         }
diff --git a/src/Nevermind/Nevermind.sln b/src/Nevermind/Nevermind.sln
index 6b32141c8..48be5b56c 100644
--- a/src/Nevermind/Nevermind.sln
+++ b/src/Nevermind/Nevermind.sln
@@ -43,6 +43,8 @@ Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Ethereum.GeneralState.Test"
 EndProject
 Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Ethereum.Basic.Test", "Ethereum.Basic.Test\Ethereum.Basic.Test.csproj", "{6FAC611D-9CA1-4EA6-9C82-06AA10A0DA4C}"
 EndProject
+Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Nevermind.Blockchain.Test.Runner", "Nevermind.Blockchain.Test.Runner\Nevermind.Blockchain.Test.Runner.csproj", "{8413AF93-4F09-45F3-96F9-47040B56B8AF}"
+EndProject
 Global
 	GlobalSection(SolutionConfigurationPlatforms) = preSolution
 		Debug|Any CPU = Debug|Any CPU
@@ -293,6 +295,18 @@ Global
 		{6FAC611D-9CA1-4EA6-9C82-06AA10A0DA4C}.Release|x64.Build.0 = Release|Any CPU
 		{6FAC611D-9CA1-4EA6-9C82-06AA10A0DA4C}.Release|x86.ActiveCfg = Release|Any CPU
 		{6FAC611D-9CA1-4EA6-9C82-06AA10A0DA4C}.Release|x86.Build.0 = Release|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Debug|Any CPU.Build.0 = Debug|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Debug|x64.ActiveCfg = Debug|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Debug|x64.Build.0 = Debug|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Debug|x86.ActiveCfg = Debug|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Debug|x86.Build.0 = Debug|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Release|Any CPU.ActiveCfg = Release|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Release|Any CPU.Build.0 = Release|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Release|x64.ActiveCfg = Release|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Release|x64.Build.0 = Release|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Release|x86.ActiveCfg = Release|Any CPU
+		{8413AF93-4F09-45F3-96F9-47040B56B8AF}.Release|x86.Build.0 = Release|Any CPU
 	EndGlobalSection
 	GlobalSection(SolutionProperties) = preSolution
 		HideSolutionNode = FALSE
diff --git a/src/Nevermind/PerfTest/Program.cs b/src/Nevermind/PerfTest/Program.cs
index 09a88e769..69d40146f 100644
--- a/src/Nevermind/PerfTest/Program.cs
+++ b/src/Nevermind/PerfTest/Program.cs
@@ -93,6 +93,7 @@ namespace PerfTest
 
         private static void Main(string[] args)
         {
+            ShouldLog.Evm = false;
             Stopwatch stopwatch = new Stopwatch();
             stopwatch.Start();
 
@@ -125,7 +126,7 @@ namespace PerfTest
             stopwatch.Start();
             for (int i = 0; i < iterations; i++)
             {
-                Machine.Run(new EvmState(1_000_000_000L, env));
+                Machine.Run(new EvmState(1_000_000_000L, env, ExecutionType.Transaction));
             }
 
             stopwatch.Stop();
