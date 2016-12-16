--[[--
 Lua Module Catenation.
 Creates one single lua file preloading all lua modules.  
 Usefull to create stand alone lua programs.  

 **Required Modules:** lpeg os.cmdl
]]
local VERSION = "GLUE Version 16/12/09 (%s)";
local USAGE = ([=[
* command line syntax: 
    XXXX [<options>] [<infile> [<outfile>]]
* <options> :
%s
]=]):gsub("XXXX",arg[0]:match("([^\\]*)%.+.*"));

local insert, concat, remove = table.insert, table.concat, table.remove;

package.preload["Cmdl"] = function(...)
  local insert, concat = table.insert, table.concat;
  --
  local function split(s, re)
    if type(s) ~= "string" then return s; end;
    local i1 = 1;
    local ls = {};
    re = re or '%s+';
    while true do
      local i2, i3 = s:find(re, i1);
      if not i2 then
        insert(ls, s:sub(i1));
        return ls;
      end;
      insert(ls, s:sub(i1, i2 - 1));
      i1 = i3 + 1;
    end;
  end;
  
  local cmdl = arg or {};
  --[[ Parse command line parameters.
   input:   argv, argsd,     
   default: arg,  cmdl.argsd,
     argv - array of command line arguments,
     argsd - array of tables, each table describes a single command, and its fields:
       tag - short tag used as parameter key in results table,
       cmd - commands synonyms array e.g. {'-h','--help','/?'},
       descr - command description (used to generate help text),
       def - list of default values, when the switch is found without parameters. 
       default - list of default values to use, when this switch is not found.
       multiple - if true, allows this command multiple times
                  if false the 2nd occurance creates a error. 
       params - list of command parameters descriptors, each table containing fields:
         t - parameter type: 
             str   (string - default), 
             int   (integer - bin/oct/hex/dec), 
             float (float), integer/float arguments.
         min,max - allowed numeric range (for int/float) or string length range (for strings)
         delim (char) - alows multiple values in one parameter separated by <char>.
                        this cmd alows 1 parameter definitions only.
         re - regexp used to check string parameter,
         vals - list of possible parameter values,
  returns:
    error: nil, string:error message
    ok:    table:args
             - table of parsed parameters in the form 
               {tag={value[,valuem...]}}.
  --]]
  cmdl.parse = function(argv, argsd)
    local result = {};
    -- use default parameters, if no parameter given ..
    argv, argsd = argv or arg, argsd or cmdl.argsd;
    --
    local argc, err;
    local othercnt = 1;
    local shortParamNames = {};
    local paramd = {}; --parameter descriptors (for faster search)
    -- fill paramd & shortParamNames list...
    for _, descr in ipairs(argsd) do
      for _, cmd in pairs(descr.cmd) do
        if cmd:match"^%-[^%-]" then insert(shortParamNames, cmd); end; --remember short params
        paramd[cmd] = descr;
      end;
    end;
    -- sort shortParamNames
    table.sort(shortParamNames, function(a, b) return ((#a == #b) and a < b) or #a > #b; end);
    --
    local function switch(str, others)
      if not str then return; end;
      local cmd, argd, val;
      -- long arg test
      cmd, val = str:match"^(%-%-[^=%s]+)[=]?(.*)";
      -- short arg test
      if not cmd and str:match"^%-[^%-]" then 
        for _, sw in ipairs(shortParamNames) do
          sw = sw:gsub("([%-%?])","%%%1");
          if str:match("^"..sw) then
            cmd, val = str:match("^("..sw..")(.*)$"); 
            val = val and #val > 0 and val or nil;
            break;
          end;
        end;
      end;
      -- prepare result
      argd = paramd[cmd];
      -- no result: others arg test
      if not argd and others then
        others = others[othercnt];
        if others.multiple or (#others.params == 1 and others.params[1].delim) then 
          return others, str; 
        end;
        othercnt = othercnt + 1;
        return others, str;
      end;
      val  = val and #val > 0 and val or nil;
      return argd, val;
    end;
  
    local function blocked(argd)
      if argd and argd.blockedby then
        for _, sw in ipairs(argd.blockedby) do
          if result[sw] then
            err = argc;
            return true;
          end;           
        end;
      end;
      return false;
    end;
  
    local function storeValue(argd, str)
      local function value_ok(val, paramd)
        if paramd.t == 'int' then -- parameter is int
          -- determine number base
          local base = 10
          local baseChar = val:match('^0([bBoOdDxX])')
          if baseChar then -- 0x base given
            baseChar = baseChar:lower()
            if baseChar == 'b' then base = 2 -- binary
            elseif baseChar == 'o' then base = 8 -- octal
            elseif baseChar == 'd' then base = 10 -- decimal
            elseif baseChar == 'x' then base = 16 -- hexadecimal
            end
            val = val:sub(3, -1) -- extract numeric part
          end;
          val = tonumber(val, base); -- convert to number
          if val then -- no error during conversion - check min/max
            -- min/max given - check
            if ((paramd.min) and (val < paramd.min)) or
               ((paramd.max) and (val > paramd.max)) then 
              return; 
            end;
          end;
        elseif paramd.t == 'float' then -- parameter is float
          val = tonumber(val) -- convert to number
          if val then
            -- min/max given - check
            if ((paramd.min) and (val < paramd.min)) or
               ((paramd.max) and (val > paramd.max)) then 
              return; 
            end;
          end;
        else  -- parameter is string
          if paramd.re then -- check with regexp if given
            local m = val:match(paramd.re);
            if (m == nil) or (#m ~= #val) then return; end;
          end;
          if val then
            -- check for min/max string length
            if ((paramd.min) and (#val < paramd.min)) or
               ((paramd.max) and (#val > paramd.max)) then 
              return; 
            end;
          end;
        end;
        -- check for allowed values list
        if paramd.vals then 
          for _, _val in pairs(paramd.vals) do
            if val == _val then return val; end;
          end;
          -- value not found in values array - error
          return;
        end;
        return val;
      end;
      --
      if str then
        -- switch takes parameters?
        if not argd.params then err = argc; return; end;
        result[argd.tag] = result[argd.tag] or {};
        local result = result[argd.tag];
        -- switch takes one parameter multiple times?
        if #argd.params == 1 and argd.params[1].delim then
          local strl = split(str, argd.params[1].delim);
          for _, _str in ipairs(strl) do
            _str = value_ok(_str, argd.params[1])
            if _str then
              insert(result, _str);
            else
              err = argc;
              return;
            end;
          end;
          return;
        end;
        -- switch takes one parameter?
        if #argd.params == 1 then
          str = value_ok(str, argd.params[1])
          if str then
             insert(result, str);
          else
            err = argc;
          end;
          return;
        end;
        -- switch takes multiple parameter?
        if #argd.params > 1 then
          local strl = split(str, argd.delim);
          if #argd.params ~= #strl then err = argc; return; end;
          local res = {};
          for i = 1, #argd do
            strl[i] = value_ok(strl[i], argd.params[i])
            if strl[i] then
              insert(res, strl[i]);
            else
              err = argc;
              return
            end;
          end;
          if argd.multiple then
            insert{result, res};
          else
            for _, v in ipairs(res) do
              insert(result, v);
            end;
          end;
          return;
        end;
        --error("This should not happen here.");
      elseif argd.params then
        if argd.params.def then
          result[argd.tag] = argd.params.def;
        else
          err = math.min(argc, #argv);
        end;
      else
        result[argd.tag] = {true};
      end;
    end;
    
    -- scanning loop
    argc = 1;
    local nxtargd, nxtval;
    while (argc <= #argv) do
      local argd, val;
      argd, val, nxtargd, nxtval = nxtargd, nxtval; -- shift
      -- expand next switch, if nessesary
      if not argd then argd, val = switch(argv[argc], argsd.others); end;
      if blocked(argd) then 
        err = argc;
        break;
      end;
      if val then -- value attached to switch ...
        if argd.params then
          storeValue(argd, val);
        else
          err = argc;
        end;
      elseif not argd.params then
        storeValue(argd, nil);
      elseif  argd.params then
        nxtargd, nxtval = switch(argv[argc+1]);
        if not nxtargd then 
          argc = argc + 1;
          storeValue(argd, argv[argc]);
        else
          storeValue(argd);
        end;
      end;
      if err then break; end;
      argc = argc + 1;
    end;
    -- handle errors
    if err then  -- generate error message
      local msg = "";
      for i = 1, #argv do
        if i == err then 
          msg = msg .. " [?> ".. argv[i] .." <?]";
        else
          msg = msg .. " " .. argv[i];
        end;
      end
      return nil, msg;  -- error, error message
    end;
    -- fill in default values for ommited parameters.
    for _, _argd in ipairs(argsd) do
      if _argd.default and result[_argd.tag] == nil then
        result[_argd.tag] = _argd.default;
      end;
    end;
    -- flatten result list for simple parameters...
    for _, _argd in ipairs(argsd) do
      if result[_argd.tag] and (not _argd.params or (#_argd.params == 1 and 
          not (_argd.multiple or _argd.params[1].delim))) then
        result[_argd.tag] = result[_argd.tag][1] or true;
      end;
    end;
    --
    return result;
  end;
  
  -- generates help text from description table
  cmdl.help = function(indent)
    local result = {};
    indent = indent or 0;
    if not cmdl.argsd then error("cmdl.help() - no parameter definition found."); end;
    for _, arg in ipairs(cmdl.argsd) do
      local cmdl = string.rep(" ", indent);
      for _, cmd in ipairs(arg.cmd) do
        cmdl = cmdl .. cmd .. ', ';
      end
      cmdl = cmdl:sub(1, -3);
      if arg.params then
        cmdl = cmdl .. '=';
        for _, param in ipairs(arg.params) do
          if param.values then -- show list of values
            cmdl = cmdl .. "";
            for _, v in ipairs(param.values) do cmdl = cmdl .. v .. '|' end;
            cmdl = cmdl:sub(1,-2) .. ' ';
          elseif param.min or param.max then -- show min/max
            cmdl = cmdl..'['
            if param.min then cmdl = cmdl .. param.min end;
            cmdl = cmdl .. '..';
            if param.max then cmdl = cmdl .. param.max end;
            cmdl = cmdl .. '] ';
          else -- else show parameter type
            local t = param.lbl or param.t or 'str';
            --t = t:upper();
            cmdl = cmdl .. t;
            if param.delim then 
              cmdl = cmdl .. "{" .. param.delim .. t .. "}";
            end;
          end;
        end;
      else
        cmdl = cmdl .. ' ';
      end;
      insert(result, {cmdl, arg.descr});
    end;
    local maxlen = 0;
    for _, t in ipairs(result) do 
      if #t[1] > maxlen then maxlen = #t[1]; end;
    end;
    for i, t in ipairs(result) do 
      result[i] = t[1] .. string.rep(" ", maxlen - #t[1]) .. " " .. t[2]; 
    end;
    return concat(result,"\n");
  end;
  --
  return cmdl;
end;
--
local cmdl     = require "Cmdl";
local lpeg     = require "lpeg";
lpeg.setmaxstack(200);       -- default: 100
local locale   = lpeg.locale();
local P, S, V  = lpeg.P, lpeg.S, lpeg.V;
local C, Cb, Cc, Cg, Cs, Cmt, Ct = lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Cmt;
local EOL, ANY = P"\n", P(1);
local EOF, BOF = P(-1), lpeg.P(function(s, i) return (i == 1) and i end);
local SPACE    = locale.space;
local DIGIT    = locale.digit;
local ALPHA    = locale.alpha + P"_";
local ALPHANUM = ALPHA + DIGIT;
local SHEBANG  = P"#" * (ANY - EOL)^0 * EOL;
local function K(w) 
  return P(w) * -ALPHANUM; 
end;
local args;                  -- command line args from os.cmdl.parse()
local tblLuaMods       = {}; -- required lua modules.
local tblOtherMods     = {}; -- unknown modules.
local tblBuiltinMods   = {   -- list of built in modules.
  _G        = true,
  coroutine = package.loaded["coroutine"] and true, 
  debug     = package.loaded["debug"]     and true, 
  io        = package.loaded["io"]        and true, 
  math      = package.loaded["math"]      and true, 
  os        = package.loaded["os"]        and true, 
  package   = package.loaded["package"]   and true, 
  string    = package.loaded["string"]    and true, 
  table     = package.loaded["table"]     and true, 
  utf8      = package.loaded["utf8"]      and true,
  bit32     = package.loaded["bit32"]     and true,
  jit       = package.loaded["jit"]       and true,
  };
local tblExcludedMods  = setmetatable({},{__index = tblBuiltinMods}); -- excluded modules
local tblIncludedMods  = {}; -- manually included modules
local tblPreloadedMods = {}; -- already preloaded modules.
local sources          = {};
local stripping;             -- true in pass2: generating amalgam

local function get_module_name(s) return s end; -- forward declaration
local function GMN(s) return get_module_name(s) end;
local function GPN(s)        -- get preloaded name
  if not stripping then
    tblPreloadedMods[s] = true;
    tblLuaMods[s] = nil;
  end
  return s;
end;
local function strip_spc(s)
  if stripping then return " " end
  return s;
end;
local function stripall(s)
  if stripping then return "" end
  return s;
end;

local PARSER = Cs{
  "chunk";
  spc = (SPACE + V"comment")^0 / stripall;
  space = ((SPACE + V"comment")^1 / strip_spc)^0;
  longstring = (P"[" * Cg((P"=")^0, "init") * P"[") *            
               (ANY - (Cmt((P"]" * C((P"=")^0) * "]") * Cb"init",
                           function (s,i,a,b) return a == b end)))^0 *
               (P"]" * (P"=")^0 * P"]");                         
  comment = (P"--" * V"longstring") +
            (P"--" * (ANY - EOL)^0);
  Name = ALPHA * ALPHANUM^0 - ( 
             K"and" + K"break" + K"do" + K"else" + K"elseif" +
             K"end" + K"false" + K"for" + K"function" + K"goto" + K"if" +
             K"in" + K"local" + K"nil" + K"not" + K"or" + K"repeat" +
             K"return" + K"then" + K"true" + K"until" + K"while");
  Number = (P"-")^-1 * V"spc" * P"0x" * locale.xdigit^1 * -ALPHANUM +
           (P"-")^-1 * V"spc" * DIGIT^1 *
               (P "." * DIGIT^1)^-1 * (S "eE" * (P "-")^-1 *
                   DIGIT^1)^-1 * -ALPHANUM +
           (P"-")^-1 * V "spc" * P "." * DIGIT^1 *
               (S "eE" * (P "-")^-1 * DIGIT^1)^-1 * -ALPHANUM;
  String = P'"' * (P"\\" * ANY + (1 - P'"'))^0 * P'"' +
           P"'" * (P"\\" * ANY + (1 - P"'"))^0 * P"'" +
           V"longstring";
  chunk = ((SHEBANG)^-1 / "") * V"spc" * (V"preload" * V"spc")^0 * V"block" * V"spc" * EOF;
  preload = P"package.preload[" * V"preloaded" * P"]" * V"spc" * P"=" * V"spc" * P"function(...)" * 
            V"spc" *  V"block" * V"space" * K"end" * V"space" * P";";
  preloaded = P'"' * ((1 - P'"')^1 / GPN) * P'"' +
              P"'" * ((1 - P"'")^1 / GPN) * P"'";
  block = (V"stat" * ((V"spc" * P";" * V"spc") + V"space"))^0;
  stat = P";" * V"spc" +
         P"::" * V"spc" * V"Name" * V"spc" * P"::" +
         K"break" +
         K"goto" * V"space" * V"Name" +
         K"do" * V"space" * V"block" * V"space" * K "end" +
         K"while" * V"space" * V"expr" * V"space" * K "do" * V"space" *
             V"block" * V"space" * K"end" +
         K"repeat" * V"space" * V"block" * V"space" * K"until" *
             V"space" * V"expr" +
         K"if" * V"space" * V"expr" * V"space" * K"then" *
             V"space" * V"block" * V"space" *
             (K"elseif" * V"space" * V"expr" * V"space" * K"then" *
              V"space" * V"block" * V"space")^0 *
             (K"else" * V"space" * V"block" * V"space")^-1 * K"end" +
         K"for" * V"space" *
             ((V"Name" * V"spc" * P"=" * V"spc" *
               V"expr" * V"spc" * P"," * V"spc" * V"expr" *
               (V"spc" * P"," * V"spc" * V"expr")^-1) +
              (V"namelist" * V"space" * K"in" * V"space" * V"explist")
             )* V"space" * K"do" * V"space" * V"block" * V"space" * K"end" +
         K"return" * (V"space" * V"explist")^-1 +
         K"function" * V"space" * V"funcname" * V"spc" *  V"funcbody" +
         K"local" * V"space" * (
           (K"function" * V"space" * V"Name" * V"spc" * V"funcbody") +
           (V"namelist" * (V"spc" * P"=" * V"spc" * V"explist")^-1)) +
         V"varlist" * V"spc" * P"=" * V"spc" * V"explist" +
         V"functioncall";
  funcname = V"Name" * (V"spc" * P"." * V"spc" * V"Name")^0 *
                (V"spc" * P":" * V"spc" * V"Name")^-1;
  namelist = V"Name" * (V"spc" * P"," * V"spc" * V"Name")^0;
  varlist = V"var" * (V"spc" * P"," * V"spc" * V"var")^0;
  value = K"nil" + K"false" + K"true" + P"..." +
          V"Number" + V"String" * V"spc" +
          V"functiondef" + V"tableconstructor" +
          V"functioncall" + V"var" +
          P"(" * V"spc" * V"expr" * V"spc" * P")" * V"spc";
  expr = V"unop" * V"spc" * V"expr" +
         V"value" * (V"binop" * V"expr")^-1;
  index = P"[" * V"spc" * V"expr" * V"spc" * P"]" +
          P"." * V"spc" * V"Name";
  call = V"args" +
         P":" * V"spc" * V"Name" * V"spc" * V"args";
  prefix = P"(" * V"spc" * V"expr" * V"spc" * P")" +
           V"Name";
  suffix = V"call" + V"index";
  var = V"prefix" * (V"spc" * V"suffix" * #(V"spc" * V"suffix"))^0 * V"spc" * V"index" +
        V"Name";
  -- <require>
  moduleargs = -- capture constant module names
               V"modulename" + P"(" * V"spc" * V"modulename" * V"spc" * P")" +
               -- cant capture calculated module names
               P"(" * V"spc" * V"explist" * V"spc" * P")"; 
  modulename = P'"' * ((1 - P'"')^0 / GMN) * P'"' +
               P"'" * ((1 - P"'")^0 / GMN) * P"'";
  -- </require>
  functioncall = -- <require>
                 K"require" * V"space" * V"moduleargs" * (
                    V"spc" * P"." * V"spc" * V"Name" +
                    V"spc" * (V"args" + V"index"))^0 +
                 -- </require>
                 V"prefix" * (V"spc" * V"suffix" * #(V"spc" * V"suffix"))^0 * V"spc" * V"call";
  explist = V"expr" * (V"spc" * P"," * V"spc" * V"expr")^0;
  args = P"(" * V"spc" * (V"explist" * V"spc")^-1 * P")" +
         V"tableconstructor" +
         V"String";
  functiondef = K"function" * V"spc" * V"funcbody";
  funcbody = P"(" * V"spc" * (V"parlist" * V"spc")^-1 * P")" * V"spc" *  V"block" * V"space" * K"end";
  parlist = V"namelist" * (V"spc" * P"," * V"spc" * P"...")^-1 +
            P"...";
  tableconstructor = P"{" * V"spc" * (V"fieldlist" * V"spc")^-1 * P"}";
  fieldlist = V"field" * (V"spc" * V"fieldsep" * V"spc" * V"field")^0 * (V"spc" * V"fieldsep")^-1;
  field = V"spc" * P"[" * V"spc" *V"expr" * V"spc" * P"]" * V"spc" * P"=" * V"spc" * V"expr"
          + V"space" * V"Name" * V"spc" * P"=" * V"spc" * V"expr" 
          + V"expr";
  fieldsep = V"spc" * (P"," + P ";") * V"spc";
  binop = V"space" * (K"and" + K"or") * V"space" +
          V"spc" * (P".." + P"<=" + P">=" + P"==" + P"~="
                    + P"//" + P">>" + P"<<" + P"~"
                    + P"|" + P"+" + P"-" + P"*" + P"/"
                    + P"^" + P"%" + P"&" + P"<" + P">" ) * V"spc";
  unop  = V"space" *K"not" * V"space" +
          V"spc" * (P"-" + P"~" + P"#") * V"spc";
};

function assert(cond, msg, ...)
  if cond then return cond end;
  assert(msg, 'assertion failed.');
  io.stderr:write(" *ERROR: " .. msg:format(...) .. "\n");
  os.exit(1);
end;

local function pairsByKey(t)
  local a = {}
  for n in pairs(t) do 
      a[#a + 1] = n 
    end;
  table.sort(a, function(a, b)
        return (type(a) == type(b)) and (a < b) or (type(a) < type(b))
      end);
  local i = 0         -- iterator variable
  return function()   -- iterator function
    i = i + 1
    return a[i], a[i] and t[a[i]]
  end;
end;

local function filetype(fn, ext)
  ext = ext:lower();
  if ext:sub(1,1) ~= "." then ext = "." .. ext end;
  return fn:sub(-#ext):lower() == ext;
end;

local function is_exe(fn)
  return filetype(fn, ".exe");
end;

local function is_gc(fn)
  return filetype(fn, ".gc");
end;

local function defaultext(fn, ext)
  if not fn:match("%.%w*$") then
    fn = fn .. ext;
  end
  return fn;
end;

local function locate_module(s) end; -- forward declaration

local function scan_file(fn, mn)
  mn = mn or 0;
  local t = {};
  function get_module_name(s)
    insert(t, s);
    return s;
  end;
  local f = assert(io.open(fn), 'cant open "' .. fn .. '".');
  sources[mn] = PARSER:match(f:read("*a"));
  f:close();
  if not sources[mn] then
    print('* syntax error in file "' .. fn ..'".');
    return;
  end
  for _, n in ipairs(t) do locate_module(n); end;
  return;
end;

function locate_module(s)
  if (type(s) ~= "string") or tblLuaMods[s] or tblExcludedMods[s] or tblOtherMods[s] or tblPreloadedMods[s] then 
    return 
  end;
  local f, n;
  for p in package.path:gsub("\\","/"):gmatch("([^;]+);") do
    p = p:gsub("?",s);
    f = io.open(p);
    if f then 
      n = p; 
      f:close();
      break;
    end
  end;
  if n then
    tblLuaMods[s] = n;
    scan_file(n, s);
    return;
  else
    tblOtherMods[s] = (package.preload[s] and "preloaded") or "?";
  end
  return;
end;

local function create_amalgam(sources)
  local t = {sources[0]}; -- main source
  sources[0] = nil;
  for m, fn in pairsByKey(tblLuaMods) do
    insert(t, #t, 'package.preload["'.. m .. '"] = function(...)\n');
    insert(t, #t, sources[m]);
    insert(t, #t, "\nend; -- module " .. m .. " \n");
    sources[m] = nil;
  end;
  local s = concat(t)
  if args.strip then
    stripping = true;
    local s1 = #s;
    s = PARSER:match(s)
    local s2 = #s;
    print("- strip result.....: "..string.format("%i / %i => %2.1f%% saved.", s1, s2, (1.0 - (s2/s1)) * 100.0));
  end
  return s;
end;

local function pml(ps, mt)
  local size = 79 - #ps;
  local s = "";
  local t = {};
  for k, v in pairsByKey(mt) do insert(t, k) end;
  if #t > 0 then 
    local x = 0;
    for i = 1, #t do
      if (#ps + #s + #t[i]) > size then 
        print(ps .. s);
        ps = string.rep(" ",#ps);
        s = "";
      end
      if #s > 0 then s = s..", " end;
      s = s .. t[i];
    end
    print(ps .. s);
  end
end;

local function print_status()
  pml("- already preloaded: ", tblPreloadedMods);
  pml("- lua modules......: ", tblLuaMods);
  pml("- excluded modules.: ", tblExcludedMods);
  pml("- included modules.: ", tblIncludedMods);
  pml("- non lua modules..: ", tblOtherMods);
end;

local function find_loader()
  local function anystub()
    local function exestub(fn)
      local GLUESIG = "%%glue:L";
      local LUACSIG = "\x1bLuaR";
      local stub;
      --fn = fn or arg[0];
      if is_exe(fn) then
        local sfile = assert(io.open(fn, "rb")); --TODO
        sfile:seek("end", -(8 + #GLUESIG));
        if GLUESIG == sfile:read(#GLUESIG) then
          local stublen = (string.byte(sfile:read(1))) +
                          (string.byte(sfile:read(1)) * 256) +
                          (string.byte(sfile:read(1)) * 256^2) +
                          (string.byte(sfile:read(1)) * 256^3);
          sfile:seek("set", 0);
          stub = assert(sfile:read(stublen)); --TODO
          sfile:close();
          return stub, fn; 
        end
      end
      return nil;
    end;
    --
    local stub, stubname;
    if args.srlua_exe then
      stub, stubname = exestub(args.srlua_exe);
    else
      stub, stubname = exestub(arg[0]);
    end
    return stub , stubname;
  end;
  --
  local stub, stubname = anystub();
  assert(stub, "can't find a loader.");
  print('- using loader in    "' .. stubname ..'".');
  return stub;
end;

local function glue(source)
  local GLUESIG = "%%glue:L"
  local LUACSIG = "\x1bLuaR"
  local function linteger(num)
    local function byte(n)
      return math.floor(num / (256^n)) % 256
    end
    return string.char(byte(0),byte(1),byte(2),byte(3))
  end;
  local stub = find_loader();
  return concat({stub, source, GLUESIG, linteger(#stub), linteger(#source)});
end;

local function luaVersion()
  local f = function() return function() end end;
  local t = {nil, [false]  = 'LUA5.1', [true] = 'LUA5.2', [1/'-0'] = 'LUA5.3', [1] = 'LUAJIT' };
  return t[1] or t[1/0] or t[f()==f()];
end;

local function printhelp()
  print(USAGE:format(cmdl.help(4)));
  local t = {};
  package.preload["Cmdl"] = nil; -- already required
  pml("* preloaded modules: ", package.preload);
  os.exit();
end;
--
do
  print(VERSION:format(luaVersion()));
  --
  cmdl.argsd = { 
    { tag = "srlua_exe", 
      cmd = {'-l'}, 
      descr = 'exe file to extract the loader from.',
      blockedby = {"srlua_mod", "help"},
      params = {{re = '^[%w%._/\\\\:]*$'}}
    },
    { tag = "strip", 
      cmd = {'-s'}, 
      descr = 'strip comments', 
      blockedby = {"help"},
    },
    { tag = "include", 
      cmd = {'-i'}, 
      descr = 'include module(s).',
      blockedby = {"help"},
      multiple = true;
      params = {
                 {
                 re = '^[%w%._]*$',
                 delim = ','
                 }
               }
    },
    { tag = "exclude", 
      cmd = {'-x'}, 
      descr = 'exclude module(s). (overrides -i)',
      blockedby = {"help"},
      multiple = true;
      params = {
                 {
                 re = '^[%w%._]*$',
                 delim = ','
                 }
               }
    },
    { tag = "help", 
      cmd = {'-h','-?'}, 
      blockedby = {"srlua_mod", "srlua_exe", "strip", "include", "exclude", "infile", "outfile" },
      descr = 'show help screen'
    },
    others = {
      { tag = "infile",
        blockedby = {"help"},
        params = {{re = '^[%w%._/\\\\: ]*$'}}
      },
      { tag = "outfile",
        blockedby = {"help"},
        params = {{re = '^[%w%._/\\\\: ]*$'}}
      },
    },
  };
  -- 
  local err;
  args, err = cmdl.parse();
  assert(args, "(in parameter):", err);
  --require"d"(args);
  if args.help or (#arg == 0) then  printhelp() end;
  assert(args.infile, "no source file given.");
  args.infile = args.infile[1]
  args.outfile = args.outfile and args.outfile[1] or nil;
  if args.infile == "." then args.infile = "glue.gc" end;
  args.infile = defaultext(args.infile, ".gc");
  if is_gc(args.infile) then -- read config file ..
    if #arg > 1 then printhelp() end;
    local cf = assert(io.open(args.infile), 'cant open "'.. args.infile ..'".');
    local s = cf:read("a*"):gsub("\n", " ");
    cf:close();
    local i = 1;
    for cs in s:gmatch("[^%s]+") do
      arg[i] = cs;
      i = i + 1;
    end;
    ok, args = os.cmdl.parse();
    assert(ok, "(in parameter file):", args);
  end
  assert(args.infile, "no source file given.");
  if args.exclude then
    for _, m in ipairs(args.exclude) do
      tblExcludedMods[m] = true;
    end;
  end;
  if args.include then
    for _, m in ipairs(args.include) do
      if not tblExcludedMods[m] then tblIncludedMods[m] = true end;
    end;
  end;
  -- read main source
  scan_file(args.infile);
  if sources[0] then
    -- read manually included modules ...
    for mn in pairsByKey(tblIncludedMods) do locate_module(mn) end;
    --
    print_status();
    --
    if args.outfile then
      -- write outfile
      local of;
      sources = create_amalgam(sources);
      if is_exe(args.outfile) then
        sources = glue(sources);
        of = assert(io.open(args.outfile, "w+b"), 'cant open "' .. args.outfile .. '".');
      else
        of = assert(io.open(args.outfile, "w+"), 'cant open "' .. args.outfile .. '".');
      end;
      assert(of:write(sources), 'cant write "' .. args.outfile .. '".');
      of:close();
      print('* Done...            "' .. args.outfile .. '" created.');
    end;
  end;
end;
