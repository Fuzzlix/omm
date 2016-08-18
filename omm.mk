--- makefile for omm.
-- statically linked, self contained lua executable
if not WINDOWS then quit("We are not running on Windows?") end;
--
-----------------------------------------------------------------------------------------------
--
LUAROOT = LUAROOT or PWD
LUA_BIN = LUA_BIN or LUAROOT.."/_install"              -- install dir
TEMPDIR = TEMPDIR or LUAROOT.."/tmp"                   -- dir for intermediate files
--
include "luastrip"
include "luaglue"

local OMM = {
  -- glue stripped lua source to mk.exe
  luaglue{odir=LUA_BIN, loader="mk.exe", force=true, 
          inputs=luastrip{src="mk.lua", odir=TEMPDIR}
         },
  -- copy include files into Lua's package.path
  file.copy{src="*.mki", odir=LUA_BIN.."/lua"}
}

target("omm", OMM)
default(OMM)
