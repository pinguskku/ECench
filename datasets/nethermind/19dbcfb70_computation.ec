commit 19dbcfb7034b3fa823a34c1b86c50674017728ee
Author: Daniel Celeda <dceleda@hotmail.com>
Date:   Fri Sep 10 00:07:24 2021 +0100

    Feature/improve jumpdest analysis (#3371)
    
    * Change Jumpdest analysis implementation to bitmaps
    
    * Improvements to jumpdest analysis
    
    * Add sampling to CodeInfo jumpdest analysis
    
    * Post review changes
    
    * Tests fix

diff --git a/src/Nethermind/Nethermind.Benchmark/Evm/JumpDestinationsBenchmark.cs b/src/Nethermind/Nethermind.Benchmark/Evm/JumpDestinationsBenchmark.cs
index b7e779ba0..f226caa43 100644
--- a/src/Nethermind/Nethermind.Benchmark/Evm/JumpDestinationsBenchmark.cs
+++ b/src/Nethermind/Nethermind.Benchmark/Evm/JumpDestinationsBenchmark.cs
@@ -18,6 +18,7 @@ using BenchmarkDotNet.Attributes;
 using BenchmarkDotNet.Jobs;
 using Nethermind.Core.Extensions;
 using Nethermind.Evm;
+using Nethermind.Evm.CodeAnalysis;
 
 namespace Nethermind.Benchmarks.Evm
 {
diff --git a/src/Nethermind/Nethermind.Evm.Test/CodeAnalysis/CodeDataAnalyzerHelperTests.cs b/src/Nethermind/Nethermind.Evm.Test/CodeAnalysis/CodeDataAnalyzerHelperTests.cs
new file mode 100644
index 000000000..71a2b7f18
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm.Test/CodeAnalysis/CodeDataAnalyzerHelperTests.cs
@@ -0,0 +1,59 @@
+﻿//  Copyright (c) 2021 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
+
+using FluentAssertions;
+using Nethermind.Evm.CodeAnalysis;
+using NUnit.Framework;
+
+namespace Nethermind.Evm.Test.CodeAnalysis
+{
+    [TestFixture]
+    public class CodeDataAnalyzerHelperTests
+    {
+        [Test]
+        public void Validate_CodeBitmap_With_Push10()
+        {
+            byte[] code =
+            {
+                (byte)Instruction.PUSH10,
+                1,2,3,4,5,6,7,8,9,10,
+                (byte)Instruction.JUMPDEST
+            };
+
+            var bitmap = CodeDataAnalyzerHelper.CreateCodeBitmap(code);
+            bitmap[0].Should().Be(127);
+            bitmap[1].Should().Be(224);
+        }
+        
+        [Test]
+        public void Validate_CodeBitmap_With_Push30()
+        {
+            byte[] code =
+            {
+                (byte)Instruction.PUSH30,
+                1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,
+                (byte)Instruction.JUMPDEST
+            };
+
+            var bitmap = CodeDataAnalyzerHelper.CreateCodeBitmap(code);
+            bitmap[0].Should().Be(127);
+            bitmap[1].Should().Be(255);
+            bitmap[2].Should().Be(255);
+            bitmap[3].Should().Be(254);
+        }
+    }
+}
diff --git a/src/Nethermind/Nethermind.Evm.Test/CodeAnalysis/CodeInfoTests.cs b/src/Nethermind/Nethermind.Evm.Test/CodeAnalysis/CodeInfoTests.cs
new file mode 100644
index 000000000..653738127
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm.Test/CodeAnalysis/CodeInfoTests.cs
@@ -0,0 +1,220 @@
+﻿//  Copyright (c) 2021 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+
+using System.Linq;
+using System.Reflection;
+using FluentAssertions;
+using Nethermind.Evm.CodeAnalysis;
+using NuGet.Frameworks;
+using NUnit.Framework;
+
+namespace Nethermind.Evm.Test.CodeAnalysis
+{
+    [TestFixture]
+    public class CodeInfoTests
+    {
+        private const string AnalyzerField = "_analyzer";
+
+        [TestCase(-1, false)]
+        [TestCase(0, true)]
+        [TestCase(1, false)]
+        public void Validates_when_only_jump_dest_present(int destination, bool isValid)
+        {
+            byte[] code =
+            {
+                (byte)Instruction.JUMPDEST
+            };
+
+            CodeInfo codeInfo = new(code);
+            
+            codeInfo.ValidateJump(destination, false).Should().Be(isValid);
+        }
+        
+        [TestCase(-1, false)]
+        [TestCase(0, true)]
+        [TestCase(1, false)]
+        public void Validates_when_only_begin_sub_present(int destination, bool isValid)
+        {
+            byte[] code =
+            {
+                (byte)Instruction.BEGINSUB
+            };
+
+            CodeInfo codeInfo = new(code);
+
+
+            codeInfo.ValidateJump(destination, true).Should().Be(isValid);
+        }
+
+        [Test]
+        public void Validates_when_push_with_data_like_jump_dest()
+        {
+            byte[] code =
+            {
+                (byte)Instruction.PUSH1,
+                (byte)Instruction.JUMPDEST
+            };
+
+            CodeInfo codeInfo = new(code);
+
+            codeInfo.ValidateJump(1, true).Should().BeFalse();
+            codeInfo.ValidateJump(1, false).Should().BeFalse();
+        }
+        
+        [Test]
+        public void Validates_when_push_with_data_like_begin_sub()
+        {
+            byte[] code =
+            {
+                (byte)Instruction.PUSH1,
+                (byte)Instruction.BEGINSUB
+            };
+
+            CodeInfo codeInfo = new(code);
+
+            codeInfo.ValidateJump(1, true).Should().BeFalse();
+            codeInfo.ValidateJump(1, false).Should().BeFalse();
+        }
+        
+        [Test]
+        public void Validate_CodeBitmap_With_Push10()
+        {
+            byte[] code =
+            {
+                (byte)Instruction.PUSH10,
+                1,2,3,4,5,6,7,8,9,10,
+                (byte)Instruction.JUMPDEST
+            };
+        
+            CodeInfo codeInfo = new(code);
+            
+            codeInfo.ValidateJump(11, false).Should().BeTrue();
+        }
+        
+        [Test]
+        public void Validate_CodeBitmap_With_Push30()
+        {
+            byte[] code =
+            {
+                (byte)Instruction.PUSH30,
+                1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,
+                (byte)Instruction.JUMPDEST
+            };
+        
+            CodeInfo codeInfo = new(code);
+            
+            codeInfo.ValidateJump(31, false).Should().BeTrue();
+        }
+
+        [Test]
+        public void Small_Jumpdest_Use_CodeDataAnalyzer()
+        {
+            byte[] code =
+            {
+                0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b,0x5b
+            };
+        
+            CodeInfo codeInfo = new(code);
+            
+            codeInfo.ValidateJump(10, false).Should().BeTrue();
+            
+            FieldInfo field = typeof(CodeInfo).GetField(AnalyzerField, BindingFlags.Instance | BindingFlags.NonPublic);
+            var calc = field.GetValue(codeInfo);
+            
+            Assert.IsInstanceOf<CodeDataAnalyzer>(calc);
+        }
+        
+        [Test]
+        public void Small_Push1_Use_CodeDataAnalyzer()
+        {
+            byte[] code =
+            {
+                0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,0x60,
+            };
+        
+            CodeInfo codeInfo = new(code);
+            
+            codeInfo.ValidateJump(10, false).Should().BeFalse();
+            
+            FieldInfo field = typeof(CodeInfo).GetField(AnalyzerField, BindingFlags.Instance | BindingFlags.NonPublic);
+            var calc = field.GetValue(codeInfo);
+            
+            Assert.IsInstanceOf<CodeDataAnalyzer>(calc);
+        }
+        
+        [Test]
+        public void Jumpdest_Over10k_Use_JumpdestAnalyzer()
+        {
+            var code = Enumerable.Repeat((byte)0x5b, 10_001).ToArray();
+
+            CodeInfo codeInfo = new(code);
+            
+            codeInfo.ValidateJump(10, false).Should().BeTrue();
+            
+            FieldInfo field = typeof(CodeInfo).GetField(AnalyzerField, BindingFlags.Instance | BindingFlags.NonPublic);
+            var calc = field.GetValue(codeInfo);
+            
+            Assert.IsInstanceOf<CodeDataAnalyzer>(calc);
+        }
+        
+        [Test]
+        public void Push1_Over10k_Use_JumpdestAnalyzer()
+        {
+            var code = Enumerable.Repeat((byte)0x60, 10_001).ToArray();
+
+            CodeInfo codeInfo = new(code);
+            
+            codeInfo.ValidateJump(10, false).Should().BeFalse();
+            
+            FieldInfo field = typeof(CodeInfo).GetField(AnalyzerField, BindingFlags.Instance | BindingFlags.NonPublic);
+            var calc = field.GetValue(codeInfo);
+            
+            Assert.IsInstanceOf<JumpdestAnalyzer>(calc);
+        }
+        
+        [Test]
+        public void Push1Jumpdest_Over10k_Use_JumpdestAnalyzer()
+        {
+            byte[] code = new byte[10_001];
+            for (int i = 0; i < code.Length; i++)
+            {
+                code[i] = i % 2 == 0 ? (byte)0x60 : (byte)0x5b;
+            }
+
+            ICodeInfoAnalyzer calc = null;
+            int iterations = 1;
+            while (iterations <= 10)
+            {
+                CodeInfo codeInfo = new(code);
+
+                codeInfo.ValidateJump(10, false).Should().BeFalse();
+                codeInfo.ValidateJump(11, false).Should().BeFalse(); // 0x5b but not JUMPDEST but data
+
+                FieldInfo field = typeof(CodeInfo).GetField(AnalyzerField, BindingFlags.Instance | BindingFlags.NonPublic);
+                calc = (ICodeInfoAnalyzer)field.GetValue(codeInfo);
+
+                if (calc is JumpdestAnalyzer)
+                {
+                    break;
+                }
+
+                iterations++;
+            }
+            
+            Assert.IsInstanceOf<JumpdestAnalyzer>(calc);
+        }
+    }
+}
diff --git a/src/Nethermind/Nethermind.Evm.Test/CodeInfoTests.cs b/src/Nethermind/Nethermind.Evm.Test/CodeInfoTests.cs
deleted file mode 100644
index 9bbfcd426..000000000
--- a/src/Nethermind/Nethermind.Evm.Test/CodeInfoTests.cs
+++ /dev/null
@@ -1,86 +0,0 @@
-﻿//  Copyright (c) 2021 Demerzel Solutions Limited
-//  This file is part of the Nethermind library.
-// 
-//  The Nethermind library is free software: you can redistribute it and/or modify
-//  it under the terms of the GNU Lesser General Public License as published by
-//  the Free Software Foundation, either version 3 of the License, or
-//  (at your option) any later version.
-// 
-//  The Nethermind library is distributed in the hope that it will be useful,
-//  but WITHOUT ANY WARRANTY; without even the implied warranty of
-//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-//  GNU Lesser General Public License for more details.
-// 
-//  You should have received a copy of the GNU Lesser General Public License
-//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
-
-using FluentAssertions;
-using NUnit.Framework;
-
-namespace Nethermind.Evm.Test
-{
-    [TestFixture]
-    public class CodeInfoTests
-    {
-        [TestCase(-1, false)]
-        [TestCase(0, true)]
-        [TestCase(1, false)]
-        public void Validates_when_only_jump_dest_present(int destination, bool isValid)
-        {
-            byte[] code =
-            {
-                (byte)Instruction.JUMPDEST
-            };
-
-            CodeInfo codeInfo = new(code);
-            
-            codeInfo.ValidateJump(destination, false).Should().Be(isValid);
-        }
-        
-        [TestCase(-1, false)]
-        [TestCase(0, true)]
-        [TestCase(1, false)]
-        public void Validates_when_only_begin_sub_present(int destination, bool isValid)
-        {
-            byte[] code =
-            {
-                (byte)Instruction.BEGINSUB
-            };
-
-            CodeInfo codeInfo = new(code);
-
-
-            codeInfo.ValidateJump(destination, true).Should().Be(isValid);
-        }
-
-        [Test]
-        public void Validates_when_push_with_data_like_jump_dest()
-        {
-            byte[] code =
-            {
-                (byte)Instruction.PUSH1,
-                (byte)Instruction.JUMPDEST
-            };
-
-            CodeInfo codeInfo = new(code);
-
-            codeInfo.ValidateJump(1, true).Should().BeFalse();
-            codeInfo.ValidateJump(1, false).Should().BeFalse();
-        }
-        
-        [Test]
-        public void Validates_when_push_with_data_like_begin_sub()
-        {
-            byte[] code =
-            {
-                (byte)Instruction.PUSH1,
-                (byte)Instruction.BEGINSUB
-            };
-
-            CodeInfo codeInfo = new(code);
-
-            codeInfo.ValidateJump(1, true).Should().BeFalse();
-            codeInfo.ValidateJump(1, false).Should().BeFalse();
-        }
-    }
-}
diff --git a/src/Nethermind/Nethermind.Evm/CodeAnalysis/CodeDataAnalyzer.cs b/src/Nethermind/Nethermind.Evm/CodeAnalysis/CodeDataAnalyzer.cs
new file mode 100644
index 000000000..29a9f8513
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeAnalysis/CodeDataAnalyzer.cs
@@ -0,0 +1,185 @@
+﻿//  Copyright (c) 2021 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
+
+using System;
+using System.Threading;
+
+namespace Nethermind.Evm.CodeAnalysis
+{
+    public class CodeDataAnalyzer : ICodeInfoAnalyzer
+    {
+        private byte[]? _codeBitmap;
+        public byte[] MachineCode { get; set; }
+
+        public CodeDataAnalyzer(byte[] code)
+        {
+            MachineCode = code;
+        }
+
+        public bool ValidateJump(int destination, bool isSubroutine)
+        {
+            _codeBitmap ??= CodeDataAnalyzerHelper.CreateCodeBitmap(MachineCode);
+
+            if (destination < 0 || destination >= MachineCode.Length)
+            {
+                return false;
+            }
+
+            if (!CodeDataAnalyzerHelper.IsCodeSegment(_codeBitmap, destination))
+            {
+                return false;
+            }
+
+            if (isSubroutine)
+            {
+                return MachineCode[destination] == 0x5c;
+            }
+
+            return MachineCode[destination] == 0x5b;
+        }
+    }
+
+    public static class CodeDataAnalyzerHelper
+    {
+        private const UInt16 Set2BitsMask = 0b1100_0000_0000_0000;
+        private const UInt16 Set3BitsMask = 0b1110_0000_0000_0000;
+        private const UInt16 Set4BitsMask = 0b1111_0000_0000_0000;
+        private const UInt16 Set5BitsMask = 0b1111_1000_0000_0000;
+        private const UInt16 Set6BitsMask = 0b1111_1100_0000_0000;
+        private const UInt16 Set7BitsMask = 0b1111_1110_0000_0000;
+
+        private static readonly byte[] _lookup = new byte[8] { 0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1, };
+
+        /// <summary>
+        /// Collects data locations in code.
+        /// An unset bit means the byte is an opcode, a set bit means it's data.
+        /// </summary>
+        public static byte[] CreateCodeBitmap(byte[] code)
+        {
+            // The bitmap is 4 bytes longer than necessary, in case the code
+            // ends with a PUSH32, the algorithm will push zeroes onto the
+            // bitvector outside the bounds of the actual code.
+            byte[] bitvec = new byte[(code.Length / 8) + 1 + 4];
+
+            byte push1 = 0x60;
+            byte push32 = 0x7f;
+
+            for (int pc = 0; pc < code.Length;)
+            {
+                byte op = code[pc];
+                pc++;
+
+                if (op < push1 || op > push32)
+                {
+                    continue;
+                }
+
+                int numbits = op - push1 + 1;
+
+                if (numbits >= 8)
+                {
+                    for (; numbits >= 16; numbits -= 16)
+                    {
+                        bitvec.Set16(pc);
+                        pc += 16;
+                    }
+
+                    for (; numbits >= 8; numbits -= 8)
+                    {
+                        bitvec.Set8(pc);
+                        pc += 8;
+                    }
+                }
+
+                switch (numbits)
+                {
+                    case 1:
+                        bitvec.Set1(pc);
+                        pc += 1;
+                        break;
+                    case 2:
+                        bitvec.SetN(pc, Set2BitsMask);
+                        pc += 2;
+                        break;
+                    case 3:
+                        bitvec.SetN(pc, Set3BitsMask);
+                        pc += 3;
+                        break;
+                    case 4:
+                        bitvec.SetN(pc, Set4BitsMask);
+                        pc += 4;
+                        break;
+                    case 5:
+                        bitvec.SetN(pc, Set5BitsMask);
+                        pc += 5;
+                        break;
+                    case 6:
+                        bitvec.SetN(pc, Set6BitsMask);
+                        pc += 6;
+                        break;
+                    case 7:
+                        bitvec.SetN(pc, Set7BitsMask);
+                        pc += 7;
+                        break;
+                }
+            }
+
+            return bitvec;
+        }
+
+        /// <summary>
+        /// Checks if the position is in a code segment.
+        /// </summary>
+        public static bool IsCodeSegment(byte[] bitvec, int pos)
+        {
+            return (bitvec[pos / 8] & (0x80 >> (pos % 8))) == 0;
+        }
+
+        private static void Set1(this byte[] bitvec, int pos)
+        {
+            bitvec[pos / 8] |= _lookup[pos % 8];
+        }
+
+        private static void SetN(this byte[] bitvec, int pos, UInt16 flag)
+        {
+            ushort a = (ushort)(flag >> (pos % 8));
+            bitvec[pos / 8] |= (byte)(a >> 8);
+            byte b = (byte)a;
+            if (b != 0)
+            {
+                //	If the bit-setting affects the neighbouring byte, we can assign - no need to OR it,
+                //	since it's the first write to that byte
+                bitvec[pos / 8 + 1] = b;
+            }
+        }
+
+        private static void Set8(this byte[] bitvec, int pos)
+        {
+            byte a = (byte)(0xFF >> (pos % 8));
+            bitvec[pos / 8] |= a;
+            bitvec[pos / 8 + 1] = (byte)~a;
+        }
+
+        private static void Set16(this byte[] bitvec, int pos)
+        {
+            byte a = (byte)(0xFF >> (pos % 8));
+            bitvec[pos / 8] |= a;
+            bitvec[pos / 8 + 1] = 0xFF;
+            bitvec[pos / 8 + 2] = (byte)~a;
+        }
+    }
+}
diff --git a/src/Nethermind/Nethermind.Evm/CodeAnalysis/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeAnalysis/CodeInfo.cs
new file mode 100644
index 000000000..aa84df92b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeAnalysis/CodeInfo.cs
@@ -0,0 +1,92 @@
+﻿//  Copyright (c) 2021 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+
+using System;
+using System.Collections;
+using System.Reflection.PortableExecutable;
+using System.Threading;
+using Nethermind.Evm.Precompiles;
+
+namespace Nethermind.Evm.CodeAnalysis
+{
+    public class CodeInfo
+    {
+        private const int SampledCodeLength = 10_001;
+        private const int PercentageOfPush1 = 40;
+        private const int NumberOfSamples = 100;
+        private static Random _rand = new();
+        
+        public byte[] MachineCode { get; set; }
+        public IPrecompile? Precompile { get; set; }
+        private ICodeInfoAnalyzer? _analyzer;
+
+        public CodeInfo(byte[] code)
+        {
+            MachineCode = code;
+        }
+
+        public bool IsPrecompile => Precompile != null;
+        
+        public CodeInfo(IPrecompile precompile)
+        {
+            Precompile = precompile;
+            MachineCode = Array.Empty<byte>();
+        }
+
+        public bool ValidateJump(int destination, bool isSubroutine)
+        {
+            if (_analyzer == null)
+            {
+                CreateAnalyzer();
+            }
+
+            return _analyzer.ValidateJump(destination, isSubroutine);
+        }
+        
+        /// <summary>
+        /// Do sampling to choose an algo when the code is big enough.
+        /// When the code size is small we can use the default analyzer.
+        /// </summary>
+        private void CreateAnalyzer()
+        {
+            if (MachineCode.Length >= SampledCodeLength)
+            {
+                byte push1Count = 0;
+
+                // we check (by sampling randomly) how many PUSH1 instructions are in the code
+                for (int i = 0; i < NumberOfSamples; i++)
+                {
+                    byte instruction = MachineCode[_rand.Next(0, MachineCode.Length)];
+
+                    // PUSH1
+                    if (instruction == 0x60)
+                    {
+                        push1Count++;
+                    }
+                }
+
+                // If there are many PUSH1 ops then use the JUMPDEST analyzer.
+                // The JumpdestAnalyzer can perform up to 40% better than the default Code Data Analyzer
+                // in a scenario when the code consists only of PUSH1 instructions.
+                _analyzer = push1Count > PercentageOfPush1 ? new JumpdestAnalyzer(MachineCode) : new CodeDataAnalyzer(MachineCode);
+            }
+            else
+            {
+                _analyzer = new CodeDataAnalyzer(MachineCode);
+            }
+        }
+    }
+}
diff --git a/src/Nethermind/Nethermind.Evm/CodeAnalysis/ICodeInfoAnalyzer.cs b/src/Nethermind/Nethermind.Evm/CodeAnalysis/ICodeInfoAnalyzer.cs
new file mode 100644
index 000000000..679e030f6
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm/CodeAnalysis/ICodeInfoAnalyzer.cs
@@ -0,0 +1,24 @@
+﻿//  Copyright (c) 2021 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
+
+namespace Nethermind.Evm.CodeAnalysis
+{
+    public interface ICodeInfoAnalyzer
+    {
+        bool ValidateJump(int destination, bool isSubroutine);
+    }
+}
diff --git a/src/Nethermind/Nethermind.Evm/CodeInfo.cs b/src/Nethermind/Nethermind.Evm/CodeAnalysis/JumpdestAnalyzer.cs
similarity index 70%
rename from src/Nethermind/Nethermind.Evm/CodeInfo.cs
rename to src/Nethermind/Nethermind.Evm/CodeAnalysis/JumpdestAnalyzer.cs
index 56b28bab6..37d74696b 100644
--- a/src/Nethermind/Nethermind.Evm/CodeInfo.cs
+++ b/src/Nethermind/Nethermind.Evm/CodeAnalysis/JumpdestAnalyzer.cs
@@ -13,42 +13,34 @@
 // 
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
 
-using System;
 using System.Collections;
+using System.Threading;
 using Nethermind.Evm.Precompiles;
 
-namespace Nethermind.Evm
+namespace Nethermind.Evm.CodeAnalysis
 {
-    public class CodeInfo
+    public class JumpdestAnalyzer : ICodeInfoAnalyzer
     {
-        private BitArray _validJumpDestinations;
-        private BitArray _validJumpSubDestinations;
+        private byte[] MachineCode { get; set; }
 
-        public CodeInfo(byte[] code)
-        {
-            MachineCode = code;
-        }
+        private BitArray? _validJumpDestinations;
+        private BitArray? _validJumpSubDestinations;
 
-        public bool IsPrecompile => Precompile != null;
-        
-        public CodeInfo(IPrecompile precompile)
+        public JumpdestAnalyzer(byte[] code)
         {
-            Precompile = precompile;
-            MachineCode = Array.Empty<byte>();
+            MachineCode = code;
         }
-        
-        public byte[] MachineCode { get; set; }
-        public IPrecompile Precompile { get; set; }
-
+    
         public bool ValidateJump(int destination, bool isSubroutine)
         {
             if (_validJumpDestinations is null)
             {
                 CalculateJumpDestinations();
             }
-
-            if (destination < 0 || destination >= MachineCode.Length ||
+            
+            if (destination < 0 || destination >= _validJumpDestinations.Length ||
                 (isSubroutine ? !_validJumpSubDestinations.Get(destination) : !_validJumpDestinations.Get(destination)))
             {
                 return false;
@@ -56,30 +48,29 @@ namespace Nethermind.Evm
 
             return true;
         }
-      
+
         private void CalculateJumpDestinations()
         {
             _validJumpDestinations = new BitArray(MachineCode.Length);
             _validJumpSubDestinations = new BitArray(MachineCode.Length);
-            
+
             int index = 0;
             while (index < MachineCode.Length)
             {
-                //Instruction instruction = (Instruction)code[index];
-                byte instruction = MachineCode[index];                
-                
-                //if (instruction == Instruction.JUMPDEST
+                byte instruction = MachineCode[index];
+
+                // JUMPDEST
                 if (instruction == 0x5b)
                 {
                     _validJumpDestinations.Set(index, true);
                 }
-                //if (instruction == Instruction.BEGINSUB
+                // BEGINSUB
                 else if (instruction == 0x5c)
                 {
                     _validJumpSubDestinations.Set(index, true);
                 }
-                //if (instruction >= Instruction.PUSH1 && instruction <= Instruction.PUSH32)
                 
+                // instruction >= Instruction.PUSH1 && instruction <= Instruction.PUSH32
                 if (instruction >= 0x60 && instruction <= 0x7f)
                 {
                     //index += instruction - Instruction.PUSH1 + 2;
diff --git a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
index 1c516500f..73215bb7e 100644
--- a/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
+++ b/src/Nethermind/Nethermind.Evm/ExecutionEnvironment.cs
@@ -16,6 +16,7 @@
 
 using System;
 using Nethermind.Core;
+using Nethermind.Evm.CodeAnalysis;
 using Nethermind.Int256;
 
 namespace Nethermind.Evm
diff --git a/src/Nethermind/Nethermind.Evm/IVirtualMachine.cs b/src/Nethermind/Nethermind.Evm/IVirtualMachine.cs
index 60436dda7..3d082e26b 100644
--- a/src/Nethermind/Nethermind.Evm/IVirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/IVirtualMachine.cs
@@ -16,6 +16,7 @@
 
 using Nethermind.Core;
 using Nethermind.Core.Specs;
+using Nethermind.Evm.CodeAnalysis;
 using Nethermind.Evm.Tracing;
 
 namespace Nethermind.Evm
diff --git a/src/Nethermind/Nethermind.Evm/TransactionProcessing/TransactionProcessor.cs b/src/Nethermind/Nethermind.Evm/TransactionProcessing/TransactionProcessor.cs
index a53347035..cfbc8e182 100644
--- a/src/Nethermind/Nethermind.Evm/TransactionProcessing/TransactionProcessor.cs
+++ b/src/Nethermind/Nethermind.Evm/TransactionProcessing/TransactionProcessor.cs
@@ -21,6 +21,7 @@ using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Specs;
 using Nethermind.Crypto;
+using Nethermind.Evm.CodeAnalysis;
 using Nethermind.Evm.Tracing;
 using Nethermind.Int256;
 using Nethermind.Logging;
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index f10b62698..66724fc2e 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -25,6 +25,7 @@ using Nethermind.Core.Caching;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Extensions;
 using Nethermind.Core.Specs;
+using Nethermind.Evm.CodeAnalysis;
 using Nethermind.Int256;
 using Nethermind.Evm.Precompiles;
 using Nethermind.Evm.Precompiles.Bls.Shamatar;
