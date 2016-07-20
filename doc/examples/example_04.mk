local CFLAGS = "-O2 -s"
local PROG   = "gcc"
local CMDLN  = "$PROG $OPTIONS $SOURCES -o $OUTFILE"
--
NODE = rule {"hello.exe", 
             src="hello.c", odir="bin", cflags=CFLAGS, prog=PROG, action=CMDLN}
default(NODE)
