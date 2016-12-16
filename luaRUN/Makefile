# Makefile for MinGW / gcc
# Program: Glue
default: all

#========================================= [start user config] ==
# LUAVER := 51|52|53 (luaJit=51)
LUAVER	?=	53
#
# LUAROOT: your lua root folder.
LUAROOT	?=	../_install32
#
# LUAINCL: where to find lua header files and static module libraries
LUAINCL ?=	$(LUAROOT)/include/$(LUAVER)
#
# PRELOAD_MODS: names of the static lua libs to link into exe
#PRELOAD_MODS ?= lfs lpeg winapi lsqlite3 lanes.core socket.core mime.core iuplua
#PRELOAD_MODS ?= lfs lpeg winapi iuplua
PRELOAD_MODS ?= lfs lpeg winapi
#

#
#ICON	?=	lua_small
#ICON	?=	lua
ICON	?=	omm
#=========================================== [end user config] ==

E	=	@echo 
RM	= 	@del 
CC	=	@gcc
CCOPT	=	-m32 -Os -s -static

# ========================================== [preload config] ===
#
ifeq ($(strip $(PRELOAD_MODS)),)
# nothing to preload. -> link to dll's.
LUALIBS	:=	$(LUAROOT)/lua$(LUAVER).dll
CCOPT	+=	
DS_FLAG	=	D$(LUAVER)
MODS_	=
CLISTUB	=	true
GUISTUB	=	true	
else
# PRELOAD_MODS defined -> link static libs into exe.
LUALIBS :=	$(LUAROOT)/include/$(LUAVER)/lua$(LUAVER).a -lws2_32 -lpsapi -lmpr
CCOPT	+=	-DCMOD_PRELOAD -Wl,--enable-stdcall-fixup
DS_FLAG	=	S$(LUAVER)
define PRELOADDEF =
	$(file >> preloaddef.inc,LUA_API int luaopen_$(subst .,_,$(MOD)) (lua_State *L);)
endef
define PRELOAD =
	$(file >> preload.inc,  {"$(MOD)", luaopen_$(subst .,_,$(MOD))},)
endef
.PHONY: preloaddef
preloaddef:
	$(file > preloaddef.inc,)
	$(foreach MOD,$(PRELOAD_MODS),$(PRELOADDEF))
.PHONY: preload
preload:
	$(file > preload.inc,)
	$(foreach MOD,$(PRELOAD_MODS),$(PRELOAD))
MODLIBS	= $(patsubst %,$(LUAINCL)/%$(LUAVER).a,$(subst .,_,$(PRELOAD_MODS)))
MODS_	= $(LUAVERSION)$(if $(PRELOAD_MODS),_$(subst $(SPACE) ,_,$(subst _core,,$(subst .,_,$(sort $(PRELOAD_MODS))))))
ifeq "$(findstring iuplua, $(PRELOAD_MODS))" "iuplua"
  CLISTUB =
  GUISTUB =	true	
else
  CLISTUB =	true
  GUISTUB =
endif
endif
#
# ====================================== [end preload config] ===

DSRLUA	= dsrlua$(DS_FLAG)$(MODS_).exe
WSRLUA	= wsrlua$(DS_FLAG)$(MODS_).exe
DGLUE	= glue$(DS_FLAG)$(MODS_).exe
WGLUE	= wGlue$(DS_FLAG)$(MODS_).exe

.phony: all clean
all:	$(if $(PRELOAD_MODS),preloaddef preload) \
	miniglue.exe \
	$(if $(CLISTUB),$(DGLUE)) \
	$(if $(GUISTUB),$(WGLUE)) 
clean:
	$(if $(wildcard *.exe *.inc),@$(RM) $(wildcard *.exe *.inc))
	$(E) CLEAN
$(WSRLUA): loader.c $(ICON).obj $(MODLIBS) $(if $(PRELOAD_MODS),| preloaddef preload)
	$(E) EXE	$@
	$(CC) $(CCOPT) -DGUI_LOADER -I$(LUAINCL) -mwindows -o $@ $^ $(LUALIBS) \
	-lkernel32 -luser32 -lgdi32 -lwinspool -lcomdlg32 -ladvapi32 -lshell32 -luuid \
	-loleaut32 -lole32 -lcomctl32 -lpsapi -lmpr
$(DSRLUA): loader.c $(ICON).obj $(MODLIBS) $(if $(PRELOAD_MODS),| preloaddef preload) 
	$(E) EXE	$@
	$(CC) $(CCOPT) -DDOS_LOADER -I$(LUAINCL) -o $@ $^ $(LUALIBS) 
$(WGLUE): wglue.lua $(WSRLUA) | miniglue.exe
	$(E) GLUE	$@
	@miniglue $(WSRLUA) wglue.lua $@
$(DGLUE): glue.lua $(DSRLUA) | miniglue.exe
	$(E) GLUE	$@
	@miniglue $(DSRLUA) glue.lua $@
miniglue.exe: miniglue.c
	$(E) EXE	$@
	$(CC) $(CCOPT) -o $@ $^
%.obj: %.rc
	$(E) RES	$@
	@windres  -F pe-i386 $^ $@
%.rc: %.ico
	$(E) RC	$@
	@echo 0  ICON "$^" > $@
