commit 3cd30d5fb95f2f3a7a9eb4cc6211fc0f3fb093eb
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Mon Nov 13 15:57:36 2017 +0000

    codecopy, memorystress, returndata - with questionable performance on jumps - work in progress

diff --git a/src/Nevermind/Ethereum.Blockchain.Test/CodeCopyTests.cs b/src/Nevermind/Ethereum.Blockchain.Test/CodeCopyTests.cs
new file mode 100644
index 000000000..674768ae8
--- /dev/null
+++ b/src/Nevermind/Ethereum.Blockchain.Test/CodeCopyTests.cs
@@ -0,0 +1,14 @@
+﻿using NUnit.Framework;
+
+namespace Ethereum.Blockchain.Test
+{
+    [TestFixture]
+    public class CodeCopyTests : BlockchainTestBase
+    {
+        [TestCaseSource(nameof(LoadTests), new object[] { "CodeCopyTest" })]
+        public void Test(BlockchainTest generateStateTest)
+        {
+            RunTest(generateStateTest);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.csproj b/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.csproj
index 469be88dd..80f80019c 100644
--- a/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.csproj
+++ b/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.csproj
@@ -39,6 +39,24 @@
       <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
     </EmbeddedResource>
   </ItemGroup>
+  <ItemGroup>
+    <EmbeddedResource Include="..\..\tests\BlockchainTests\GeneralStateTests\stReturnDataTest*\*.*">
+      <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
+      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
+    </EmbeddedResource>
+  </ItemGroup>
+  <ItemGroup>
+    <EmbeddedResource Include="..\..\tests\BlockchainTests\GeneralStateTests\stMemoryStressTest*\*.*">
+      <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
+      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
+    </EmbeddedResource>
+  </ItemGroup>
+  <ItemGroup>
+    <EmbeddedResource Include="..\..\tests\BlockchainTests\GeneralStateTests\stCodeCopy*\*.*">
+      <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
+      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
+    </EmbeddedResource>
+  </ItemGroup>
   <ItemGroup>
     <EmbeddedResource Include="..\..\tests\BlockchainTests\GeneralStateTests\stCreate*\*.*">
       <Link>%(RecursiveDir)%(FileName)%(Extension)</Link>
@@ -127,11 +145,14 @@
   </ItemGroup>
   <ItemGroup>
     <Compile Include="CallCreateCallCodeTests.cs" />
+    <Compile Include="CodeCopyTests.cs" />
     <Compile Include="InitCodeTests.cs" />
     <Compile Include="ExampleTests.cs" />
     <Compile Include="CallCodeTests.cs" />
+    <Compile Include="MemoryStressTests.cs" />
     <Compile Include="MemoryTests.cs" />
     <Compile Include="RefundTests.cs" />
+    <Compile Include="ReturnDataTests.cs" />
     <Compile Include="StaticCallTests.cs" />
     <Compile Include="Properties\AssemblyInfo.cs" />
     <Compile Include="BlockchainTestBase.cs" />
diff --git a/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.v3.ncrunchproject b/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.v3.ncrunchproject
index d93250bd6..b572a7027 100644
--- a/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.v3.ncrunchproject
+++ b/src/Nevermind/Ethereum.Blockchain.Test/Ethereum.Blockchain.Test.v3.ncrunchproject
@@ -4,11 +4,53 @@
       <FixtureTestSelector>
         <FixtureName>Ethereum.Blockchain.Test.LogTests</FixtureName>
       </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.Random2Tests</FixtureName>
+      </FixtureTestSelector>
+      <NamedTestSelector>
+        <TestName>Ethereum.Blockchain.Test.RandomTests.Test(randomStatetest307_d0g0v0_Frontier)</TestName>
+      </NamedTestSelector>
       <FixtureTestSelector>
         <FixtureName>Ethereum.Blockchain.Test.RandomTests</FixtureName>
       </FixtureTestSelector>
       <FixtureTestSelector>
-        <FixtureName>Ethereum.Blockchain.Test.Random2Tests</FixtureName>
+        <FixtureName>Ethereum.Blockchain.Test.ZeroCallsTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.ZeroCallsRevertTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.StaticCallTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.ReturnDataTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.RefundTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.StackTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.MemoryTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.MemoryStressTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.InitCodeTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CreateTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CodeCopyTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CallCreateCallCodeTests</FixtureName>
+      </FixtureTestSelector>
+      <FixtureTestSelector>
+        <FixtureName>Ethereum.Blockchain.Test.CallCodeTests</FixtureName>
       </FixtureTestSelector>
     </IgnoredTests>
   </Settings>
diff --git a/src/Nevermind/Ethereum.Blockchain.Test/MemoryStressTests.cs b/src/Nevermind/Ethereum.Blockchain.Test/MemoryStressTests.cs
new file mode 100644
index 000000000..38ed1c60b
--- /dev/null
+++ b/src/Nevermind/Ethereum.Blockchain.Test/MemoryStressTests.cs
@@ -0,0 +1,14 @@
+﻿using NUnit.Framework;
+
+namespace Ethereum.Blockchain.Test
+{
+    [TestFixture]
+    public class MemoryStressTests : BlockchainTestBase
+    {
+        [TestCaseSource(nameof(LoadTests), new object[] { "MemoryStressTest" })]
+        public void Test(BlockchainTest generateStateTest)
+        {
+            RunTest(generateStateTest);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nevermind/Ethereum.Blockchain.Test/ReturnDataTests.cs b/src/Nevermind/Ethereum.Blockchain.Test/ReturnDataTests.cs
new file mode 100644
index 000000000..e6b02bb3d
--- /dev/null
+++ b/src/Nevermind/Ethereum.Blockchain.Test/ReturnDataTests.cs
@@ -0,0 +1,14 @@
+﻿using NUnit.Framework;
+
+namespace Ethereum.Blockchain.Test
+{
+    [TestFixture]
+    public class ReturnDataTests : BlockchainTestBase
+    {
+        [TestCaseSource(nameof(LoadTests), new object[] { "ReturnDataTest" })]
+        public void Test(BlockchainTest generateStateTest)
+        {
+            RunTest(generateStateTest);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Evm/ShouldLog.cs b/src/Nevermind/Nevermind.Evm/ShouldLog.cs
index 3399d952c..58605c900 100644
--- a/src/Nevermind/Nevermind.Evm/ShouldLog.cs
+++ b/src/Nevermind/Nevermind.Evm/ShouldLog.cs
@@ -2,7 +2,7 @@ namespace Nevermind.Evm
 {
     public static class ShouldLog
     {
-        public static volatile bool Evm = true; // marked volatile to make ReSharper think it is not a const
-        //public const bool Evm = false; // no volatile for performance testing
+        //public static volatile bool Evm = true; // marked volatile to make ReSharper think it is not a const
+        public const bool Evm = false; // no volatile for performance testing
     }
 }
\ No newline at end of file
diff --git a/src/Nevermind/Nevermind.Evm/VirtualMachine.cs b/src/Nevermind/Nevermind.Evm/VirtualMachine.cs
index c9f78bf5c..57befb85e 100644
--- a/src/Nevermind/Nevermind.Evm/VirtualMachine.cs
+++ b/src/Nevermind/Nevermind.Evm/VirtualMachine.cs
@@ -1011,20 +1011,20 @@ namespace Nevermind.Evm
                     case Instruction.JUMP:
                     {
                         UpdateGas(GasCostOf.Mid, ref gasAvailable);
-                        BigInteger dest = PopUInt();
-                        ValidateJump((int)dest);
-                        programCounter = (long)dest;
+                        int dest = (int)PopUInt();
+                        ValidateJump(dest);
+                        programCounter = dest;
                         break;
                     }
                     case Instruction.JUMPI:
                     {
                         UpdateGas(GasCostOf.High, ref gasAvailable);
-                        BigInteger dest = PopUInt();
+                        int dest = (int)PopUInt();
                         BigInteger condition = PopUInt();
                         if (condition > BigInteger.Zero)
                         {
-                            ValidateJump((int)dest);
-                            programCounter = (long)dest;
+                            ValidateJump(dest);
+                            programCounter = dest;
                         }
 
                         break;
