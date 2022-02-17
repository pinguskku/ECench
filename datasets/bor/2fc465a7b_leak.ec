commit 2fc465a7be6f29f75f0528d7867fe3e5f49c4e65
Merge: 111abdcfb ef227c5f4
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Fri Feb 12 15:34:35 2021 +0200

    Merge pull request #22319 from karalabe/fix-defer-leak
    
    core: fix temp memory blowup caused by defers holding on to state

