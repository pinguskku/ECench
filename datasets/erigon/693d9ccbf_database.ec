commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
