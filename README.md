#One More Maketool. A lua based extensible build engine.

OMM is a lua make tool very similiar to [lake][]. Its goal is a simpler 
and cleaned up syntax, extensibility, portability between different lua 
versions and operating systems. The multitreading is improved compared to 
[lake][]. All makefiles become executed in one and the same sandbox 
environment.  
OMM is still in alpha state, caused by the fact there is no good
documentation and it is not widely tested.  
To see what works and how it works, take a look at the makefiles in the 
examples folder.

Any critics, test reports, and contibutions are welcome.

---

Inspired by and stealing code snippets from Steve Donovan's [lake][].  

Using modified versions of 
Roland Yonaba's [30log][] and 
Gary V. Vaughan's [optparse][].

Required 3rd party modules:
[luafilesystem][], [winapi][]/[luaposix][]

Thanks also to Paul Kulchenko for his great [ZeroBraneStudio][].

[lake]:            https://github.com/stevedonovan/Lake
[30log]:           https://github.com/Yonaba/30log
[optparse]:        https://github.com/gvvaughan/optparse)
[luafilesystem]:   https://github.com/keplerproject/luafilesystem/
[winapi]:          https://github.com/stevedonovan/winapi
[luaposix]:        https://github.com/luaposix/luaposix/
[ZeroBraneStudio]: https://github.com/pkulchenko/ZeroBraneStudio

---

copyright (C) 2016 Ulrich Schmidt

**The MIT License (MIT)**

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:  
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

# OMM Internals

## Naming conventions:

* Commands like `cc`, `c99`, `cpp`, `file`, ... are called _tools_.
* _Tools_ may have _actions_ like `.program`, `.library`. or `.group`.  
  _Actions_ may have any name valid as a lua field name but 
  not already existing `clTools` field names.
* _Tools_ are defined and managed inside _toolchains_.
* _Toolchains_ can be _loaded_ and/or _activated_.
* _Loading_ a _toolchain_ means, requiring the toolchain module
  and registering the _toolchain_ and ther _actions_ inside the 
  _toolchain manager_.
* _Activating_ a toolchain means, inserting all actions of 
  a _loaded_ toolchain into the makefile sandbox environment.
  (Most times this happens automatically when a makescript 
  try to use a tool the 1st time.)

---

##Internal naming conventions:

* class names start with `cl` followed by a capital letter.
  eg. `clToolchain`, `clMakefile`, ...
* object names start with a capital letter.
  eg. `Tools`, `Makefile`, ...
* fixed values (constants) are all capitalized.
  eg. `TOOLCHAIN_PREFIX`, `_DEBUG`, ...
* predefined makefile valiables are all capitalized.
  eg. `CC`, `CXX`, `WINDOWS`, ...
* all other variables start with lower case letter.
* all other names are _exceptions_ from the convention. ^^

---

##Toolchain handling:

Toolchain handling is mainly done by the `Tools` object which is a object of `clTools`.
`clTools:load()` first tries to find a external toolchain and, if not successful, 
try to find a internal/preloaded toolchain. Internal toolchain names are 
prefixed by `"tc_"` eg. the Toolchain `"gnu"` is preloaded in a module named `"tc_gnu"`.

**Example:**  

To extend the  preloaded toolchain "files", simply create a new module
`"omm_files.lua"` somewhere inside your `package.path`.
First require the old internal toolchain, you want to extend:  

    local Files = require "tc_files";

Require "Make". This is the main object for supplying internal informations and 
functionality. (Note the capital "M" in the module name!)

    local Make = require "Make";

Now get the Toolchains object from Make. It provides all functionality you need 
to create and register the new tools, you want to create.

    local Toolchains = Make.tools;
    
Now you are ready to write your code into the new toolchain module.
Finally return. There is nothing to return because all tool registration is hopefully 
already done by `Toolchains`.

    return;

---

##The Make object:

The Make object is the central hub for all needed informations.
It stores for instance:

* File and target lists
* The Needs list
* The toolchain manager
* usefull utility functions
* ...
* command line options
  
It can be called to start a make-run.
It is available in makescripts as `make` and can be required 
in toolchain modules with `require "Make"`.

---

## Make tree nodes:

The root of a make tree is a _Target_  (clTarget). 

* _Targets_ may have a field _action_ which holds a method to execute.
(The targets 'clean' and 'CLEAN' are implemented this way.) Targets usually
have a field 'deps', which points to a _Targetlist_.
* _Targetlists_ hold a array of _Files_ and/or _Targets_.
* _Files_ can be of subtype _SourceFile_, _Tempfile_ or _Targetfile_.


_Sourcefiles_ are read-only for OMM and needs to be present.  
_Tempfiles_ are created as nessesary.  
_Targetfiles_ are the goal to create for the make process.  

---

## Needs:

Needs are basically named collections of action parameters:

* defines:        aditional defines for compiler
* incdir:         include dir(s)
* libs:           libs to link 
* libdir:         lib search path(s)
* prerequisites:  Targets needed to fulfill this need.  
                  (This field will be _ignored_, when exporting 
                  needs to a need file.)

It is also possible to assign _aliases_ to needs. This way it becomes possible 
to call sub-makefiles multiple times with different parameter sets stored in 
different needs.

---

## The make process:

The make process is a 3 pass run:

### Pass 1

**All** marefiles are read and the make tree becomes generated.
This pass may error out if there are:  

* syntax errors in makefiles  
* malformed action parameters. 
  ("from=" parameters are ignored in this pass.)  
* unsatisfied needs.  
* non existend source files  

All makescripts use the same sandbox environment and share
all global valiables. This way a earlier scanned makefile
may give informations to later scanned makefiles. There is 
no need anymore, to pass values via the os environment. (off
cause you still can.)
   
### Pass 2

The dirtyness of all nodes becomes calculated. Also the
"from=" parameters become expanded.

### Pass 3

For all dirty treenodes the target(s) depend on:  

* the action-functions become executed.  
* the command line becomes generated and executed.  

There are 2 different pass-3 implementations:  

* standard/ordered: (-j)  
  Something similiar to [lake][]. Only files
  in one targetlist can be built at the same time. The job queue
  becomes flushed after each treenode.
* quick/unordered: (-J)  
  The tree nodes become reordered to build bigger
  lists of jobs (execution levels) that can be executed at the same 
  time. The job queue becomes flushed after each execution level.  
  Better: more nodes/level, less levels.

See also the the benchmarks.
     
### The "from" trick:

There are 2 reasons to implement the "from" parameter:

- You may define somthing only once, you want to store in the 
  need and also use as a action parameter.
- Some targets defined later in your makefile(s) may want to add some 
  additional defines/libs,... to a need they depend on.  

**Example:**  
The lua library is build by default with `"LUA_BUILD_AS_DLL"` only.
The later "my_module" target needs the lua lib built with `"LUA_COMPAT_MODULE"`.
The my_module makescript may add in the 1st pass this define to the "lua"-need.
  
    make.Needs"lua".defines:add("LUA_COMPAT_MODULE")

Need fields are stored in StringList-objects. Stringlist objects store each 
string value only once. This means, if "LUA_COMPAT_MODULE" is already present 
in .defines, the shown line has no effect and does no harm. 
If the need "lua" does not exist, the command creates a error.  
In the 2nd pass the from-fields become expanded and there values 
become stored/added in treenode fields.  
In the 3rd pass, the lua lib becomes compiled with `"LUA_BUILD_AS_DLL LUA_COMPAT_MODULE"`.

---

## Benchmarks:

command: 

    omm [option] default,CLEAN

targets: lua5.3, lfs, lpeg, winapi, luasocket, lualanes, penlight.  
         (also copying all result files, docs, tests, etc to a install folder.)
         
debug output when using '-J':

    makeNodeQD(): 305 nodes in 5 level(s). 6..158 nodes/level
  
### Intel core-i5 @3.1GHz (4 cores) 8GB Win7/64, TDM-gcc-5.1, lua-5.3.3

    -n  00,27s
    -j1 50,47s=100%
    -j2 29,14s=57.7%   -J2 26,61s=52.7%    J/j=91,3%
    -j4 20,25s=40.1%   -J4 16,10s=31.9%    J/j=79,5%
    -j5 19,55s=38.7%   -J5 15,96s=31.6%    J/j=81.6%

### Intel celeron @1.8GHz (2 cores) 16GB Win7/64, TDM-gcc-5.1, lua-5.3.3

    -n  00,44s
    -j1 70,78s=100%
    -j2 44,79s=63.2%   -J2 40,83s=57.6%    J/j=91.1%
    -j3 44,04s=62.2%   -J3 40,68s=57.4%    J/j=92.2%

---

# TODO

- Not well tested on linux yet. 
  Still some changes needed to work on linux properly in all cases. (see: TODO comments)

- optparse: better check for parameter values.  
  For instance `omm -j default` takes "default" as a -j parameter but as target.
  
- better english in messages and comments.

- More sophisticated needs handling
    - OS specific needs
        - What is a good syntax for?
        - default/fallback needs?

- msc toolchain.
    - It is a poor tested skeleton right now.

- lua toolchain. what are useful actions to implement and what is a good syntax for?  
  .strip action? (remove comments and whitespaces from source)  
  .glue action?  (preload lua modules in main source)  
  .program?      (make self running executable.)  
  .ldoc?         (generate documentation)  
  
- implement a patch ability?

- dependency file generation and handling.

- how to deal with zip/... achives?

- svn tool, repository toolchain. 
  svn.checkout works, but need better ideas, HOW to deal with repositories at all.
  svn.checkout is not part of the make tree now. Threfore it is being executed 
  allways in pass 1. Should be executed in pass 3 only when the target requests it.
  A patch ability would be nice to apply local changes to the downloded files.  
  (Maybe better implement a "repository" _tool_, that handles svn, git, zip, .. downloads)
  
- correct silent/normal/verbose message print (doublecheck)

- create a documentation.

- create a test suite.

- remove old style pass3 when the new pass3 is well tested and noone complains.

