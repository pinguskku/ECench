commit bd848aad7c4e1f7d1eaecd9ea7ee23785090768a
Author: Li, Cheng <lob4tt@gmail.com>
Date:   Tue Dec 8 13:19:09 2020 -0500

    common: improve printing of Hash and Address (#21834)
    
    Both Hash and Address have a String method, which returns the value as
    hex with 0x prefix. They also had a Format method which tried to print
    the value using printf of []byte. The way Format worked was at odds with
    String though, leading to a situation where fmt.Sprintf("%v", hash)
    returned the decimal notation and hash.String() returned a hex string.
    
