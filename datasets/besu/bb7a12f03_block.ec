commit bb7a12f032a470320139e907b2c309c6e894745c
Author: Danno Ferrin <danno.ferrin@consensys.net>
Date:   Thu Sep 12 22:47:09 2019 -0600

    [perf] reduce header validation in Clique fast sync (#1935)
    
    Move header validations that extract the signer key out of the "light"
    validation mode.  Reduces fast sync time on goerli 75%
    Signed-off-by: Adrian Sutton <adrian.sutton@consensys.net>

diff --git a/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/CliqueDifficultyValidationRule.java b/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/CliqueDifficultyValidationRule.java
index 418609a8f..bbb04bc9f 100644
--- a/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/CliqueDifficultyValidationRule.java
+++ b/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/CliqueDifficultyValidationRule.java
@@ -41,4 +41,9 @@ public class CliqueDifficultyValidationRule
 
     return expectedDifficulty.equals(actualDifficulty);
   }
+
+  @Override
+  public boolean includeInLightValidation() {
+    return false;
+  }
 }
diff --git a/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/CliqueExtraDataValidationRule.java b/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/CliqueExtraDataValidationRule.java
index 5049fd980..1b0906ef3 100644
--- a/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/CliqueExtraDataValidationRule.java
+++ b/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/CliqueExtraDataValidationRule.java
@@ -100,4 +100,9 @@ public class CliqueExtraDataValidationRule
 
     return true;
   }
+
+  @Override
+  public boolean includeInLightValidation() {
+    return false;
+  }
 }
diff --git a/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/SignerRateLimitValidationRule.java b/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/SignerRateLimitValidationRule.java
index b0a0e5e1b..8360baa62 100644
--- a/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/SignerRateLimitValidationRule.java
+++ b/consensus/clique/src/main/java/tech/pegasys/pantheon/consensus/clique/headervalidationrules/SignerRateLimitValidationRule.java
@@ -31,4 +31,9 @@ public class SignerRateLimitValidationRule
 
     return CliqueHelpers.addressIsAllowedToProduceNextBlock(blockSigner, protocolContext, parent);
   }
+
+  @Override
+  public boolean includeInLightValidation() {
+    return false;
+  }
 }