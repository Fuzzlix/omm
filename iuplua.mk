--- makefile for iuplua
--
if not WINDOWS then quit("We are not running on Windows?") end;
--
LUAROOT = LUAROOT or PWD
LUA_BIN = LUA_BIN or LUAROOT.."/bin" -- install dir
TEMPDIR = TEMPDIR or LUAROOT.."/tmp" -- dir for intermediate files
--
IUPROOT = LUAROOT.."/iuplua"
IUPBIN  = LUA_BIN
--
make "iup"
--
local LUAVER  = make.Needs"lua".LUAVERSION
local TEMPDIR = TEMPDIR.."/"..LUAVER
--
include "luastrip" -- load luastrip rule.
include "bin2c"    -- load bin2c rule.
--
if not make.Targets("iuplua"..LUAVER) then -- iuplua-3.19.1
  --
  local LUA_CDIR = LUA_BIN.."/lib/" .. LUAVER
  local SRCDIR   = IUPROOT .. "/iup/srclua5"
  local INCLUDES = TEMPDIR.." . ../include ../src"
  local NEEDS    = "lua iup"
  local DEFINES  = "IUPLUA_USELH"
  --
  local CTRL     = "button canvas dialog colordlg clipboard filedlg fill frame hbox normalizer gridbox \z
                    item image imagergb imagergba label expander link menu multiline list separator user \z
                    submenu text toggle vbox zbox timer detachbox sbox scrollbox split spin spinbox cbox \z
                    radio val tabs fontdlg tree progressbar messagedlg progressdlg backgroundbox flatbutton \z
                    animatedlabel calendar datepick param parambox"

  local SRCLUA   = addprefix("elem/",    addsuffix( ".lua", CTRL)).." iuplua.lua constants.lua iup_config.lua" 
  
  local STRPLUA  = luastrip {base=SRCDIR, odir=TEMPDIR, src=SRCLUA} -- luastrip: imported rule

  local CTRLH    = bin2c {inputs=STRPLUA, base=SRCDIR, odir=TEMPDIR, outext=".lh", -- bin2c: imported rule
                          command="iuplua_dobuffer(L,(const char*)B1,sizeof(B1),%q)"
                         }
  local SRC      = "iuplua.c iuplua_api.c iuplua_draw.c iuplua_tree_aux.c iuplua_scanf.c \z
                    iuplua_getparam.c iuplua_getcolor.c iuplua_config.c " .. 
                    addprefix("elem/il_", addsuffix( ".c", CTRL))
  --
  local DLIBOBJ  = c99 {"iuplua"..LUAVER, src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, 
                        defines=DEFINES, cflags=CFLAGS, needs=NEEDS, deps=CTRLH -- deps defined here explicit, because automatic ..
                       }                                                        -- include file checks do not work for generated files (yet).
  local DLIB     = c99.shared {"iuplua"..LUAVER, inputs=DLIBOBJ, odir=LUA_CDIR, cflags=CFLAGS, needs=NEEDS}
  --
  target("iuplua"..LUAVER, DLIB)
  default{DLIB}
  --
end;
