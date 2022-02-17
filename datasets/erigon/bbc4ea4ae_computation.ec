commit bbc4ea4ae8e8a962deae3d5693d9d4a9376eab88
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Thu Jan 5 11:52:10 2017 +0100

    core/vm: improved EVM run loop & instruction calling (#3378)
    
    The run loop, which previously contained custom opcode executes have been
    removed and has been simplified to a few checks.
    
    Each operation consists of 4 elements: execution function, gas cost function,
    stack validation function and memory size function. The execution function
    implements the operation's runtime behaviour, the gas cost function implements
    the operation gas costs function and greatly depends on the memory and stack,
    the stack validation function validates the stack and makes sure that enough
    items can be popped off and pushed on and the memory size function calculates
    the memory required for the operation and returns it.
    
