commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
commit c3b0f59b3853d9fe79eebfe725ce6072f95825db
Author: Mateusz Jędrzejewski <33068017+matilote@users.noreply.github.com>
Date:   Mon Dec 2 19:34:57 2019 +0100

    adding env variables to reduce typing when excluding unnecessary test… (#1049)
    
    * adding env variables to reduce typing when excluding unnecessary test projects
    
    * excluding DataMarketplace.Test

diff --git a/.travis.yml b/.travis.yml
index 59a792276..902b8ae74 100755
--- a/.travis.yml
+++ b/.travis.yml
@@ -3,6 +3,9 @@ mono: none
 sudo: required
 dist: bionic
 dotnet: 3.0.100
+env:
+  NETHERMIND_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Nethermind.DataMarketplace.Test]*"
+  ETHEREUM_TEST_PROJECTS="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*%2c[Ethereum.Test.Base]*"
 git:
   depth: false
   submodules: false
@@ -23,7 +26,7 @@ jobs:
       script: 
       - git submodule update --init src/Dirichlet
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Abi.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Abi.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Abi.Test;
         fi
@@ -31,7 +34,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.AuRa.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.AuRa.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.AuRa.Test; 
         fi
@@ -39,7 +42,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Blockchain.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Blockchain.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Blockchain.Test; 
         fi
@@ -47,7 +50,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Clique.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Clique.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Clique.Test;
         fi
@@ -55,7 +58,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Config.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Config.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Config.Test;
         fi
@@ -63,7 +66,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Core.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Core.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Core.Test;
         fi
@@ -76,7 +79,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Evm.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Evm.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -84,7 +87,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Facade.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Facade.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Evm.Test;
         fi
@@ -92,7 +95,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.JsonRpc.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.JsonRpc.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.JsonRpc.Test;
         fi
@@ -102,7 +105,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Mining.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Mining.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Mining.Test;
         fi
@@ -111,7 +114,7 @@ jobs:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - sudo apt-get install libsnappy-dev 
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.Network.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Network.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Network.Test;
         fi
@@ -119,7 +122,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Nethermind.Secp256k1.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Secp256k1.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Secp256k1.Test;
         fi
@@ -136,7 +139,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Runner.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Runner.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Runner.Test;
         fi
@@ -144,7 +147,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Ssz.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Ssz.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Ssz.Test;
         fi
@@ -152,7 +155,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Store.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Store.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Store.Test;
         fi
@@ -160,7 +163,7 @@ jobs:
     - script: 
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Nethermind.Wallet.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.Wallet.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.Wallet.Test;
         fi
@@ -168,7 +171,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Test;
         fi
@@ -176,7 +179,7 @@ jobs:
     - script:
       - git submodule update --init src/Dirichlet src/rocksdb-sharp
       - if [ $TRAVIS_PULL_REQUEST != false ] || [ $TRAVIS_BRANCH == "master" ]; then
-          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*%2c[Nethermind.Blockchain.Test]*" src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
+          dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$NETHERMIND_TEST_PROJECTS src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         else 
           dotnet test -c Release src/Nethermind/Nethermind.DataMarketplace.Consumers.Test;
         fi
@@ -184,47 +187,47 @@ jobs:
     - stage: Ethereum Tests
       if: branch = master OR type = pull_request
       script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Basic.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Basic.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Basic.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Blockchain.Block.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Block.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Block.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Ethereum.Test.Base]*" src/Nethermind/Ethereum.Blockchain.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && travis_wait 21 dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Blockchain.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Blockchain.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Difficulty.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Difficulty.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Difficulty.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.HexPrefix.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.HexPrefix.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.HexPrefix.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.KeyAddress.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.KeyAddress.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.KeyAddress.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.PoW.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.PoW.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.PoW.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*%2c[Nethermind.Core.Test]*" src/Nethermind/Ethereum.Rlp.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Rlp.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Rlp.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transaction.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transaction.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transaction.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Transition.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Transition.Test
       if: branch = master OR type = pull_request
       name: "Ethereum.Transition.Test"
     - script:
-      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude="[Nethermind.HashLib]*" src/Nethermind/Ethereum.Trie.Test
+      - git -c submodule."src/eth2.0-spec-tests".update=none submodule update --init && dotnet test -c Release /p:CollectCoverage=true /p:CoverletOutputFormat=opencover /p:Exclude=$ETHEREUM_TEST_PROJECTS src/Nethermind/Ethereum.Trie.Test
       - ./scripts/docker-publish.sh
       if: branch = master OR type = pull_request
       name: "Ethereum.Trie.Test"
\ No newline at end of file
