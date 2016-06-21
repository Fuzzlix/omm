# Makefile for MinGW / gcc
# Program: Glue
default: all

#========================================= [start user config] ==
# LUAVER := 51|52|53 (luaJit=51)
LUAVER	?=	51
#
# LUAROOT: your lua root folder.
LUAROOT	?=	../_install32
#
# LUAINCL: where to find lua header files and static module libraries
LUAINCL ?=	$(LUAROOT)/include/$(LUAVER)
#
# PRELOAD_MODS: names of the static lua libs to link into exe
#PRELOAD_MODS ?= lfs lpeg wx winapi lsqlite3 lanes.core socket.core mime.core
#PRELOAD_MODS ?= lfs lpeg winapi lsqlite3 lanes.core socket.core mime.core
#PRELOAD_MODS ?= lpeg winapi socket.core mime.core
PRELOAD_MODS ?= lfs winapi lpeg
#
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
endif
# ====================================== [end preload config] ===

DSRLUA	=	dsrlua$(DS_FLAG)$(MODS_).exe
DGLUE	=	glue$(DS_FLAG)$(MODS_).exe

.phony: all clean
all:	$(if $(PRELOAD_MODS),preloaddef preload) miniglue.exe $(DGLUE)
clean:
	$(if $(wildcard *.exe *.inc),@$(RM) $(wildcard *.exe *.inc))
	$(E) CLEAN
$(DSRLUA): loader.c icon.res $(MODLIBS) $(if $(PRELOAD_MODS),| preloaddef preload) 
	$(E) EXE	$@
	$(CC) $(CCOPT) -DDOS_LOADER -I$(LUAINCL) -o $@ $^ $(LUALIBS) 
$(DGLUE): glue.lua $(DSRLUA) | miniglue.exe
	$(E) GLUE	$@
	@miniglue $(DSRLUA) glue.lua $@
miniglue.exe: miniglue.c
	$(E) EXE	$@
	$(CC) $(CCOPT) -o $@ $^
