NODE_OBJ = cc.group {src="hello", odir="tmp", base="src"}
NODE_EXE = cc.program {"hello", inputs=NODE_OBJ, odir="bin"}
default(NODE_EXE)
