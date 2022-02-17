commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
