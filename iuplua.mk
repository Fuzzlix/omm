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

local function bin2c(par)
  local function msg(s, ...) return ("lua2c(): "..s):format(...); end;
  --
  local numtab={}; 
  for i = 0, 255 do numtab[string.char(i)] = ("%3d,"):format(i); end;
  --
  local ifname = par.source:gsub(".*/", "");
  local ifile  = io.open(par.source,  "rb");
  if not ifile then return nil, msg("cant open %s.",par.source); end;
  local ofile  = io.open(par.outfile, "w+");
  if not ofile then 
    ifile:close();
    return nil, msg("cant open %s.",par.outfile); 
  end;
  local res = ofile:write(
      "\n{\n static const unsigned char B1[]={\n",
      ifile:read("*a"):gsub(".", numtab):gsub(("."):rep(80), "%0\n"), 
      string.format("\n};\n\n  iuplua_dobuffer(L,(const char*)B1,sizeof(B1),%q);\n}\n", ifname)
      );
  ofile:close();
  ifile:close();
  if res then return true; end;
  return nil, msg("error writing %s.",par.outfile); 
end;

--
if not make.Targets("iuplua"..LUAVER) then -- iuplua-3.19.1
  -- [[
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

  local CTRLC    = addprefix("elem/il_", addsuffix( ".c",   CTRL))
  local SRCLUA   = addprefix("elem/",    addsuffix( ".lua", CTRL)).. " " .. "iuplua.lua constants.lua iup_config.lua" 
  
  --local STRPLUA  = rule {base=SRCDIR, odir=TEMPDIR, prog="lstrip.lua", src=SRCLUA, 
  --                       action = "$PROG $SOURCE $OUTFILE"
  --                      }
  --local CTRLH    = rule {base=SRCDIR, odir=TEMPDIR, prog=SRCDIR.."/bin2c.lua", inputs=STRPLUA, outext=".lh",
  --                       action = "$PROG $SOURCE > $OUTFILE"
  --                      }
  local CTRLH    = rule {base=SRCDIR, odir=TEMPDIR, func=bin2c, src=SRCLUA, outext=".lh", -- inputs=STRPLUA,
                         action = "lua2c $SOURCE $OUTFILE" -- dummy commandline for console output.
                        }
  local SRC      = "iuplua.c iuplua_api.c iuplua_draw.c iuplua_tree_aux.c iuplua_scanf.c \z
                    iuplua_getparam.c iuplua_getcolor.c iuplua_config.c " .. CTRLC
  --
  local DLIBOBJ = c99 {"iuplua"..LUAVER, src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, 
                       defines=DEFINES, cflags=CFLAGS, deps=CTRLH, needs=NEEDS
                      }
  local DLIB    = c99.shared {"iuplua"..LUAVER, inputs=DLIBOBJ, odir=LUA_CDIR, cflags=CFLAGS, needs=NEEDS}
  --
  target("iuplua"..LUAVER, DLIB)
  default{DLIB}
  --]]
end;
