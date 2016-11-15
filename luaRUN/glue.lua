
local function pr(str, ...)
  print(str:format(...));
end;

local function glue(ifilename, ofilename)
  local GLUESIG = "%%glue:L"
  local LUACSIG = "\x1bLuaR"
  local stub = nil
  local function checkexe()
    if arg[0]:sub(-4, -1) == ".exe" then
      local sfile = io.open(arg[0], "rb")
      if sfile then
        sfile:seek("end", -(8 + #GLUESIG))
        if GLUESIG == sfile:read(#GLUESIG) then
          local stublen = (string.byte(sfile:read(1))) +
                          (string.byte(sfile:read(1)) * 256) +
                          (string.byte(sfile:read(1)) * 256^2) +
                          (string.byte(sfile:read(1)) * 256^3);
          sfile:seek("set", 0)
          stub = sfile:read(stublen)
          sfile:close()
          if stub then 
            return true 
          end
        end
      end
    end
    print("error: no loader found. aborting..")
    os.exit(2)
  end
  local function linteger(num)
    local function byte(n)
      return math.floor(num / (256^n)) % 256
    end
    return string.char(byte(0),byte(1),byte(2),byte(3))
  end
  checkexe()
  ofilename = ofilename or (((ifilename:match("(.*)%.[Ll][Uu][Aa]") or 
    ifilename):match("(.*)%.[Ss][Oo][Aa][Rr]") or ofilename) .. ".exe")
  local ifile = io.open(ifilename, "rb")
  if not ifile then
    print("error: cant open '" .. ifilename .. "'.")
    os.exit(2)
  end
  local luafile = ifile:read("*a")
  ifile:close()
  local ofile = io.open(ofilename, "wb")
  ofile:write(stub)
  ofile:write(luafile)
  ofile:write(GLUESIG)
  ofile:write(linteger(#stub))
  ofile:write(linteger(#luafile))
  ofile:close()
  print(ofilename .. " written.")
end
--
local function luaVersion()
  local f = function() return function() end end;
  local t = {nil, [false]  = 'LUA5.1', [true] = 'LUA5.2', [1/'-0'] = 'LUA5.3', [1] = 'LUAJIT' };
  return t[1] or t[1/0] or t[f()==f()];
end;

if #arg == 1 or #arg == 2 then
  glue(arg[1], arg[2])
else
  local preloaded = ""
  for n, _ in pairs(package.preload) do
    preloaded = preloaded .." "..n
  end
  if preloaded == "" then
    preloaded = "<none>"
  end
  pr("glue V16/11/14 (%s)", luaVersion())
  pr("  syntax: glue <luafile> [<exefile>]")
  pr("  preloaded modules: %s", preloaded)
end
