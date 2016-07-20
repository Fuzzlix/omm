local CFLAGS     = "-O2 -s"
local PROG       = "gcc"
local CMDCOMPILE = "$PROG -c $OPTIONS $SOURCES -o $OUTFILE"
local CMDLINK    = "$PROG $OPTIONS $SOURCES -o $OUTFILE"
--
NODE_OBJ  = rule {"hello.obj",
                  src="hello.c", odir="tmp", base="src", cflags=CFLAGS, prog=PROG, action=CMDCOMPILE}
NODE_EXE  = rule {"hello.exe", 
                  inputs=NODE_OBJ, odir="bin", cflags=CFLAGS, prog=PROG, action=CMDLINK}
default(NODE_EXE)
