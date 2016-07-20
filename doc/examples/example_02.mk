NODE = rule {"hello.exe", src="hello.c", cflags="-O2 -s", action="gcc $OPTIONS $SOURCES -o $OUTFILE"}
default(NODE)
