commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
