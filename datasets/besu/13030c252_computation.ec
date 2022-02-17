commit 13030c252532b6aa367059f77c217baeedbc4cf8
Author: Stefan Pingel <16143240+pinges@users.noreply.github.com>
Date:   Thu Aug 20 16:35:05 2020 +1000

    remove unnecessary method call (#1323)
    
    Signed-off-by: Stefan Pingel <stefan.pingel@consensys.net>

diff --git a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/privacy/DefaultPrivacyController.java b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/privacy/DefaultPrivacyController.java
index 9edc8591b..f0c1974ce 100644
--- a/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/privacy/DefaultPrivacyController.java
+++ b/ethereum/core/src/main/java/org/hyperledger/besu/ethereum/privacy/DefaultPrivacyController.java
@@ -534,7 +534,7 @@ public class DefaultPrivacyController implements PrivacyController {
   public void verifyPrivacyGroupContainsEnclavePublicKey(
       final String privacyGroupId, final String enclavePublicKey, final Optional<Long> blockNumber)
       throws MultiTenancyValidationException {
-    verifyPrivacyGroupContainsEnclavePublicKey(privacyGroupId, enclavePublicKey);
+    // NO VALIDATION NEEDED
   }
 
   @Override
