--- makefile for luaJIT
-- (NOT FULL TESTED YET!) At least it compiles a win32 executable and modules. win32 executable not full tested yet.
--
if not WINDOWS then quit("We are not running on Windows?") end;
--
-----------------------------------------------------------------------------------------------
--
LUAROOT = LUAROOT or PWD
LUA_BIN = LUA_BIN or LUAROOT.."/_install"              -- install dir
TEMPDIR = TEMPDIR or LUAROOT.."/tmp"                   -- dir for intermediate files

local LUA_VERSION  = "51"
local LUA_IDIR     = LUA_BIN.."/include/"..LUA_VERSION -- dir for headers and static libs
local LUA_CDIR     = LUA_BIN.."/lib/"..LUA_VERSION     -- dir for c modules
local LUA_LDIR     = LUA_BIN.."/lua"                   -- dir for lua modules 
local LUA_ETC_DIR  = LUA_BIN.."/etc"                   -- dir for documentation, tests, etc.
local JIT_SRC_DIR  = LUAROOT.."/luaJIT20/src"          -- where are the lua sources.
local JIT_HOSTDIR  = JIT_SRC_DIR.."/host"

local CFLAGS       = CFLAGS .. " -fomit-frame-pointer"
--if make.get_flag"M32" then CFLAGS = CFLAGS .. " -march=i686" end

if not make.path.isDir("luaJIT20") then
  svn.checkout{"luaJIT20", "https://github.com/Fuzzlix/lua5/branches/JIT20"}
end
--
local MINILUA = c99.program {TEMPDIR.."/minilua", src="minilua.c", base=JIT_HOSTDIR, incdir=JIT_SRC_DIR}
local ARCHH   = rule {TEMPDIR.."/buildvm_arch.h", deps = MINILUA,
                          action = ("%s %s %s -D JIT -D FFI -D FPU -D HFABI -D VER= -D WIN -o $OUTFILE %s"):format(
                                    MINILUA:canonical(), "luaJIT20/dynasm/dynasm.lua", 
                                    make.get_flag"M32" and "" or "-D P64", "luaJIT20/src/vm_x86.dasc")
                         }
local BUILDVM = c99.program {TEMPDIR.."/buildvm", 
                             src="buildvm buildvm_asm buildvm_peobj buildvm_lib buildvm_fold", 
                             base=JIT_HOSTDIR, incdir={JIT_SRC_DIR, TEMPDIR}, deps = ARCHH,
                             defines="LJ_ARCH_HASFPU=1 LJ_ABI_SOFTFP=0 LUAJIT_TARGET=LUAJIT_ARCH_"..
                               (make.get_flag"M32" and "x86" or "x64")
                            }
local LJ_VM   = rule {TEMPDIR.."/lj_vm.o", 
                      deps = BUILDVM,
                      action = ("%s -m peobj -o $OUTFILE"):format(BUILDVM:canonical()),
                     }
local FFDEF   = rule {TEMPDIR.."/lj_ffdef.h", 
                          src="lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c", 
                          base=JIT_SRC_DIR, deps = BUILDVM,
                          action = ("%s -m ffdef -o $OUTFILE $SOURCES"):format(BUILDVM:canonical()),
                         }
local BCDEF   = rule {TEMPDIR.."/lj_bcdef.h", 
                          src="lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c", 
                          base=JIT_SRC_DIR, deps = BUILDVM,
                          action = ("%s -m bcdef -o $OUTFILE $SOURCES"):format(BUILDVM:canonical()),
                         }
local RECDEF  = rule {TEMPDIR.."/lj_recdef.h", 
                          src="lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c", 
                          base=JIT_SRC_DIR, deps = BUILDVM,
                          action = ("%s -m recdef -o $OUTFILE $SOURCES"):format(BUILDVM:canonical()),
                         }
local LIBDEF  = rule {TEMPDIR.."/lj_libdef.h", 
                          src="lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c", 
                          base=JIT_SRC_DIR, deps=BUILDVM,
                          action = ("%s -m libdef -o $OUTFILE $SOURCES"):format(BUILDVM:canonical()),
                         }
local FOLDDEF = rule {TEMPDIR.."/lj_folddef.h", 
                          src="lj_opt_fold.c", 
                          base=JIT_SRC_DIR, deps=BUILDVM,
                          action = ("%s -m folddef -o $OUTFILE $SOURCES"):format(BUILDVM:canonical()),
                         }
local LJDEPS  = group {FFDEF, BCDEF, RECDEF, LIBDEF, FOLDDEF}
local VMDEF   = rule {TEMPDIR.."/vmdef.lua", 
                          src="lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c \z
                               lib_package.c lib_debug.c lib_jit.c lib_ffi.c", 
                          base=JIT_SRC_DIR, deps=BUILDVM,
                          action = ("%s -m vmdef -o $OUTFILE $SOURCES"):format(BUILDVM:canonical()),
                         }
--
local LUAICON = wresource {"luajit", src="icon", base=JIT_SRC_DIR, odir=TEMPDIR}                                   -- icon resources
local LUAOBJ  = c99 {"luajit", src="luajit", base=JIT_SRC_DIR, odir=TEMPDIR, from="luajit:defines", cflags=CFLAGS} -- lua program c source
local DLIBOBJ = c99 {"luajit_d", src="ljamalg", base=JIT_SRC_DIR, odir=TEMPDIR, incdir={TEMPDIR, JIT_SRC_DIR},     -- dynamic lib c source
                     deps=LJDEPS, from="luajit:defines", cflags=CFLAGS}
local SLIBOBJ = c99 {"luajit_s", src="ljamalg", base=JIT_SRC_DIR, odir=TEMPDIR, incdir={TEMPDIR, JIT_SRC_DIR},     -- static lib c source
                     deps=LJDEPS, from="luajits:defines", cflags=CFLAGS}
--
local LUALIB  = c99.library {'lua51', odir=LUA_IDIR, inputs={SLIBOBJ, LJ_VM}}                            -- static lua runtime lib
local LUADLL  = c99.shared  {'lua51', odir=LUA_BIN, inputs={DLIBOBJ, LJ_VM}}                             -- dynamic lua runtime lib
local LUAEXE  = c99.program {'luajit', odir=LUA_BIN, inputs={LUAOBJ, LUAICON, LUADLL}, needs="windows"}  -- lua executable
--
local LUAINC  = file {src="lua.h luaconf.h lualib.h lauxlib.h", base=JIT_SRC_DIR, odir=LUA_IDIR}
local LUADOC  = file {src="*", base=JIT_SRC_DIR.."/../doc", odir=LUA_ETC_DIR.."/luajit/doc"}
local LUAJIT  = file {src="*.lua", base=JIT_SRC_DIR.."/jit", odir=LUA_CDIR.."/jit", inputs=VMDEF}
--
local LUA = group {LUAEXE, LUADLL, LUALIB, LUAINC, LUAJIT, LUADOC}

target("luajit", LUA)
default(LUA)
--
define_need{'luajit',  -- luajit, dynamically linked libs
  libs          = "lua51", 
  incdir        = LUA_IDIR, 
  defines       = "LUA_BUILD_AS_DLL", 
  libdir        = LUA_BIN .. " " .. LUA_IDIR,
  prerequisites = "luajit",
  LUAVERSION    = LUA_VERSION
};

define_need{'luajits', -- luajit, statically linked libs
  libs          = "luajit",
  incdir        = LUA_IDIR, 
  libdir        = LUA_IDIR,
  prerequisites = "luajit",
  LUAVERSION    = LUA_VERSION
};
--
make.Needs "lua = luajit"   -- need alias.
make.Needs "luas = luajits" -- need alias.
