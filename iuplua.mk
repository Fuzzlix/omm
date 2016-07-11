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
local LUAVER   = make.Needs"lua".LUAVERSION
--
if not make.Targets("iuplua"..LUAVER) then -- iuplua-3.19.1
  -- [[
  local LUA_CDIR = LUA_BIN.."/lib/" .. LUAVER
  local SRCDIR   = IUPROOT .. "/iup/srclua5"
  local INCLUDES = ". ../include ../src lh"
  local NEEDS    = "lua iup"
  local DEFINES  = "IUPLUA_USELH"
  --
  local CTRLUA   = "button.lua canvas.lua dialog.lua colordlg.lua clipboard.lua \z
                    filedlg.lua fill.lua frame.lua hbox.lua normalizer.lua gridbox.lua \z
                    item.lua image.lua imagergb.lua imagergba.lua label.lua expander.lua \z
                    link.lua menu.lua multiline.lua list.lua separator.lua user.lua \z
                    submenu.lua text.lua toggle.lua vbox.lua zbox.lua timer.lua detachbox.lua \z
                    sbox.lua scrollbox.lua split.lua spin.lua spinbox.lua cbox.lua \z
                    radio.lua val.lua tabs.lua fontdlg.lua tree.lua progressbar.lua \z
                    messagedlg.lua progressdlg.lua backgroundbox.lua flatbutton.lua \z
                    animatedlabel.lua calendar.lua datepick.lua param.lua parambox.lua"

  local CTRC     = addprefix("elem/il_", addsuffix( ".c", basename(CTRLUA)))
        CTRLUA   = addprefix("elem/", CTRLUA)
  local SRC      = "iuplua.c iuplua_api.c iuplua_draw.c iuplua_tree_aux.c iuplua_scanf.c \z
                    iuplua_getparam.c iuplua_getcolor.c iuplua_config.c " .. CTRC
  local SRCLUA   = "iuplua.lua constants.lua iup_config.lua" 
  --
  local DLIBOBJ = c99 {"iuplua"..LUAVER, src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, defines=DEFINES, cflags=CFLAGS, needs=NEEDS}
  local DLIB    = c99.shared {"iuplua"..LUAVER, inputs=DLIBOBJ, odir=LUA_CDIR, cflags=CFLAGS, needs=NEEDS}
  --
  target("iuplua"..LUAVER, DLIB)
  default{DLIB}
  --]]
end;
