--- makefile for iup, cd and im
--
if not WINDOWS then quit("We are not running on Windows?") end;
--
-----------------------------------------------------------------------------------------------
--
LUAROOT = LUAROOT or PWD
LUA_BIN = LUA_BIN or LUAROOT.."/bin" -- install dir
TEMPDIR = TEMPDIR or LUAROOT.."/tmp" -- dir for intermediate files
--
local IUPBIN = IUPBIN or LUA_BIN
local IUPROOT = IUPROOT or (LUAROOT.."/iuplua")
--
if not make.Targets "zlib" then     -- zlib-1.2.8
  local SRC      = "adler32.c crc32.c inffast.c inftrees.c uncompr.c gzclose.c gzlib.c gzread.c \z
                    gzwrite.c compress.c deflate.c infback.c inflate.c trees.c zutil.c"
  local SRCDIR   = IUPROOT .. "/zlib/src"
  local INCLUDES = "../include"
  --
  local DLIBOBJ = group {
    c99 {"zlib", src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, cflags=CFLAGS},
    wresource {"zlib", src="zlib1.rc", base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, defines="GCC_WINDRES"}
  }
  --
  local DLL = c99.shared {'zlib', inputs=DLIBOBJ, odir=IUPBIN, cflags=CFLAGS}
  --
  target("zlib", DLL)
  default{DLL}
  define_need{'zlib',  
    libs          = "zlib", 
    incdir        = SRCDIR.."/../include", 
    libdir        = IUPBIN,
    prerequisites = "zlib",
  }
end;

if not make.Targets "freetype" then -- freetype-2.6.3
  local SRC      = "autofit/autofit.c bdf/bdf.c cff/cff.c cache/ftcache.c \z
                    gzip/ftgzip.c lzw/ftlzw.c gxvalid/gxvalid.c otvalid/otvalid.c pcf/pcf.c \z
                    pfr/pfr.c psaux/psaux.c pshinter/pshinter.c psnames/psnames.c raster/raster.c \z
                    sfnt/sfnt.c smooth/smooth.c truetype/truetype.c type1/type1.c cid/type1cid.c \z
                    type42/type42.c winfonts/winfnt.c bzip2/ftbzip2.c \z
                    base/ftapi.c base/ftbbox.c base/ftbdf.c base/ftbitmap.c base/ftdebug.c \z
                    base/ftgasp.c base/ftglyph.c base/ftgxval.c base/ftinit.c base/ftlcdfil.c \z
                    base/ftmm.c base/ftotval.c base/ftpatent.c base/ftpfr.c base/ftstroke.c \z
                    base/ftsynth.c base/ftsystem.c base/fttype1.c base/ftwinfnt.c \z
                    base/ftbase.c base/ftcid.c base/ftfstype.c base/md5.c base/ftfntfmt.c"
  local SRCDIR   = IUPROOT .. "/freetype/src"
  local INCLUDES = "../include"
  local DEFINES  = "FT2_BUILD_LIBRARY FT_CONFIG_OPTION_SYSTEM_ZLIB"
  local NEEDS    = "zlib"
  --
  local DLIBOBJ = group {
    cc {"freetype", src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, cflags=CFLAGS, defines=DEFINES, needs=NEEDS},
    wresource {"freetype_res", src="freetype.rc", base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES}
  }
  local DLL = cc.shared {'freetype', inputs=DLIBOBJ, odir=IUPBIN, cflags=CFLAGS, needs=NEEDS}
  --
  target("freetype", DLL)
  default{DLL}
  define_need{'freetype',  
    libs          = "freetype", 
    incdir        = SRCDIR.."/../include", 
    libdir        = IUPBIN,
    prerequisites = "freetype",
  }
end;

if not make.Targets "im" then       -- im-3.11
  --  [[ 
  local SRCDIR = IUPROOT .. "/im/src"
  --
  local INCLUDES = "libtiff libpng libjpeg libexif liblzf"
  local SRC = "libtiff/tif_aux.c libtiff/tif_dirwrite.c libtiff/tif_jpeg.c \z
               libtiff/tif_print.c libtiff/tif_close.c libtiff/tif_dumpmode.c \z
               libtiff/tif_luv.c libtiff/tif_read.c libtiff/tif_codec.c \z
               libtiff/tif_error.c libtiff/tif_lzw.c libtiff/tif_strip.c \z
               libtiff/tif_color.c libtiff/tif_extension.c libtiff/tif_next.c \z
               libtiff/tif_swab.c libtiff/tif_compress.c libtiff/tif_fax3.c \z
               libtiff/tif_open.c libtiff/tif_thunder.c libtiff/tif_dir.c \z
               libtiff/tif_fax3sm.c libtiff/tif_packbits.c libtiff/tif_tile.c \z
               libtiff/tif_dirinfo.c libtiff/tif_flush.c libtiff/tif_pixarlog.c \z
               libtiff/tif_zip.c libtiff/tif_dirread.c libtiff/tif_getimage.c \z
               libtiff/tif_predict.c libtiff/tif_version.c libtiff/tif_write.c \z
               libtiff/tif_warning.c libtiff/tif_ojpeg.c libtiff/tif_lzma.c \z
               libtiff/tif_jbig.c \z
               \z
               libpng/png.c libpng/pngget.c libpng/pngread.c libpng/pngrutil.c libpng/pngwtran.c \z
               libpng/pngerror.c libpng/pngmem.c libpng/pngrio.c libpng/pngset.c libpng/pngwio.c \z
               libpng/pngpread.c libpng/pngrtran.c libpng/pngtrans.c libpng/pngwrite.c libpng/pngwutil.c \z
               \z
               libjpeg/jcapimin.c libjpeg/jcmarker.c libjpeg/jdapimin.c libjpeg/jdinput.c \z
               libjpeg/jdtrans.c libjpeg/jcapistd.c libjpeg/jcmaster.c libjpeg/jdapistd.c \z
               libjpeg/jdmainct.c libjpeg/jerror.c libjpeg/jmemmgr.c libjpeg/jccoefct.c \z
               libjpeg/jcomapi.c libjpeg/jdatadst.c libjpeg/jdmarker.c libjpeg/jfdctflt.c \z
               libjpeg/jmemnobs.c libjpeg/jccolor.c libjpeg/jcparam.c libjpeg/jdatasrc.c \z
               libjpeg/jdmaster.c libjpeg/jfdctfst.c libjpeg/jquant1.c libjpeg/jcdctmgr.c \z
               libjpeg/jdcoefct.c libjpeg/jdmerge.c libjpeg/jfdctint.c libjpeg/jquant2.c \z
               libjpeg/jchuff.c libjpeg/jcprepct.c libjpeg/jdcolor.c libjpeg/jidctflt.c \z
               libjpeg/jutils.c libjpeg/jdarith.c libjpeg/jcinit.c libjpeg/jcsample.c \z
               libjpeg/jddctmgr.c libjpeg/jdpostct.c libjpeg/jidctfst.c libjpeg/jaricom.c \z
               libjpeg/jcmainct.c libjpeg/jctrans.c libjpeg/jdhuff.c libjpeg/jdsample.c \z
               libjpeg/jidctint.c libjpeg/jcarith.c \z
               \z
               libexif/fuji/exif-mnote-data-fuji.c  libexif/fuji/mnote-fuji-entry.c \z
               libexif/fuji/mnote-fuji-tag.c libexif/canon/exif-mnote-data-canon.c \z
               libexif/canon/mnote-canon-entry.c libexif/canon/mnote-canon-tag.c \z
               libexif/olympus/exif-mnote-data-olympus.c libexif/olympus/mnote-olympus-entry.c \z
               libexif/olympus/mnote-olympus-tag.c libexif/pentax/exif-mnote-data-pentax.c \z
               libexif/pentax/mnote-pentax-entry.c libexif/pentax/mnote-pentax-tag.c \z
               libexif/exif-byte-order.c libexif/exif-entry.c libexif/exif-utils.c \z
               libexif/exif-format.c libexif/exif-mnote-data.c libexif/exif-content.c \z
               libexif/exif-ifd.c libexif/exif-tag.c libexif/exif-data.c libexif/exif-loader.c \z
               libexif/exif-log.c libexif/exif-mem.c \z
               \z
               liblzf/lzf_c.c liblzf/lzf_d.c \z
               \z
               im_oldcolor.c im_oldresize.c tiff_binfile.c"
  --
  local SRCCPP = "im_converttype.cpp \z
                  im_attrib.cpp im_format.cpp im_format_tga.cpp im_filebuffer.cpp \z
                  im_bin.cpp im_format_all.cpp im_format_raw.cpp im_convertopengl.cpp \z
                  im_binfile.cpp im_format_sgi.cpp im_datatype.cpp im_format_pcx.cpp \z
                  im_colorhsi.cpp im_format_bmp.cpp im_image.cpp im_rgb2map.cpp \z
                  im_colormode.cpp im_format_gif.cpp im_lib.cpp im_format_pnm.cpp \z
                  im_colorutil.cpp im_format_ico.cpp im_palette.cpp im_format_ras.cpp \z
                  im_convertbitmap.cpp im_format_led.cpp im_counter.cpp im_str.cpp \z
                  im_convertcolor.cpp im_fileraw.cpp im_format_krn.cpp im_compress.cpp \z
                  im_file.cpp im_old.cpp im_format_pfm.cpp im_format_tiff.cpp im_format_png.cpp \z
                  im_format_jpeg.cpp im_sysfile_win32.cpp im_dib.cpp im_dibxbitmap.cpp"

  local DEFINES  = "USE_EXIF"
  local MODULES  = LUAROOT .. "/iuplua/im/src"
  local NEEDS    = "windows zlib"
  INCLUDES = INCLUDES.. " . ../include"
  --
  local DLIBOBJ  = group {
    c99 {"im", src=SRC,    base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, defines=DEFINES, cflags=CFLAGS, needs=NEEDS},
    cpp {"im", src=SRCCPP, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, defines=DEFINES, cflags=CFLAGS, needs=NEEDS},
    wresource {"im_res", src="im.rc", base=SRCDIR, odir=TEMPDIR} -- resources
  }
  --
  local DYNLIB  = cpp.shared {'im', odir=IUPBIN, inputs=DLIBOBJ, needs=NEEDS}
  --
  target("im", DYNLIB)
  default{DYNLIB}
  define_need{'im',  
    libs          = "im", 
    incdir        = SRCDIR.."/../include", 
    libdir        = IUPBIN,
    prerequisites = "im",
  }
  --]]
end;


if not make.Targets "cd" then       -- cd-5.10
  -- [[
  local SRC = "cd.c wd.c wdhdcpy.c rgb2map.c cd_vectortext.c cd_active.c \z
               cd_attributes.c cd_bitmap.c cd_image.c cd_primitives.c cd_text.c cd_util.c \z
               win32/cdwclp.c win32/cdwemf.c win32/cdwimg.c win32/cdwin.c win32/cdwnative.c win32/cdwprn.c \z
               win32/cdwwmf.c win32/wmf_emf.c win32/cdwdbuf.c win32/cdwdib.c \z
               svg/base64.c svg/lodepng.c svg/cdsvg.c \z
               intcgm/cd_intcgm.c intcgm/cgm_bin_get.c intcgm/cgm_bin_parse.c intcgm/cgm_list.c \z
               intcgm/cgm_play.c intcgm/cgm_sism.c intcgm/cgm_txt_get.c intcgm/cgm_txt_parse.c \z
               drv/cddgn.c drv/cdcgm.c drv/cgm.c drv/cddxf.c drv/cdirgb.c drv/cdmf.c drv/cdps.c drv/cdpicture.c \z
               drv/cddebug.c drv/cdpptx.c drv/pptx.c \z
               minizip/ioapi.c minizip/minizip.c minizip/zip.c \z
               sim/cdfontex.c sim/sim.c sim/cd_truetype.c sim/sim_primitives.c sim/sim_text.c sim/sim_linepolyfill.c"
  local SRCDIR   = IUPROOT .. "/cd/src"
  local INCLUDES = "drv x11 win32 intcgm sim cairo svg ../include"
  local DEFINES  = "UNICODE"
  local NEEDS    = "freetype zlib windows im"
  --
  local DLIBOBJ = group{
    c99 {"cd", src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, cflags=CFLAGS, defines=DEFINES, needs=NEEDS},
    wresource {"cd_res", src="cd.rc", base=SRCDIR, incdir=INCLUDES, odir=TEMPDIR, defines="GCC_WINDRES"} -- resources
  }
  --
  local DLIB = c99.shared {'cd', odir=IUPBIN, inputs=DLIBOBJ, cflags=CFLAGS, defines=DEFINES, needs=NEEDS}
  --
  target("cd", DLIB)
  default{DLIB}
  define_need{'cd',  
    libs          = "cd", 
    incdir        = SRCDIR.."/../include", 
    libdir        = IUPBIN,
    --needs         = "im",
    prerequisites = "cd",
  }
  --]]
end;

if not make.Targets "iup" then      -- iup-3.19.1
  --  [[ 
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
  local NEEDS    = "windows cd im"
  --
  local DLIBOBJ = group {
    c99 {"iup", src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, defines=DEFINES, cflags=CFLAGS, needs=NEEDS},
    wresource {"iup_res", src="../etc/iup.rc", base=SRCDIR, odir=TEMPDIR} -- resources
  }
  --
  local MODDLL  = c99.shared  {'iup', odir=IUPBIN, inputs=DLIBOBJ, cflags=CFLAGS, needs=NEEDS}
  --
  target("iup", MODDLL)
  default{MODDLL}
  define_need{'iup',  
    libs          = "iup", 
    incdir        = SRCDIR.."/../include", 
    libdir        = IUPBIN,
    needs         = "cd im",
    prerequisites = "iup",
  }
  --]]
end;

if not make.Targets "iupcd" then    -- iupcd-3.19.1
 --  [[ 
  local SRC      = "iup_cd.c iup_cdutil.c"
  local DEFINES  = "CD_NO_OLD_INTERFACE"
  local SRCDIR   = LUAROOT .. "/iuplua/iup/srccd"
  local INCLUDES = "../include ../src"
  local NEEDS    = "iup cd windows"
  --
  local DLIBOBJ = group {
    c99 {"iup", src=SRC, base=SRCDIR, odir=TEMPDIR, incdir=INCLUDES, defines=DEFINES, cflags=CFLAGS, needs=NEEDS},
    wresource {"iupcd_res", src="../etc/iup.rc", base=SRCDIR, odir=TEMPDIR} -- resources
  }
  local DLL  = c99.shared  {'iupcd', odir=IUPBIN, inputs=DLIBOBJ, cflags=CFLAGS, needs=NEEDS}
  --
  target("iupcd", DLL)
  default{DLL}
  --]]
end;

