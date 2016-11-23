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
local LUAVER  = make.Needs"lua".LUAVERSION
--
if not make.Targets("iuplua"..LUAVER) then -- iuplua-3.19.1
  if make.path.isDir("iuplua") then -- module iuplua
    --
    local TEMPDIR = TEMPDIR.."/"..LUAVER
    local DLIBO;
    do -- iup
      local SRC = "iup_array.c iup_callback.c iup_dlglist.c iup_attrib.c iup_focus.c iup_font.c \z
                   iup_globalattrib.c iup_object.c iup_key.c iup_layout.c iup_ledlex.c iup_names.c \z
                   iup_ledparse.c iup_predialogs.c iup_register.c iup_scanf.c iup_show.c iup_str.c \z
                   iup_func.c iup_childtree.c iup.c iup_classattrib.c iup_dialog.c iup_assert.c \z
                   iup_messagedlg.c iup_timer.c iup_image.c iup_label.c iup_fill.c iup_zbox.c \z
                   iup_colordlg.c iup_fontdlg.c iup_filedlg.c iup_strmessage.c iup_menu.c iup_frame.c \z
                   iup_user.c iup_button.c iup_radio.c iup_toggle.c iup_progressbar.c iup_text.c iup_val.c \z
                   iup_box.c iup_hbox.c iup_vbox.c iup_cbox.c iup_class.c iup_classbase.c iup_maskmatch.c \z
                   iup_mask.c iup_maskparse.c iup_tabs.c iup_spin.c iup_list.c iup_getparam.c iup_link.c \z
                   iup_sbox.c iup_scrollbox.c iup_normalizer.c iup_tree.c iup_split.c iup_layoutdlg.c \z
                   iup_recplay.c iup_progressdlg.c iup_expander.c iup_open.c iup_table.c iup_canvas.c \z
                   iup_gridbox.c iup_detachbox.c iup_backgroundbox.c iup_linefile.c iup_config.c \z
                   iup_flatbutton.c iup_animatedlabel.c iup_draw.c \z
                   win/iupwin_common.c win/iupwin_brush.c win/iupwin_focus.c win/iupwin_font.c \z
                   win/iupwin_globalattrib.c win/iupwin_handle.c win/iupwin_key.c win/iupwin_str.c \z
                   win/iupwin_loop.c win/iupwin_open.c win/iupwin_tips.c win/iupwin_info.c \z
                   win/iupwin_dialog.c win/iupwin_messagedlg.c win/iupwin_timer.c \z
                   win/iupwin_image.c win/iupwin_label.c win/iupwin_canvas.c win/iupwin_frame.c \z
                   win/iupwin_colordlg.c win/iupwin_fontdlg.c win/iupwin_filedlg.c win/iupwin_dragdrop.c \z
                   win/iupwin_button.c win/iupwin_draw.c win/iupwin_toggle.c win/iupwin_clipboard.c \z
                   win/iupwin_progressbar.c win/iupwin_text.c win/iupwin_val.c win/iupwin_touch.c \z
                   win/iupwin_tabs.c win/iupwin_menu.c win/iupwin_list.c win/iupwin_tree.c \z
                   win/iupwin_calendar.c win/iupwin_datepick.c \z
                   win/iupwindows_main.c win/iupwindows_help.c win/iupwindows_info.c"
      local DEFINES  = "_WIN32_WINNT=0x0501 _WIN32_IE=0x600 WINVER=0x0501 NOTREEVIEW UNICODE IUP_DLL"
      if make.get_flag("DEBUG") then 
        DEFINES = DEFINES .. " IUP_ASSERT"
      end
      local SRCDIR   = LUAROOT .. "/iuplua/iup/src"
      local INCLUDES = ". ../include win ../etc"
      local NEEDS    = "windows"
      DLIBO = c99 {"iup", 
        src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, 
        defines=DEFINES, cflags=CFLAGS, needs=NEEDS
        }
    end
    --
    include "luastrip" -- load luastrip rule.
    include "bin2c"    -- load bin2c rule.
    --
    local LUA_CDIR = LUA_BIN.."/lib/"..LUAVER
    local SRCDIR   = IUPROOT.."/iup/srclua5"
    local INCLUDES = TEMPDIR.." . ../include ../src"
    local NEEDS    = "lua windows"
    local DEFINES  = "IUPLUA_USELH"
    --
    local CTRL    = "button canvas dialog colordlg clipboard filedlg fill frame hbox normalizer gridbox \z
                     item image imagergb imagergba label expander link menu multiline list separator user \z
                     submenu text toggle vbox zbox timer detachbox sbox scrollbox split spin spinbox cbox \z
                     radio val tabs fontdlg tree progressbar messagedlg progressdlg backgroundbox flatbutton \z
                     animatedlabel calendar datepick param parambox"
  
    local SRCLUA  = addprefix("elem/", addsuffix( ".lua", CTRL)).." iuplua.lua constants.lua iup_config.lua" 
    
    local STRPLUA = luastrip {base=SRCDIR, odir=TEMPDIR, src=SRCLUA} -- luastrip: imported rule
  
    local CTRLH   = bin2c {inputs=STRPLUA, base=SRCDIR, odir=TEMPDIR, outext=".lh", -- bin2c: imported rule
                           command="iuplua_dobuffer(L,(const char*)B1,sizeof(B1),%q)"
                          }
    local SRC     = "iuplua.c iuplua_api.c iuplua_draw.c iuplua_tree_aux.c iuplua_scanf.c \z
                     iuplua_getparam.c iuplua_getcolor.c iuplua_config.c " .. 
                     addprefix("elem/il_", addsuffix( ".c", CTRL))
    --
    local DLIBOBJ = c99 {"iuplua"..LUAVER, src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, 
                         defines=DEFINES, cflags=CFLAGS, needs=NEEDS, deps=CTRLH -- deps defined here explicit, because automatic ..
                        }                                                        -- include file checks do not work for generated files (yet).
    local DLIB    = c99.shared {"iuplua"..LUAVER, inputs={DLIBO,DLIBOBJ}, odir=LUA_CDIR, cflags=CFLAGS, needs=NEEDS}
    --
    target("iuplua"..LUAVER, DLIB)
    default{DLIB}
    --
  end;
end;
