--- lakefile for lua-modules
--
if not WINDOWS then quit("We are not running on Windows?") end;
--
-----------------------------------------------------------------------------------------------
--
LUAROOT = LUAROOT or PWD
LUA_BIN = LUA_BIN or LUAROOT.."/bin" -- install dir
TEMPDIR = TEMPDIR or LUAROOT.."/tmp" -- dir for intermediate files
--
local LUAVER     = make.Needs"lua".LUAVERSION
local TEMPDIR    = TEMPDIR .. "/lua" .. LUAVER  -- dir for intermediate files
local MODULES    = LUAROOT
local LUA_ETCDIR = LUA_BIN.."/etc"
local LUA_IDIR   = LUA_BIN.."/include/" .. LUAVER
local LUA_CDIR   = LUA_BIN.."/lib/" .. LUAVER
local LUA_LDIR   = LUA_BIN.."/lua"

--svn.checkout{"lsqlite3", "https://github.com/Fuzzlix/lsqlite/branches/0.9.4"}
if make.path.isDir("lsqlite3") then -- module lsqlite3
  --  [[ 
  local MODULES = MODULES .. "/lsqlite3";
  local DOCDIR  = MODULES .. "/doc";
  local MODS_C  = c99 {"lsqlite3_s", src="*.c", base=MODULES, odir=TEMPDIR, needs="luas", cflags=CFLAGS}
  local MODD_C  = c99 {"lsqlite3",   src="*.c", base=MODULES, odir=TEMPDIR, needs="lua", cflags=CFLAGS}
  --
  local MODLIB  = c99.library {'lsqlite3'..LUAVER, odir=LUA_IDIR, inputs=MODS_C, needs="luas", cflags=CFLAGS}          
  local MODDLL  = c99.shared  {'lsqlite3'..LUAVER, odir=LUA_CDIR, inputs=MODD_C, needs="lua", cflags=CFLAGS}
  target("lsqlite3", {MODLIB, MODDLL})
  default{MODLIB, MODDLL}
  if not make.Targets "lsqlite3_doc" then
    local MODDOC= file {src="*.html *.css", base=DOCDIR, odir=LUA_ETCDIR.."/lsqlite3/doc"}
    target("lsqlite3_doc", MODDOC)
    default{MODDOC}
  end;
  --]]
end;

svn.checkout{"lfs", "https://github.com/keplerproject/luafilesystem/trunk"}
if make.path.isDir("lfs") then -- module lfs
  --  [[ 
  local DOCDIR  = MODULES .. "/lfs/doc/us";
  local MODULES = MODULES .. "/lfs/src";
  local MODS_C  = c99 {"lfs_s", src="lfs", base=MODULES, odir=TEMPDIR, needs="luas", cflags=CFLAGS}
  local MODD_C  = c99 {"lfs",   src="lfs", base=MODULES, odir=TEMPDIR, needs="lua", cflags=CFLAGS}
  --
  local MODLIB  = c99.library {'lfs'..LUAVER, odir=LUA_IDIR, inputs=MODS_C, needs="luas", cflags=CFLAGS}          
  local MODDLL  = c99.shared  {'lfs'..LUAVER, odir=LUA_CDIR, inputs=MODD_C, needs="lua", cflags=CFLAGS}
  target("lfs", {MODLIB, MODDLL})
  default{MODLIB, MODDLL}
  if not make.Targets "lfs_doc" then
    local MODDOC= file {src="*.html *.png *.css", base=DOCDIR, odir=LUA_ETCDIR.."/lfs/doc"}
    target("lfs_doc", MODDOC)
    default{MODDOC}
  end;
  --]]
end;

svn.checkout{"lpeg", "https://github.com/Fuzzlix/lpeg/branches/1.0"}
if make.path.isDir("lpeg") then -- module lpeg
  -- [[
  local MODULES = MODULES.."/lpeg"
  local MODS_C  = c99 {"lpeg_s", src="*.c", base=MODULES, odir=TEMPDIR, needs="luas", cflags=CFLAGS}
  local MODD_C  = c99 {"lpeg",   src="*.c", base=MODULES, odir=TEMPDIR, needs="lua", cflags=CFLAGS}
  --
  local MODLIB  = c99.library {'lpeg'..LUAVER, odir=LUA_IDIR, inputs=MODS_C, needs="luas"}          
  target("lpeg", MODLIB)
  default(MODLIB)
  local MODDLL  = c99.shared  {'lpeg'..LUAVER, odir=LUA_CDIR, inputs=MODD_C, needs="lua", cflags=CFLAGS}           
  target("lpeg", MODDLL)
  default(MODDLL)
  local MODLUA  = file {src="re.lua", base=MODULES, odir=LUA_CDIR}
  target("lpeg", MODLUA)
  default(MODLUA)
  if not make.Targets "lfs_doc" then
    local MODDOC  = file {src="*.gif *.html", base=MODULES, odir=LUA_ETCDIR.."/lpeg/doc"}
    target("lpeg_doc", MODDOC)
    default(MODDOC)
  end;
  --]]
end;

svn.checkout{"luasocket", "https://github.com/diegonehab/luasocket/trunk"}
if make.path.isDir("luasocket") then -- module luasocket
  -- [[
  local MODULE  = MODULES.."/luasocket"
  local SRCDIR  = MODULE.."/src"
  local SOCT_C  = "luasocket wsocket timeout buffer io auxiliar options inet except select tcp udp compat"
  local MIME_C  = "mime"
  local DEFINES  = "NDEBUG LUASOCKET_INET_PTON WINVER=0x0502"
  --
  local SOCTS_C = c99 {"luasocket_s", src=SOCT_C, defines=DEFINES ,base=SRCDIR, odir=TEMPDIR, needs="luas", cflags=CFLAGS}
  local SOCTD_C = c99 {"luasocket",   src=SOCT_C, defines=DEFINES ,base=SRCDIR, odir=TEMPDIR, needs="lua windows", cflags=CFLAGS}
  local MIMES_C = c99 {"luasocket_s", src=MIME_C, defines=DEFINES ,base=SRCDIR, odir=TEMPDIR, needs="luas", cflags=CFLAGS}
  local MIMED_C = c99 {"luasocket",   src=MIME_C, defines=DEFINES ,base=SRCDIR, odir=TEMPDIR, needs="lua windows", cflags=CFLAGS}
  --
  local SOCTSLIB= c99.library {'socket_core'..LUAVER, odir=LUA_IDIR, inputs=SOCTS_C, needs="luas"}           
  local SOCTSDLL= c99.shared  {'socket/core'..LUAVER, odir=LUA_CDIR, inputs=SOCTD_C, needs="lua", libs="ws2_32", cflags=CFLAGS} 
  local MIMELIB = c99.library {'mime_core'..LUAVER,   odir=LUA_IDIR, inputs=MIMES_C, needs="luas"}
  local MIMEDLL = c99.shared  {'mime/core'..LUAVER,   odir=LUA_CDIR, inputs={MIMED_C, SOCTSDLL}, needs="lua", cflags=CFLAGS}
  --
  local MODLUA1 = file {src="socket mime ltn12",            ext=".lua", base=SRCDIR, odir=LUA_CDIR}
  local MODLUA2 = file {src="ftp headers http smtp tp url", ext=".lua", base=SRCDIR, odir=LUA_CDIR.."/socket"}
  local MODLUA  = group {MODLUA1, MODLUA2}
  local MODBIN  = group {SOCTSLIB, SOCTSDLL, MIMELIB, MIMEDLL, MODLUA}
  target("luasocket", MODBIN)
  default(MODBIN)
  --
  if not make.Targets "luasocket_doc" then
    local MODDOC  = file {src="doc/* etc/* samples/* test/*", base=MODULE, odir=LUA_ETCDIR.."/luasocket"}
    target("luasocket_doc", MODDOC)
    default{MODDOC}
  end;
  --]]
end; 

svn.checkout{"penlight", "https://github.com/stevedonovan/Penlight/trunk"}
if make.path.isDir("penlight") then -- module penlight
  -- [[
  if not make.Targets "penlight" then
    -- TODO: generate docs
    local MODULE  = MODULES.."/penlight"
    local SRCDIR  = MODULE.."/lua"
    --
    local MODLUA = file {src="pl/*", ext=".lua", base=SRCDIR, odir=LUA_LDIR}
    local MODDOC = file {src="examples/*", base=MODULE, odir=LUA_ETCDIR.."/penlight"}
    --
    local PENLIGHT = group {MODLUA, MODDOC}
    --
    target("penlight", PENLIGHT)
    default(PENLIGHT)
  end;
  --]]
end; 

svn.checkout{"winapi", "https://github.com/Fuzzlix/winapi/trunk"}
if make.path.isDir("winapi") then -- module winapi
  -- [[
  local MODULES = MODULES.."/winapi"
  local MODS_C  = c99.group   {"winapi_s", src="winapi wutils", base=MODULES, odir=TEMPDIR, defines='PSAPI_VERSION=1', needs="luas", cflags=CFLAGS}  
  local MODD_C  = c99.group   {"winapi",   src="winapi wutils", base=MODULES, odir=TEMPDIR, defines='PSAPI_VERSION=1', needs="lua", cflags=CFLAGS}
  --
  local MODLIB  = c99.library {'winapi'..LUAVER, odir=LUA_IDIR, inputs={MODS_C}, needs="luas windows", cflags=CFLAGS}
  target("winapi", MODLIB)
  default(MODLIB)
  local MODDLL  = c99.shared  {'winapi'..LUAVER, odir=LUA_CDIR, inputs={MODD_C}, needs="lua windows", cflags=CFLAGS}
  target("winapi", MODDLL)
  default(MODDLL)
  --if not LUAMODS_DOC_COPIED then
  --  local MODDOC  = file {src="doc/*", base=MODULES, odir=LUA_ETCDIR.."/winapi", recurse=true}
  --  target("winapi", MODDOC)
  --  default(MODDOC)
  --end;
  --]]
end;

svn.checkout{"lanes", "https://github.com/LuaLanes/lanes/trunk"}
if make.path.isDir("lanes") then -- module lanes
  -- [[
  local MODULE  = MODULES.."/lanes"
  local SRCDIR  = MODULE.."/src"
  local MODSRC  = "lanes compat threading tools deep keeper"
  local DEFINES  = ""
  --
  local MODS_C = c99 {"lanes_s", src=MODSRC, defines=DEFINES ,base=SRCDIR, odir=TEMPDIR, needs="luas", cflags=CFLAGS}
  local MODD_C = c99 {"lanes",   src=MODSRC, defines=DEFINES ,base=SRCDIR, odir=TEMPDIR, needs="lua windows", cflags=CFLAGS}
  --
  local MODLIB = c99.library {'lanes_core'..LUAVER, odir=LUA_IDIR, inputs=MODS_C, needs="luas"}           
  local MODDLL = c99.shared  {'lanes/core'..LUAVER, odir=LUA_CDIR, inputs=MODD_C, needs="lua", cflags=CFLAGS}
  local MODLUA = file {src="lanes", ext=".lua", base=SRCDIR, odir=LUA_CDIR}
  local MODBIN = group {MODLIB, MODDLL, MODLUA}
  target("lanes", MODBIN)
  default{MODBIN}
  --
  if not make.Targets "lanes_doc" then
    local MODDOC = file {src="docs/*", base=MODULE, odir=LUA_ETCDIR.."/lanes"}
    target("lanes_doc", MODDOC)
    default{MODDOC}
  end;
  --]]
end; 

svn.checkout{"iuplua", "svn://svn.code.sf.net/p/iup/iup/trunk/iup"}
if make.path.isDir("iuplua") then 
  -- [[
  make "iuplua"
  --]]
end;
