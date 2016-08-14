Title:	OMM manual
Author:	Ulrich Schmidt
CSS:		omm.css
....
			
# Makefiles

Makefiles are lua scripts running a a special lua environment supplying usefull functions and informations.

## First steps (Nodes and Rules)

Makefiles define the relationship between source files and generated files. Internally all informations 
for files are stored in so called _nodes_, defining the file name, a command to build the file, all kind of parameters 
needed to build the file and relations to files/_nodes_ the _node_ depends on.

The most native way to define a _node_ is the `rule` tool. To compile a c source to a executable using the 
gnu compiler collection, you may define the following rule in your makefile.

```lua
-- example_01.mk
NODE = rule {"hello.exe", 
             src="hello.c", 
             action="gcc $SOURCES -o $OUTFILE"
            }
default(NODE)
```
The rule() line creates 2 nodes, one node for the target file "hello.exe" and one node behind the scene for the source file "hello.c". 
To generate/compile the target file, the command line given in the `"action"` parameter becomes executed. 
As you can see, you can use a set of $-variables in the command line. In this example the $SOURCES variable becomes 
substituted by "hello.c" and $OUTFILE by "hello.exe". The gnu c compiler `gcc` is hard coded in the commandline.
The `default()` command defines the node, where to start calculating the build order. 

---

In most cases it is needed to provide aditional parameters in the command line. For instance we want to 
specify optimization options and more. It is usual to provide those compiler switches in a variable or 
parameter named `cflags`. Those cflags (and some other options) will substitute the `$OPTIONS` command line variable.

```lua
-- example_02.mk
NODE = rule {"hello.exe", 
             src="hello.c", 
             cflags="-O2 -s", 
             action="gcc $OPTIONS $SOURCES -o $OUTFILE"
            }
default(NODE) 
```

---

The program to call can also be given by a `prog` parameter. This parameter can be a string 
containing any valid executable name or a _node_ defined earlier.

```lua
-- example_03.mk
CFLAGS = "-O2 -s"
PROG   = "gcc"
CMDLN  = "$PROG $OPTIONS $SOURCES -o $OUTFILE"
--
NODE = rule {"hello.exe", 
             src="hello.c", cflags=CFLAGS, prog=PROG, action=CMDLN}
default(NODE)
```

---

Until now we used filenames without paths. But source files are not allway stored 
in one folder and generated files are usually not stored in the same folder as the sources.
By default all file names are relative to the makefile location. In the previous examples 
the sources are located in the same folder as the makefile and the generated files went 
into this folder too.

In the next example we store the generated executable in a `bin/` subfolder. To do so, we define 
a parameter `"odir"`. The odir parameter in the next example is a relative path and this means 
this path is relative to the makefile location. It is possible to use absolute paths for `"odir"`.
All directories needed will be created automatically.

```lua
-- example_04.mk
CFLAGS = "-O2 -s"
PROG   = "gcc"
CMDLN  = "$PROG $OPTIONS $SOURCES -o $OUTFILE"
--
NODE = rule {"hello.exe", 
             src="hello.c", odir="bin", cflags=CFLAGS, prog=PROG, action=CMDLN}
default(NODE)
```

---

Sources may be found in a different folder than the makefile. To avoid writing long paths for each sourcefile, 
it is possible to define a `"base"` parameter. This parameter defines a relative or absolute path where the 
source files given in the src parameter are located.  
Site note: When writing makefiles, use slashes in paths, even on Windows! Slashes will be automatically 
converted to backslashes for Windows command lines.

```lua
-- example_05.mk
CFLAGS = "-O2 -s"
PROG   = "gcc"
CMDLN  = "$PROG $OPTIONS $SOURCES -o $OUTFILE"
--
NODE = rule {"hello.exe", 
             src="hello.c", odir="bin", base="src", cflags=CFLAGS, prog=PROG, action=CMDLN}
default(NODE)
```

---

In previous examples the c source was compiled directly to a executable. In large projects it is usual to
compile each source to a object file and finally link all object files to a executable or library.
The next example compiles the c source to a objectfile and stores the build rule for the object file in `NODE_OBJ`.
`NODE_OBJ` is a _node_ and can't be handed over to `NODE_EXE` as a `"src"` parameter. To define _nodes_ as sources, 
we use the `"inputs"` parameter. Both `"src"` and `"inputs"` can be used at the same time and substitute the `$SOURCES` 
command line variable.

```lua
-- example_06.mk
CFLAGS     = "-O2 -s"
PROG       = "gcc"
CMDCOMPILE = "$PROG -c $OPTIONS $SOURCES -o $OUTFILE"
CMDLINK    = "$PROG $OPTIONS $SOURCES -o $OUTFILE"
--
NODE_OBJ = rule {"hello.o",
                 src="hello.c", odir="tmp", base="src", cflags=CFLAGS, prog=PROG, action=CMDCOMPILE}
NODE_EXE = rule {"hello.exe", 
                 inputs=NODE_OBJ, odir="bin", cflags=CFLAGS, prog=PROG, action=CMDLINK}
default(NODE_EXE)
```

As you can imagine, writing makefiles for huge projects in this way results in much writing effort 
and is not comfortable. Therefore the are handy tools ready to allow simpler makefile syntax. 

The first one is the `rule.define()` _action_[^action]. This one creates a new _action_ but a _node_[^node]. 
The generated _action_ includes all parameters given to `rule.define()` as a set of predefined parameter values.
When using the generated _action_, the predefined parameters will be taken into account. 
Some template parameters will be used if this parameter is ommittet. (`base`, `odir`, `ext`, `type`, `prog`)
Some template parameters will be used in addition to the given parameters. (`src`, `defines`, `cflags`, `incdir`, `libdir`, `libs`, `needs`, `from`, `deps`)

```lua
-- example_07.mk
compile = rule.define {odir="tmp", base="src", cflags="-O2", type="obj",
                       action="gcc -c $OPTIONS $SOURCES -o $OUTFILE"
                      }
link    = rule.define {odir="bin", type="prog",
                       action="gcc $OPTIONS $SOURCES -o $OUTFILE"
                      }
NODE_OBJ = compile {"hello.o", src="hello.c"}
NODE_EXE = link {"hello.exe", inputs=NODE_OBJ}
```
`rule.create()` and `rule.define()` are very universal and usefull but somehow limited too: One call to rule.create() or calling a generated action generates ___one___ node for ___one___ file only. That is the point, where the `.group()` action of the predefined tools comes handy. `.group()` generates a list of nodes, including new generated nodes to compile each given source file to a object file.

---

The next example use the `cc` _tool_'s `.group()` and `.program()` _actions_[^action]. The `cc` _tool_ deals with standard c files.  
The `.group()` _action_ creates a _node_ that compiles all given c sources to object files. The file names for temporary 
object files are generated automatically.
The `.program()` _action_ creates a node for a executable to build. It also store additional informations behind the scene, 
for instance: The node builds a executable! (If no default target is defined, all executables and libraries defined 
will be assumed to be the default targets.)
All `cc` _actions_ are os aware and choose file extensions as needed. Our next example will build a `"hello.exe"` on 
Windows and a `"hello"` on *nix.

```lua
-- example_08.mk
NODE_OBJ = cc.group {src="hello", odir="tmp", base="src"}
NODE_EXE = cc.program {"hello", inputs=NODE_OBJ, odir="bin"}
default(NODE_EXE)
```

Off cause, with all the knowlege we have now, we can write this simple example shorter:

```lua
-- example_09.mk
cc.program {"hello", src="hello", base="src", odir="bin"}
```

## Action parameters

### parameters unterstood by most tools:

| name        | type            | description                                                                                                |
|-------------|:----------------|------------------------------------------------------------------------------------------------------------|
| __[1]__     | _string_        | filename or filename prefix for the generated file. May also include a absolute or relative path.          |
| __src__     | _stringlist_    | a list of sourcefiles. The extensions may be omittet if the tool knows the default extensions to look for. |
| __ext__     | _stringlist_    | a list of default source file extension e.g: `".c .cpp"`.                                                  |
| __base__    | _string_        | base folder where the sources are stored.                                                                  |
| __odir__    | _string_        | folder where to store the compiled files.                                                                  |
| __incdir__  | _stringlist_    | a list of directories where to seach includefiles.                                                         |
| __libdir__  | _stringlist_    | a list of directories where to seach libraries.                                                            |
| __libs__    | _stringlist_    | a list of libraries needed to link a executable or library.                                                |
| __cflags__  | _stringlist_    | a list of compilerflags.                                                                                   |
| __defines__ | _stringlist_    | a list of defines.                                                                                         |
| __needs__   | _stringlist_    | a list of needs to pull parameters from and use them in addition.                                          |
| __from__    | _string_        | pull parameters from a need. e.g: `from="lua:cflags,defines"` reads the fields `cflags` and `defines` from the need "lua" and uses it in addition to all given parameters.|
| __inputs__  | _MaketreeNode_ | Other MaketreeNodes used as sources for compilation.                                                        |
| __deps__    | _MaketreeNode_ | Other MaketreeNodes needs to be built before this node. Unlike `"inputs"`, those nodes do not become part of the generated command line |

### aditional parameters unterstood by rule:

| name        | type                        | description                                                |
| ----------- | --------------------------- | ---------------------------------------------------------- |
| __prog__    | _string_ or _MaketreeNode_  | executable to be used in this rule.                        |
| __type__    | _string_                    | type of the generated file. default: none. `"obj"`, `"slib"`, `"dlib"` and `"prog"` are predefined types used by all tools and can be used with care. |
| __outext__  | _string_                    | extension to use for generated files                       |

### Parameter types:

_string_ 
: A lua string containing 1 value, e.g. a filename, define, path, ...  
example: `base="src"`

_stringlist_ 
: A collection of string values.  
type-a: all values space delimitted in one string e.g.  
	  `libs="kernel32 user32 gdi32 winspool comdlg32"`  
type-b: A lua table containing strings with one value. e.g.  
	  `libs={"kernel32", "user32", "gdi32", "winspool", "comdlg32"}`  
		Note: A list type-b containing lists type-a is _not_ allowed.

_MaketreeNode_ 
: A lua value returned by a _tool_ or _action_ call, containing ..  
a) all informations needed to build and/or use a file in a make run or ..  
b) one or more _MaketreeNode_'s .

_MaketreeNodes_ 
: A _MaketreeNode_ or a lua table containing _MaketreeNode_'s.

### rule(): action variables:

- `$PROG`: program to execute. (should be the very 1st variable in the action string.)
- `$SOURCES`: will be substituted by _all_ filenames given by `src` and `inputs`.
- `$SOURCE`:  will be substituted by _one_ filename given by `src` and `inputs`.  
  `rule()` will generate as many nodes as sources are given and return a nodelist instead a single node.
- `$OUTFILE`: generated name for the file to build.
- `$*`: all other variables starting with "$" and continuing with upper case letters can be freely used and will be substituded 
  by the value of the coresponding lower letter parameter. (eg. `$SOMETHING` will be substituded by the parameter value of `something`.)

[^action]:glossary: action
	A tool function generating a node or a rule template.

[^node]:glossary: node
	A data structure describing a file to built. This description includes file name, command line to 
	build the file, nodes the node depends on and needed to be built first, ...
