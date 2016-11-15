/* loader.c V.16/11/14, universal Console/Win32 Loader.
 * merged ideas from;
 * - srlua.c         (Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>)
 * - lua.c           (lua5.2.3 Lua.org, PUC-Rio, Brazil (http://www.lua.org))
 * - win32_starter.c (ZBStudio (https://studio.zerobrane.com/))
 * - MS website      (https://msdn.microsoft.com/en-us/library/windows/desktop/ms683197(v=vs.85).aspx)
 *
 * Features:
 *  - all error handling done in [C] including tracebacks. No need for xpcall()
 *  - arg[] Table: arg[0] = full exe name
 *                 arg[1..n] = command line parameter
 *  - executes lua main program GLUEed to exe.
 *    fallback: minimalistic loader included in exe.
 *    see: GLUE_LOADER. If set -> compile glue ability.
 *         GLUE_LOADER increases exe size by ~0.5kB.
 *
 * tested so far with:
 * - luaJit 2.0.3
 * - lua 5.1.5
 * - lua 5.2.4
 * - lua 5.3.3
 */
#define GLUE_LOADER

#if !(defined(DOS_LOADER) || defined(GUI_LOADER))
  #warning "DOS_LOADER or GUI_LOADER not defined -> fallback to: DOS_LOADER"
#endif

#ifdef __MINGW32__
  #define _WIN32_WINNT 0x0502
#endif
#define WINDOWS_LEAN_AND_MEAN
#include <windows.h>
#include <winbase.h>
#include <stdlib.h>
#include <stdio.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#define argc __argc
#define argv __argv

// minimalistic lua loader. used in case, no glued lua chunk found.
static const char *luacode = "dofile(arg[0]:sub(1,-5)..'.lua')";

char * szAppName; //char szAppName[MAX_PATH];
#if defined(GUI_LOADER)
void printErr(const char *s, const char *h) {
  MessageBox(NULL, s, h, MB_OK|MB_ICONERROR);
}
#else
void printErr(const char *s, const char *h) {
  printf(s);
}
#endif

static int report(lua_State *L, int status) {
  if (status && !lua_isnil(L, -1)) {
    const char *msg = lua_tostring(L, -1);                        // [-0, +0, m]
    if (msg == NULL) msg = "(error object is not a string)";
    luaL_gsub(L, msg, szAppName, "");                             // [-0, +1, m]
    lua_remove(L, -2);                                            // [-1, +0, -]
    luaL_gsub(L, lua_tostring(L, -1), "\t", "  ");                // [-0, +1, m]
    lua_remove(L, -2);                                            // [-1, +0, -]
    printErr(lua_tostring(L, -1), TEXT("LUA Error"));
    lua_pop(L, 1);                                                // [-n, +0, -]
    lua_gc(L, LUA_GCCOLLECT, 0);
  }
  return status;
}

#if LUA_VERSION_NUM  == 501
static int traceback (lua_State *L) {
  if (!lua_isstring(L, 1))  /* 'message' not a string? */
    return 1;  /* keep it intact */
  lua_getfield(L, LUA_GLOBALSINDEX, "debug");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 1;
  }
  lua_getfield(L, -1, "traceback");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 2);
    return 1;
  }
  lua_pushvalue(L, 1);  /* pass error message */
  lua_pushinteger(L, 2);  /* skip this function and traceback */
  lua_call(L, 2, 1);  /* call debug.traceback */
  return 1;
} 
#else
static int traceback (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg)
    luaL_traceback(L, L, msg, 1);
  else if (!lua_isnoneornil(L, 1)) {  /* is there an error object? */
    if (!luaL_callmeta(L, 1, "__tostring"))  /* try its 'tostring' metamethod */
      lua_pushliteral(L, "(no error message)");
  }
  return 1;
}
#endif

#ifdef GLUE_LOADER
#define GLUESIG     "%%glue:L"
#define GLUELEN     (sizeof(GLUESIG)-1)
#define GLUETYP     (sizeof(GLUESIG)-2)
typedef struct { char sig[GLUELEN]; long size1, size2; } Glue;
typedef struct { FILE *f; long size; char buff[512]; } State;

Glue  GlueInfo; 
State S;

static int glue_found() {
  S.f = fopen(szAppName, "rb");
  if (S.f == NULL) return 0;
  if ((fseek(S.f, (long int)(-sizeof(GlueInfo)), SEEK_END) == 0) && 
      (fread(&GlueInfo, sizeof(GlueInfo), 1, S.f) == 1) && 
      (memcmp(GlueInfo.sig, GLUESIG, GLUELEN) == 0) &&
      (fseek(S.f, GlueInfo.size1, SEEK_SET) == 0))
    return 1;
  fclose(S.f);
  return 0;
}

const char* myget(lua_State *L, void *data, size_t *size) {
  State *s = data;
  size_t n;
  if (s->size <= 0) return NULL;
  n = (sizeof(s->buff) <= s->size) ? sizeof(s->buff) : s->size;
  n = fread(s->buff, 1, n, s->f);
  if (n == -1) return NULL;
  s->size -= n;
  *size = n;
  return s->buff;
}

static int loadGlue(lua_State *L) {
  if (S.f == NULL) {
    lua_pushstring(L, "cant read loader.");
    return 1;
  };
  S.size = GlueInfo.size2;
#if LUA_VERSION_NUM  == 501
  int err = lua_load(L, myget, &S, "MAIN");
#else
  int err = lua_load(L, myget, &S, "MAIN", NULL);
#endif
  fclose(S.f);
  return err;
}

#endif //GLUE_LOADER

#ifdef CMOD_PRELOAD
  #include "preloaddef.inc" 
  static const luaL_Reg preloadedlibs[] = {
  #include "preload.inc"
  {NULL, NULL}
  }; 
  LUALIB_API void preload_libs(lua_State *L) {
    const luaL_Reg *lib;
  #if LUA_VERSION_NUM  == 501
    luaL_findtable(L, LUA_REGISTRYINDEX, "_PRELOAD",
       sizeof(preloadedlibs)/sizeof(preloadedlibs[0])-1);
  #else
    luaL_getsubtable(L, LUA_REGISTRYINDEX, "_PRELOAD");
  #endif
    for (lib = preloadedlibs; lib->func; lib++) {
      lua_pushcfunction(L, lib->func);
      lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);
  }
#else
  #define preload_libs(L) 
#endif

int main() {
	szAppName = _pgmptr; //GetModuleFileName(NULL, szAppName, MAX_PATH);
  lua_State *L = luaL_newstate();
  if (L != NULL) {
    luaL_openlibs(L);
    preload_libs(L); // preload statically linked lua libs
    // filling arg table ...
    lua_createtable(L, argc, 0);
    lua_pushstring(L, szAppName); // [-0, +1, m]
    lua_rawseti(L, -2, 0); // arg[0] = full exe_name
    int i;
    for (i = 1; i < argc; i++) { // command line arguments
      lua_pushstring(L, argv[i]);
      lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");
    //
    int status = 0; // no error
#ifdef GLUE_LOADER
    if (glue_found())
      status = loadGlue(L);
    else
#endif //GLUE_LOADER
    status = luaL_loadbuffer(L, luacode, strlen(luacode), "BOOT"); 
    if (status == 0) {
      int base = lua_gettop(L);
      lua_pushcfunction(L, traceback);
      lua_insert(L, base);                            // [-1, +1, -]
      status = lua_pcall(L, 0, 0, base); 
      lua_remove(L, base);                            // [-1, +0, -]
    };
    report(L, status);
    lua_close(L);
  } else {
    printErr("Couldn't initialize a luastate", TEXT("Initialization failure"));
  };
  return 0;
}

#if defined(GUI_LOADER)
int WINAPI WinMain(HINSTANCE hInstance,  HINSTANCE hPrevInstance,  LPSTR lpCmdLine, int nCmdShow) {
  return main();
}
#endif
