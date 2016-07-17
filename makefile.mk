--[[ makefile for lua-5.1, lua-5.2, lua-5.3 and modules, ...
-- Build a lua environment for windows, where all lua versions resides side by side in one 
-- directory tree including there modules, libraries, documentation and lua tools.
-- It creates a `"install` folder containing all content you may want for copy 
-- to `c:\lua` (for instance).
-- This makefile is not intended to work on other OS than Windows.
-- it is tested with [TDM-GCC-64](https://tdm-gcc.tdragon.net/)
--]]
if not WINDOWS then quit("We are not running on Windows?") end;
--
-- Adress 32/64 bit targets directly.
-- not all lua .c modules compile in 64bit mode, so stick on 32bit build for now.
make.toolchain "gnu32"; -- compile to 32bit executables. (or use -m32 commandline parameter)
--make.toolchain "gnu64"; -- compile to 64bit executables. (or use -m64 commandline parameter)
--
--make.set_flags {OPTIMIZE="Os", NODEPS=true, PREFIX="x86_64-w64-mingw32"};
-----------------------------------------------------------------------------------------------
--
LUAROOT = PWD                  -- base of the lua build tree
LUA_BIN = LUAROOT.."/_install" -- install dir
          .. (M32 and "32" or "") 
          .. (M64 and "64" or "") 
TEMPDIR = LUAROOT.."/tmp"      -- dir for intermediate files
          .. (M32 and "/32" or "") 
          .. (M64 and "/64" or "") 
--CFLAGS  = "-Werror -pipe" -- Make all warnings into errors.
CFLAGS  = "-pipe"
--
-----------------------------------------------------------------------------------------------
--
-- Dont use "luajit20" and "lua51" makefiles at the same time!
-- luajit acts as a replacement for lua51.
make "luajit20"
--make "lua51"
make "modules"
make "lua52"
make "modules"
make "lua53"
make "modules"
--make "tools"

--[[-- This build script a patched package.path and package.cpath:
       (Otherwise the resulting executables may not find the libs in
       PortableApp zenarios.)

for lua-5.1: (and luaJIT)

 #define LUA_LDIR	"!\\lua\\"
 #define LUA_CDIR	"!\\lib\\51\\"
 #define LUA_PATH_DEFAULT  \
 		LUA_LDIR"?.lua;"  LUA_LDIR"?\\init.lua;" \
		LUA_CDIR"?.lua;"  LUA_CDIR"?\\init.lua;" ".\\?.lua"
 #define LUA_CPATH_DEFAULT \
		LUA_CDIR"?51.dll;"	LUA_CDIR"?.dll;" \
		"!\\?51.dll;"	"!\\?.dll"

for lua-5.2:

 #define LUA_LDIR	"!\\lua\\"
 #define LUA_CDIR	"!\\lib\\52\\"
 #define LUA_PATH_DEFAULT  \
 		LUA_LDIR"?.lua;"  LUA_LDIR"?\\init.lua;" \
		LUA_CDIR"?.lua;"  LUA_CDIR"?\\init.lua;" ".\\?.lua"
 #define LUA_CPATH_DEFAULT \
		LUA_CDIR"?52.dll;"	LUA_CDIR"?.dll;" \
		"!\\?52.dll;"	"!\\?.dll"

for lua-5.3:

 #define LUA_LDIR	"!\\lua\\"
 #define LUA_CDIR	"!\\lib\\53\\"
 #define LUA_PATH_DEFAULT  \
 		LUA_LDIR"?.lua;"  LUA_LDIR"?\\init.lua;" \
		LUA_CDIR"?.lua;"  LUA_CDIR"?\\init.lua;" ".\\?.lua"
 #define LUA_CPATH_DEFAULT \
		LUA_CDIR"?53.dll;"	LUA_CDIR"?.dll;" \
		"!\\?53.dll;"	"!\\?.dll"

--]]--