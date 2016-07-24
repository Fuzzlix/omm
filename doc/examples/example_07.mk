compile = rule.define {odir="tmp", base="src", cflags="-O2", type="obj",
                       action="gcc -c $OPTIONS $SOURCES -o $OUTFILE"
                      }
link    = rule.define {odir="bin", type="prog",
                       action="gcc $OPTIONS $SOURCES -o $OUTFILE"
                      }
NODE_OBJ = compile {"hello.o", src="hello.c"}
NODE_EXE = link {"hello.exe", inputs=NODE_OBJ}
