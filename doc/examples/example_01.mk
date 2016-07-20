NODE = rule {"hello.exe", src="hello.c", action="gcc $SOURCES -o $OUTFILE"}
default(NODE)
