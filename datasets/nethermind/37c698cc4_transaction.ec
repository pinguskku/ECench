commit 37c698cc48d6ab7b2f9f43a705c59bdee15835a7
Author: Marcin Sobczak <77129288+marcindsobczak@users.noreply.github.com>
Date:   Fri Jun 11 16:45:56 2021 +0100

    Tx replacement improvement (#3102)
    
    * replace tx only when new one has fee more than 10 percent higher
    
    * move logic to comparer
    
    * cosmetic
    
    * separation of const
    
    * naming, docs

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/TxPools/TxPoolTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/TxPools/TxPoolTests.cs
index 337b41b50..17416ab72 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/TxPools/TxPoolTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/TxPools/TxPoolTests.cs
@@ -874,6 +874,30 @@ namespace Nethermind.Blockchain.Test.TxPools
             _txPool.RemoveTransaction(null).Should().Be(false);
         }
 
+        [TestCase(0,0,false)]
+        [TestCase(0,1,true)]
+        [TestCase(1,2,true)]
+        [TestCase(10,11,true)]
+        [TestCase(100,0,false)]
+        [TestCase(100,80,false)]
+        [TestCase(100,109,false)]
+        [TestCase(100,110,true)]
+        [TestCase(1_000_000_000,1_099_999_999,false)]
+        [TestCase(1_000_000_000,1_100_000_000,true)]
+        public void should_replace_tx_with_same_sender_and_nonce_only_if_new_fee_is_at_least_10_percent_higher_than_old(int oldGasPrice, int newGasPrice, bool replaced)
+        {
+            _txPool = CreatePool(_noTxStorage);
+            Transaction oldTx = Build.A.Transaction.WithSenderAddress(TestItem.AddressA).WithNonce(0).WithGasPrice((UInt256)oldGasPrice).SignedAndResolved(_ethereumEcdsa, TestItem.PrivateKeyA).TestObject;
+            Transaction newTx = Build.A.Transaction.WithSenderAddress(TestItem.AddressA).WithNonce(0).WithGasPrice((UInt256)newGasPrice).SignedAndResolved(_ethereumEcdsa, TestItem.PrivateKeyA).TestObject;
+            EnsureSenderBalance(newTx.GasPrice > oldTx.GasPrice ? newTx : oldTx);
+
+            _txPool.AddTransaction(oldTx, TxHandlingOptions.PersistentBroadcast);
+            _txPool.AddTransaction(newTx, TxHandlingOptions.PersistentBroadcast);
+            
+            _txPool.GetPendingTransactions().Length.Should().Be(1);
+            _txPool.GetPendingTransactions().First().Should().BeEquivalentTo(replaced ? newTx : oldTx);
+        }
+
         private Transactions AddTransactions(ITxStorage storage)
         {
             _txPool = CreatePool(storage);
diff --git a/src/Nethermind/Nethermind.TxPool/Collections/DistinctValueSortedPool.cs b/src/Nethermind/Nethermind.TxPool/Collections/DistinctValueSortedPool.cs
index 789f4d730..e5e4127c1 100644
--- a/src/Nethermind/Nethermind.TxPool/Collections/DistinctValueSortedPool.cs
+++ b/src/Nethermind/Nethermind.TxPool/Collections/DistinctValueSortedPool.cs
@@ -47,11 +47,14 @@ namespace Nethermind.TxPool.Collections
             ILogManager logManager) 
             : base(capacity, comparer)
         {
-            _comparer = comparer ?? throw new ArgumentNullException(nameof(comparer));
+            // ReSharper disable once VirtualMemberCallInConstructor
+            _comparer = GetReplacementComparer(comparer ?? throw new ArgumentNullException(nameof(comparer)));
             _logger = logManager?.GetClassLogger() ?? throw new ArgumentNullException(nameof(logManager));
             _distinctDictionary = new Dictionary<TValue, KeyValuePair<TKey, TValue>>(distinctComparer);
         }
-        
+
+        protected virtual IComparer<TValue> GetReplacementComparer(IComparer<TValue> comparer) => comparer;
+
         protected override void InsertCore(TKey key, TValue value, ICollection<TValue> bucketCollection)
         {
             base.InsertCore(key, value, bucketCollection);
diff --git a/src/Nethermind/Nethermind.TxPool/Collections/TxDistinctSortedPool.cs b/src/Nethermind/Nethermind.TxPool/Collections/TxDistinctSortedPool.cs
index f89313fc8..f6ce08e0f 100644
--- a/src/Nethermind/Nethermind.TxPool/Collections/TxDistinctSortedPool.cs
+++ b/src/Nethermind/Nethermind.TxPool/Collections/TxDistinctSortedPool.cs
@@ -33,9 +33,10 @@ namespace Nethermind.TxPool.Collections
 
         protected override IComparer<Transaction> GetUniqueComparer(IComparer<Transaction> comparer) => comparer.GetPoolUniqueTxComparer();
         protected override IComparer<Transaction> GetGroupComparer(IComparer<Transaction> comparer) => comparer.GetPoolUniqueTxComparerByNonce();
-
-        protected override Address? MapToGroup(Transaction value) => value.MapTxToGroup();
+        protected override IComparer<Transaction> GetReplacementComparer(IComparer<Transaction> comparer) => comparer.GetReplacementComparer();
         
+        protected override Address? MapToGroup(Transaction value) => value.MapTxToGroup();
+
         [MethodImpl(MethodImplOptions.Synchronized)]
         public void UpdatePool(Func<Address, ICollection<Transaction>, IEnumerable<(Transaction Tx, Action<Transaction> Change)>> changingElements)
         {
diff --git a/src/Nethermind/Nethermind.TxPool/Collections/TxSortedPoolExtensions.cs b/src/Nethermind/Nethermind.TxPool/Collections/TxSortedPoolExtensions.cs
index fed81dde7..d9d2df81d 100644
--- a/src/Nethermind/Nethermind.TxPool/Collections/TxSortedPoolExtensions.cs
+++ b/src/Nethermind/Nethermind.TxPool/Collections/TxSortedPoolExtensions.cs
@@ -30,6 +30,9 @@ namespace Nethermind.TxPool.Collections
             => CompareTxByNonce.Instance // we need to ensure transactions are ordered by nonce, which might not be done in supplied comparer
                 .ThenBy(GetPoolUniqueTxComparer(comparer));
 
+        public static IComparer<Transaction> GetReplacementComparer(this IComparer<Transaction> comparer)
+            => CompareReplacedTxByFee.Instance.ThenBy(comparer);
+
         public static Address? MapTxToGroup(this Transaction value) => value.SenderAddress;
     }
 }
diff --git a/src/Nethermind/Nethermind.TxPool/CompareReplacedTxByFee.cs b/src/Nethermind/Nethermind.TxPool/CompareReplacedTxByFee.cs
new file mode 100644
index 000000000..cedfb5a27
--- /dev/null
+++ b/src/Nethermind/Nethermind.TxPool/CompareReplacedTxByFee.cs
@@ -0,0 +1,56 @@
+//  Copyright (c) 2021 Demerzel Solutions Limited
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
+using System.Collections.Generic;
+using Nethermind.Core;
+using Nethermind.Int256;
+
+namespace Nethermind.TxPool
+{
+    /// <summary>
+    /// Compare fee of newcomer transaction with fee of transaction intended to be replaced increased by given percent
+    /// </summary>
+    public class CompareReplacedTxByFee : IComparer<Transaction>
+    {
+        public static readonly CompareReplacedTxByFee Instance = new();
+        
+        private CompareReplacedTxByFee() { }
+        
+        // To replace old transaction, new transaction needs to have fee higher by at least 10% (1/10) of current fee.
+        // It is required to avoid acceptance and propagation of transaction with almost the same fee as replaced one.
+        private const int PartOfFeeRequiredToIncrease = 10;
+        
+        public int Compare(Transaction? x, Transaction? y)
+        {
+            if (ReferenceEquals(x, y)) return 0;
+            if (ReferenceEquals(null, y)) return 1;
+            if (ReferenceEquals(null, x)) return -1;
+            
+            // if gas bottleneck was calculated, it's highest priority for sorting
+            // if not, different method of sorting by gas price is needed
+            if (x.GasBottleneck != 0 || y.GasBottleneck != 0)
+            {
+                y.GasBottleneck.Divide(PartOfFeeRequiredToIncrease, out UInt256 bumpGasBottleneck);
+                return (y.GasBottleneck + bumpGasBottleneck).CompareTo(x.GasBottleneck);
+            }
+            
+            y.GasPrice.Divide(10, out UInt256 bumpGasPrice);
+            return (y.GasPrice + bumpGasPrice).CompareTo(x.GasPrice);
+        }
+
+    }
+}
