--[[-------------------------------------------------------------------------
##OMM, a lua based extensible build engine.

Inspired by and stealing code snippets from Steve Donovan's [lake][].

Using modified versions of
Roland Yonaba's [30log][] and
god6or@gmail.com's [os.cmdl][].

Required 3rd party modules:
[luafilesystem][], [winapi][] / [luaposix][]

(best viewed with a folding editor like [ZBS][].)

[lake]:          https://github.com/stevedonovan/Lake
[30log]:         https://github.com/Yonaba/30log
[os.cmdl]:       https://github.com/edartuz/lua-cmdl
[luafilesystem]: https://github.com/keplerproject/luafilesystem/
[winapi]:        https://github.com/stevedonovan/winapi
[luaposix]:      https://github.com/luaposix/luaposix/
[ZBS]:           https://github.com/pkulchenko/ZeroBraneStudio

@author Ulrich Schmidt
@copyright 2016
@license MIT/X11
--]]-------------------------------------------------------------------------
--luacheck: globals arg _DEBUG
--require "luacov"
--_DEBUG = true;
--
local VERSION = "1.0";
local MSG1 = "omm 1.0.2 (2019/08/04)\n  A lua based extensible build engine.\n";
local USAGE   = [=[
Usage: OMM [options] [target[,...]]

Options:
%s

special targets:
  * clean    delete all intermediate files.
  * CLEAN    delete all intermediate and result files.

Please report bugs to u.sch.zw@gmx.de
]=];

local MAKEFILENAME = "makefile.omm"; -- default makefile name.
local SCRIPTEXT = ".omm";
local INCLUDESCRIPTEXT = ".omi";
--
-- [] =======================================================================
--
local table_sort, io_popen, io_stderr, io_open, os_remove, os_getenv, os_tmpname, os_exit =
      table.sort, io.popen, io.stderr, io.open, os.remove, os.getenv, os.tmpname, os.exit;
local print, concat,       insert,       remove,       max,      min,      tointeger =
      print, table.concat, table.insert, table.remove, math.max, math.min, math.tointeger;
local pairs, ipairs, type, getmetatable, rawget, select, error, os_execute, package =
      pairs, ipairs, type, getmetatable, rawget, select, error, os.execute, package;
local pcall, require, loadfile, setmetatable, tonumber, setfenv, debug_getinfo =
      pcall, require, loadfile, setmetatable, tonumber, setfenv, debug.getinfo;
--
-- [] =======================================================================
--
package.preload["33log"]  = function(...) --luacheck: ignore
  local pairs, ipairs, type, getmetatable, rawget, select =
        pairs, ipairs, type, getmetatable, rawget, select;
  local setmetatable = setmetatable;
  local insert       = table.insert;

  local classes = {}; -- all classes indexed by her classname.
  
  local class;
  
  local function split(s)
    local i1 = 1;
    local ls = {};
    while true do
      local i2, i3 = s:find("%s+", i1);
      if not i2 then
        insert(ls, s:sub(i1));
        return ls;
      end;
      insert(ls, s:sub(i1, i2 - 1));
      i1 = i3 + 1;
    end;
  end;
  
  local function copy(src, dst)
    src = src or {}
    dst = dst or {};
    for k, v in pairs(src) do dst[k] = v; end;
    return dst;
  end;
   
  local function class_index(self, i)
    return rawget(getmetatable(self), i);
  end;
    
  local function class_is(self, kind)
    if not rawget(self, "__classname") then
      self = getmetatable(self);
    end;
    if type(kind) == "string" then
      kind = split(kind);
    end;
    for _, n in ipairs(kind) do
      local kMT = classes[n];
      if kMT then
        local s = self;
        while s do
          if s == kMT then
            return true;
          end;
          s = getmetatable(s);
        end;
      end;
    end;
    return false;
  end;
    
  local function isClass(...) -- ([self,] var, kind)
    local var, kind;
    if select(1, ...) == class then
      var, kind = select(2, ...);
    else
      var, kind = select(1, ...);
    end;
    if type(var) ~= "table"   then
      return false;
    end;
    if var.is ~= class_is     then
      return false;
    end;
    if not kind               then
      return true;
    end;
    if type(kind) == "string" then
      return class_is(var, kind);
    end;
    if isClass(kind)          then
      return class_is(var, kind.__classname);
    end;
    if type(kind) == "table"  then
      for _, k in ipairs(kind) do
        if isClass(var, k) then
          return true;
        end;
      end;
      return false;
    end;
    error("isClass(); wrong parameter 'kind'.", 2);
  end;

  local function class_newindex(self, field, value)
    local mt = getmetatable(self);
    if mt[field] == nil then
      rawset(self, field, value);
    else
      error(('%s field "%s" is readonly.'):format(self, field), 2)
    end;
  end;

  local function class_new(self, ...)
    if rawget(self,'__classname') == nil then error('new() should be called from a class.', 2) end;
    local instance = setmetatable({}, self);
    if self.init then
      return self.init(instance, ...);
    end;
    return instance;
  end;
  
  local function class_singleton(self, ...)
    local o = self:new(...);
    self.new = function()
      return o;
    end;
    return o;
  end;
  
  local function class_is_singleton(self)
    return self.new ~= class_new;
  end;
  
  local function class_subclass(self, name, extra_params)
    if type(name) == "table" then extra_params = name; name = nil; end;
    local newClass       = copy(extra_params, copy(self));
    newClass.__classname = name or "class#" .. #classes+1;
    newClass.super       = self;
    newClass             = setmetatable(newClass, self);
    if classes[newClass.__classname] then
      error(("subclass(): class '%s' already defined."):format(newClass.__classname), 2);
    end;
    if name then classes[name] = newClass; end;
    return newClass;
  end;
  
  local function class_protect(self)
    if rawget(self,'__classname') == nil then error('protect() should be called from a class.', 2) end;
    rawset(self, "__newindex", class_newindex);
  end;
  
  local function class_unprotect(self)
    if rawget(self,'__classname') == nil then error('unprotect() should be called from a class.', 2) end;
    rawset(self, "__newindex", nil);
  end;
  
  local function class_init(self, param)
    if type(param) == "table" then
      for n, v in pairs(param) do
        self[n] = v;
      end;
    end;
    return self;
  end;
  --
  local clBase = {
    __classname  = "base";
    __index      = class_index;
    init         = class_init;
    new          = class_new;
    singleton    = class_singleton;
    is_singleton = class_is_singleton;
    subclass     = class_subclass;
    is           = class_is;
    protect      = class_protect;
    unprotect    = class_unprotect;
  }
  --
  class = setmetatable({
    },{
      __call      = isClass;
      __index     = classes;
    }
  );
  --
  classes[clBase.__classname] = clBase;
  --
  return class;
end;

package.preload["33list"] = function(...) --luacheck: ignore
  local concat, insert, remove = table.concat, table.insert, table.remove;
  local error = error;
  --
  local class = require "33log";
  --
  local clList   = class.base:subclass("List", {
    __call = function(self) -- iterator()
      local i = 0;
      return function()
        i = i + 1;
        return self[i];
      end;
    end
  });
  
  clList.insert  = function(self, item, idx)
    if idx then
      insert(self, idx, item);
    else
      insert(self, item);
    end;
  end;
  
  clList.remove  = function(self, idx)
    remove(self, idx)
  end;
  
  clList.add     = function(self, tbl)
    if type(tbl) == "table" then
      for _, v in ipairs(tbl) do insert(self, v); end;
    end;
    return self;
  end;
  
  clList.copy    = function(self)
    return clList:new(self)
  end;
  
  clList.index   = function(self, val)
    for i, v in ipairs(self) do
      if v == val then return i end;
    end;
  end;
  
  clList.find    = function(self, field, value)
    for _, v in ipairs(self) do
      if v[field] == value then return v; end;
    end;
  end;
  
  clList.erase   = function(self, l2)
    for _, v in ipairs(l2) do
      local idx = self:index(v);
      if idx then remove(self, idx); end;
    end;
  end;
  
  clList.concat  = function(self, field, sep)
    local res = {};
    for _, o in ipairs(self) do insert(res, o[field]); end;
    return concat(res, sep or " ");
  end;
  
  --
  -- [unique list class] ==============================================
  --
  local clUList    = clList:subclass("UList", {
    __key       = 1,      -- default
    --__allowed = "base", -- default
  });
  
  clUList.init     = function(self, ...)
    clUList.super.init(self, ...);
    self.__dir = {};
    local kf = self.__key;
    for _, obj in ipairs(self) do
      if self.__dir[obj[kf]] then
        error(("<class %s> double key detected."):format(self.__classname));
      end;
      self.__dir[obj[kf]] = obj;
    end;
    return self;
  end;

  clUList.add      = function(self, item)
    local kf = self.__key or 1;
    if class(item, self.__allowed) then
      if self.__dir[item[kf]] then
        error(("cant overwrite value '%s'"):format(item[kf]));
        --return nil, self.__dir[item[kf]];
      else
        insert(self, item);
        self.__dir[item[kf]] = item;
      end;
    elseif type(item) == "table" then
      for _, v in ipairs(item) do
        self:add(v);
      end;
    else
      error("parameter needs to be a object or a list of objects.", 2);
    end;
    return self;
  end;
  
  clUList.find     = function(self, field, value)
    if type(value) == "nil" then
      return self.__dir[field];
    elseif type(field) == "nil" then
      return self.__dir[value];
    else
      return clUList.super.find(self, field, value);
    end;
  end;
  
  clUList.new_item = function(self, ...)
    local item = class.classes[self.__allowed]:new(...);
    self:add(item);
    return item;
  end;
  
  clUList.concat   = function(self, field, sep)
    return clUList.super.concat(self, field or self.__key, sep);
  end;
  --
  -- [string list class] ===============================================
  --
  local clStrList  = clList:subclass("StrList");
  
  clStrList.init   = function(self, stringlist)
    self.__dir = {};
    if stringlist then
      if type(stringlist) == "string" then
        stringlist = {stringlist};
      end;
      for _, s in ipairs(stringlist) do
        self:add(s)
      end;
    end;
    return self;
  end;
  
  clStrList.add    = function(self, item, delim)
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
    
    if type(item) == "string" then
      item = split(item, delim);
    end;
    if type(item) == "table" then
      for _, v in ipairs(item) do
        if type(v) ~= "string" then
          error("clStrList.add(): parameter needs to be a string or a list of strings.", 2);
        end;
        if #v > 0 and not self.__dir[v] then
          insert(self, v);
          self.__dir[v] = v;
        end;
      end;
    elseif item ~= nil then
      error("clStrList.add(): parameter needs to be a string or a list of strings.", 2);
    end;
    return self;
  end;
  
  clStrList.find   = function(self, value)
    return self.__dir[value];
  end;
  
  clStrList.concat = function(self, sep)
    return concat(self, sep or " ");
  end;
  --
  return class;
end;

package.preload["Cmdl"]   = function(...) --luacheck: ignore
  local insert, concat = table.insert, table.concat;
  local tonumber, table_sort = tonumber, table.sort;
  
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
    table_sort(shortParamNames, function(a, b) return ((#a == #b) and a < b) or #a > #b; end);
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
          err = min(argc, #argv);
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
      argd, val, nxtargd, nxtval = nxtargd, nxtval; --luacheck: ignore
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
-- [] =======================================================================
--
local class    = require "33log";
                 require "33list";
local lfs      = require "lfs";
local attributes, mkdir = lfs.attributes, lfs.mkdir;
--
local DIRSEP    = package.config:sub(1, 1); --luacheck: ignore
local WINDOWS   = DIRSEP == '\\' or nil;
local MAKELEVEL = 0;
local Make;
--
--=== [utils] ===============================================================
local warning, warningMF, quit, quitMF, dprint, chdir, choose, pick, split,
      shell, execute, roTable, pairsByKeys,
      luaVersion,
      winapi, posix,
      ENV, PWD, NUMCORES;
do
  local ok;
  if WINDOWS then
    ok, winapi = pcall(require, "winapi");
    if not ok then winapi = nil; end;
  else
    ok, posix = pcall(require, "posix");
    if not ok then posix = nil; end;
  end;
  --
  local update_pwd;
  --
  local dir_stack = {};
  function update_pwd()
    local dir = lfs.currentdir();
    if WINDOWS then dir = dir:lower() end;
    PWD = dir:gsub("\\", "/");
  end;
  
  function chdir(path)
    if not path then return end
    if path == '!' or path == '<' then
      lfs.chdir(remove(dir_stack))
    else
      insert(dir_stack, lfs.currentdir())
      local res, err = lfs.chdir(path)
      if not res then quitMF(err) end;
    end;
    update_pwd();
  end;
  --
  function roTable(t)
    local proxy = {}
    local mt = { -- create metatable
      __index = t;
      __newindex = function()
        quit("attempt to write a read-only table field.", 2)
      end;
    }
    setmetatable(proxy, mt)
    return proxy
  end;
  
  function pairsByKeys(t)
    local a = {};
    for n in pairs(t) do insert(a, n); end;
    table_sort(a, function(a, b)
       return (type(a) == type(b)) and (a < b)  or (type(a) < type(b))
      end
    );
    local i = 0;        -- iterator variable
    return function()   -- iterator function
      i = i + 1;
      return a[i], a[i] and t[a[i]];
    end;
  end;
   
  function choose(cond, v1, v2)
    if type(cond) == 'string' then
      cond = cond ~= '0' and cond ~= 'false'
    end;
    if cond then return v1 else return v2 end;
  end;
  
  function pick(a, b, ...)
    if a ~= nil then
      return a;
    elseif select("#", ...) == 0 then
      return b;
    else
      return pick(b, ...);
    end;
  end;
  
  function split(s, re)
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

  function shell(cmd, ...)
    cmd = cmd:format(...)
    local inf = io_popen(cmd..' 2>&1','r');
    if not inf then return '' end;
    local res = inf:read('*a');
    inf:close();
    return res:gsub('\n$','');
  end;
  
  function execute(cmd, quiet)
    -- 4 spaces at the end of the line means quiet run.
    if quiet or cmd:find("%s%s%s%s$") then
      cmd = cmd:gsub("%s*$"," > ") .. choose(WINDOWS, 'NUL', '/dev/null') .. " 2>&1";
    end
    local res1, _, res3 = os_execute(cmd)
    if type(res1) == "number" then
      return res1 == 0, res1;
    else
      return res1, res3;
    end
  end;
  
  -- debug print when `_DEBUG == true`
  function dprint(msg, ...)
    if _DEBUG then print(msg:format(...)); end;
  end;
  --
  ENV = setmetatable({}, {
      __index = function(_, key)
        return os_getenv(key)
      end;
      __newindex = function(_, key, value)
        local M = winapi or posix or quitMF("ENV[]: need winapi/posix for environment writes.");
        M.setenv(key, value);
      end;
    }
  );
  --
  update_pwd();
  --
end;

--
--=== [filename and path functions] =========================================
local fn_temp,     fn_isabs,      fn_canonical,  fn_join,     fn_isFile,
      fn_isDir,    fn_defaultExt, fn_exists,     fn_forceExt, fn_splitext,
      fn_get_ext,  fn_splitpath,  fn_ensurePath, fn_basename, fn_path_lua,
      fn_cleanup,  fn_abs,        fn_rel,        fn_which,    fn_filetime,
      fn_get_files, fn_files_from_mask, fn_get_directories;
do
  --
  function fn_temp ()
    local res = os_tmpname();
    if WINDOWS then -- note this necessary workaround for Windows
      res = ENV.TMP .. res;
    end;
    return res;
  end;
  
  function fn_isabs(path)
    return path and ((path:find '^"*%a:' or path:find '^"*[\\/]') ~= nil);
  end;
  
  function fn_canonical(p)
    if type(p) ~= 'string' then quit("canonical(): wrong parameter.", 2) end;
    if WINDOWS then
      local res;
      if p:find("%s+") then
        res = '"'..p..'"';
      else
        res = p;
      end;
      res = res:gsub('/', '\\');
      return res; --:lower();
    else
      p = p:gsub(" ", "\\ ")
      return p;
    end;
  end;

  function fn_cleanup(path)
    -- shorten path by removing ".."s.
    while path:find("/[^%./]+/%.%./") do
      path = path:gsub("/[^%./]+/%.%./", "/");
    end;
    path = path:gsub("/[^%./]+/%.%.$", "");
    path = path:gsub("/%.$", "");
    return path;
  end;
  
  function fn_join(...)
    local param = {...}
    local t = {}
    for i = 1, select("#", ...) do
      if param[i] then insert(t, param[i]) end;
    end;
    param = t;
    local idx = 1;
    -- start concatination with last absolute path ...
    for i, path in ipairs(param) do
      if fn_isabs(path) then idx = i; end;
    end;
    -- remove trailing slashes ...
    for i = idx, #param do
      local n = param[i];
      if n:sub(-1) == "/" or n:sub(-1) == "\\" then param[i] = n:sub(1, -2); end;
    end;
    --
    return fn_cleanup(concat(param, "/", idx))
  end;
  
  function fn_isFile(fname, types)
    -- types: string, eg: "directory,file"
    types = types or "file";
    local mode = attributes(fname, 'mode');
    return mode and types:find(mode) and true;
  end;
  
  function fn_isDir(fname)
    return fn_isFile(fname, "directory");
  end;
  
  function fn_defaultExt(fn, ext)
    if not fn:match("%.%w*$") then
      fn = fn .. ".".. ext:gsub("^%.","");
    end;
    return fn;
  end;

  function fn_exists(...)
    local fname = fn_join(...);
    if attributes(fname) ~= nil then return fname; end;
    return nil;
  end;
  
  function fn_forceExt(fname, ext)
    if ext then
      if #ext > 0 and (ext:sub(1,1) ~= ".") then ext = "." .. ext end;
      return fname:gsub("%.[%w_]*$", "") .. ext;
    else
      return fname;
    end;
  end;

  function fn_splitext(path)
    local i = #path;
    local ch = path:sub(i, i);
    while i > 0 and ch ~= '.' do
      if ch == '/' or ch == '\\' then return path,''; end;
      i = i - 1;
      ch = path:sub(i, i);
    end;
    if i == 0 then
      return path, '';
    else
      return path:sub(1, i - 1), path:sub(i);
    end;
  end;
  
  function fn_get_ext(path)
    local _, p2 = fn_splitext(path);
    return p2;
  end;

  function fn_splitpath(path)
    local i = #path;
    local ch = path:sub(i, i);
    while i > 0 and ch ~= '/' and ch ~= '\\' do
      i = i - 1;
      ch = path:sub(i, i);
    end;
    if i == 0 then
      return '', path;
    else
      return path:sub(1, i - 1), path:sub(i + 1);
    end;
  end;

  function fn_ensurePath(path)
    if fn_isDir(path) then return; end;
    local dirs = split(path,"/");
    local dir;
    for i = 1, #dirs do
      dir = concat(dirs, "/", 1, i);
      if fn_exists(dir) then
        if not fn_isDir(dir) then break; end;
      else
        mkdir(dir);
      end;
    end;
    return path;
  end;

  function fn_basename(path)
    local _, p2 = fn_splitpath(path);
    return p2;
  end;

  function fn_path_lua(path)
    return path:gsub("\\", "/");
  end;

  function fn_abs(path)
    if type(path) == "string" then path = {path}; end;
    if fn_isabs(path[#path]) then
      path = path[#path];
    else
      if not fn_isabs(path[1]) then insert(path, 1, PWD); end;
      path = concat(path, "/");
    end;
    path = fn_path_lua(path); -- windows paths not used inside this script
    return fn_cleanup(path);
  end;

  function fn_rel(path, base)
    path = fn_cleanup(path);
    base = fn_cleanup(base or PWD).."/";
    path = path:gsub(base,"")
    return path;
  end;

  function fn_which(prog)
    if fn_isabs(prog) then return prog end;
    if WINDOWS then -- no 'which' commmand, so do it directly
      -- use the PATHEXT environment var. This way we find executable scripts too.
      local pathext = split(ENV.PATHEXT:lower(), ';')
      if fn_get_ext(prog) ~= '' then pathext = {''}; end;
      local path = split(ENV.PATH, ';')
      for _, dir in ipairs(path) do
        dir = fn_path_lua(dir);
        for _, ext in ipairs(pathext) do
          local f = fn_exists(dir, prog..ext);
          if f then return f end;
        end;
      end;
      return false;
    else
      local res = shell('which %s 2> /dev/null', prog);
      if res == '' then return false; end;
      return res;
    end;
  end;
 
  function fn_filetime(fname)
    return attributes(fname, 'modification') or -1;
  end;
  
  function fn_get_files(path, pat, recurse, files)
    files = files or {};
    pat = "^"..pat:gsub('%.','%%.'):gsub('%*','.*')..'$';
    for file in lfs.dir(path) do
      if file ~= '.' and file ~= '..' then
        if path ~= '.' then file = fn_join(path, file) end;
        if fn_isDir(file) then
          if recurse then fn_get_files(file, pat, recurse, files); end;
        else
          local _, fn = fn_splitpath(file);
          if fn:find(pat) then insert(files, file); end;
        end;
      end;
    end;
    return files
  end;
  
  function fn_files_from_mask(mask, recurse)
    local path, pat = fn_splitpath(mask);
    if path == '' then path = '.' end;
    -- turn shell-style wildcard into Lua regexp
    --pat = "^"..pat:gsub('%.','%%.'):gsub('%*','.*')..'$';
    return fn_get_files(path, pat, recurse);
  end;
  
  function fn_get_directories(dir)
    local res = {};
    for f in lfs.dir(dir) do
      if f ~= '.' and f ~= '..' then
        local path = fn_join(dir, f);
        if fn_isDir(path) then insert(res, path); end;
      end;
    end;
    return res;
  end;
  
end;
--
do -- [os & hardware detection] =============================================
  --
  --[[--------------------------------------------------------------------
  
  Betreff:  A tricky way to determine Lua version
  Datum:  Sat, 21 May 2016 08:18:21 +0300
  Von:  Egor Skriptunoff <egor.###########@gmail.com>
  An:   Lua mailing list <lua-l@lists.lua.org>
  
  Hi!
  
  I want to share simple program that determines Lua version.
  
  local f, t = function()return function()end end, {nil,
      [false]  = 'Lua 5.1',
      [true]   = 'Lua 5.2',
      [1/'-0'] = 'Lua 5.3',
      [1]      = 'LuaJIT' }
  local version = t[1] or t[1/0] or t[f()==f()]
  
  The curious fact about this program is that it doesn't depend on anything
  that can be changed. It does not use any standard library function or any
  global variable  (as they may be withdrawn from sandboxed environment).
  It does not rely on the name of "_ENV" upvalue (as it can be renamed when
  Lua is being built).

  --]]--------------------------------------------------------------------

  function luaVersion()
    local f = function() return function() end end;
    local t = {nil, [false]  = '51', [true] = '52', [1/'-0'] = '53', [1] = 'JIT' }; --luacheck: ignore
    return t[1] or t[1/0] or t[f()==f()];
  end;
  --
  local function getCores()
    if WINDOWS then
      return ENV.NUMBER_OF_PROCESSORS or 1;
    else
      local t = fn_get_directories("/sys/devices/system/cpu");
      for i= #t, 1, -1 do
        if not t[i]:find("/cpu[%d]+$") then remove(t,i); end;
      end;
      return #t;
    end;
  end;
  NUMCORES = getCores();
  --
  dprint("  Running on Lua%s\t %s cores detected.",  luaVersion(), NUMCORES);
  --
end;
--
do -- [error handling] ======================================================
  --
  local scriptfile = arg[0];
  --
  function warning(reason, ...)
    if not Make.options or Make.options.verbose or Make.options.print_warnings then
      reason = reason or '?'
      io_stderr:write(reason:format(...), '\n')
    end;
  end;

  function warningMF(reason, ...)
    --if not Make or Make.options.verbose or Make.options.print_warnings then
      reason = reason or '?';
      local i = 0;
      local info;
      repeat
        i = i + 1;
        info = debug_getinfo(i);
      until info.short_src ~= scriptfile;
      io_stderr:write(
        ("%s:%1.0d: - "):format(fn_canonical(info.short_src), info.currentline) ..
        reason:format(...) .. "\n"
      );
    --end;
  end;

  function quit(reason, ...)
    reason = reason or '?';
    reason = reason:format(...);
    if _DEBUG then
      local idx = select("#", ...);
      local lvl = (idx == 0) and 1 or select(idx, ...);
      if type(lvl) ~= "number" then
        lvl = 2;
      else
        lvl = lvl + 1;
      end;
      local sFileLine = "";
      if lvl > 1 then
        local errtbl = debug_getinfo(lvl);
        sFileLine = ("%s:%1.0d: - "):format(fn_canonical(fn_abs(errtbl.short_src)), errtbl.currentline);
      end;
      reason = sFileLine .. reason;
    end;
    io_stderr:write(reason, '\n');
    os_exit(2);
  end;

  function quitMF(reason, ...)
    reason = reason or '?';
    local i = 0;
    local info;
    repeat
      i = i + 1;
      info = debug_getinfo(i);
    until info.short_src ~= scriptfile;
    io_stderr:write(
      ("%s:%1.0d: - "):format(fn_canonical(info.short_src), info.currentline) ..
      reason:format(...) .. "\n"
    );
    os_exit(2);
  end;
  --
end;
--
--=== [commandline parameter] ===============================================
local cmdl = require "Cmdl";
do
  cmdl.argsd = {
    { tag = "build",
      cmd = {'-B', "--build-all"},
      descr = "Unconditionally make all targets.",
      blockedby = {"printhelp", "printversion", "build"},
    },
    { tag = "makefile",
      cmd = {"-f", "--makefile"},
      descr = 'makefile to run. (default:"makefile.mk")',
      blockedby = {"printhelp", "printversion", "makefile"},
      params = { {
                 lbl = "FILE",
                 re = '^[%w%._/\\:]+$',
                 },
               },
      default = {MAKEFILENAME},
    },
    { tag = "dont_execute",
      cmd = {'-n', "--just-print"},
      descr = "Don't actually run any command; just print them.",
      blockedby = {"printhelp", "printversion", "dont_execute"},
    },
    { tag = "defines",
      cmd = {'-D', "--define"},
      descr = 'DEFINEs for compilation.',
      blockedby = {"printhelp", "printversion"},
      multiple = true;
      params = { {
                 delim = ','
                 }
               }
    },
    { tag = "verbose",
      cmd = {'-v', "--verbose"},
      descr = 'Be verbose. print commands executed, ...',
      blockedby = {"printhelp", "printversion", "silent", "verbose"},
    },
    { tag = "silent",
      cmd = {'-s', "--silent"},
      descr = "Don't echo commands executed.",
      blockedby = {"printhelp", "printversion", "silent", "verbose"},
    },
    { tag = "question",
      cmd = {'-q', "--question"},
      descr = "Run no recipe; exit status says if up to date.",
      blockedby = {"printhelp", "printversion", "verbose", "build"},
    },
    { tag = "jobs",
      cmd = {'-j', "--jobs"},
      descr = 'Run N jobs parallel. (default: # of cores)',
      blockedby = {"printhelp", "printversion", "jobs"},
      params = {
                 {
                 t = "int",
                 min = 1,
                 },
               def = {tonumber(NUMCORES)},
               }
    },
    { tag = "printversion",
      cmd = {"-V", "--version"},
      descr = 'Display version information, then exit',
      blockedby = {"printhelp", "targets"},
    },
    { tag = "printhelp",
      cmd = {"-h", "--help"},
      descr = "Display this help, then exit.",
      blockedby = {"build", "makefile", "dont_execute", "defines", "mode",
                   "import_needs", "export_needs", "use_needs", "aliases",
                   "verbose", "silent", "question", "jobs",
                   "targets", "printversion"},
    },
    --
    others = {
      { tag = "targets",
        blockedby = {"printhelp", "printversion"},
        multiple = true;
        params = { {
                   re = "^[%w%._]+$",
                   delim = ","
                   }
                 }
      },
    },
  };
  --
end;
--
--=== [Concurrent job handling] =============================================
local concurrent_jobs; -- FORWARD(nj);
local job_execute;     -- FORWARD(cmd, callback);
local jobs_clear;      -- FORWARD();
do
  --
  local function command_line(cmd)
    local tmpfile = fn_temp();
    local cmdline;
    cmd = cmd:gsub("%s%s%s%s$", choose(WINDOWS, " > NUL", " > /dev/null"))
    if cmd:match '>%s*%S+$' then
      cmdline = cmd .. ' 2> ' .. tmpfile;
    else
      cmdline = cmd..' > '..tmpfile..' 2>&1'
    end
    return cmdline, tmpfile;
  end;

  local function execute_wrapper(cmd, callback)
    local cmdline, tmpfile = command_line(cmd);
    local ok, code = execute(cmdline);
    local inf = io_open(tmpfile, 'r');
    callback(ok, code, inf)
    inf:close();
    os_remove(tmpfile);
  end;

  job_execute = execute_wrapper;
  jobs_clear  = function() end;
  local n_threads, n_threads_forced = 1, false;
  local Processes  = class.List:new();
  local Outputs    = class.List:new();
  local spawn;     -- FORWARD(cmd)
  local wait;      -- FORWARD([cmd])
  local job_start; -- FORWARD(cmd)
  local jobs_wait; -- FORWARD()
  if WINDOWS then
    if winapi then
      local comspec = ENV.COMSPEC .. ' /c ';
      --
      function spawn(cmd)
        cmd = comspec..cmd;
        if #cmd > 32767 then quit("spawn(): commandline too long (%s chars)", #cmd); end;
        return winapi.spawn_process(comspec..cmd);
      end;
      --
      function wait()
        local idx, err = winapi.wait_for_processes(Processes, false)
        if err then return nil, err; end;
        local p = Processes[idx]
        return idx, p:get_exit_code(), err;
      end;
      --
    end;
  else
    if posix then
      --
      function spawn(cmd)
        local cpid = posix.fork()
        if cpid == 0 then
          if posix.exec('/bin/sh','-c',cmd) == -1 then
            local _, code = posix.errno()
            os_exit(code)
          end
        else
          return cpid
        end
      end
      --
      function wait()
        local pid, _, code = posix.wait(-1);
        if not pid then return nil, nil, code end;
        local idx = Processes:index(pid);
        return idx, code;
      end;
      --
    end;
  end;
  if winapi or posix then
    function job_start(cmd, callback)
      local cmdline, tmpfile = command_line(cmd)
      local p, r = spawn(cmdline)
      Outputs:insert{read=r, callback=callback, tmp=tmpfile}
      Processes:insert(p);
    end;

    function jobs_wait(cmd, callback)
      if #Processes == 0 then
        if cmd then job_start(cmd, callback); end;
        return;
      end;
      local idx, code, err = wait();
      if cmd then job_start(cmd, callback); end;
      if err then return nil, err end;
      local item, p = Outputs[idx], Processes[idx];
      local inf, _ = io_open(item.tmp, 'r');
      Processes:remove(idx);
      Outputs:remove(idx);
      item.callback(code == 0, code, inf);
      if item.read then item.read:close() end;
      inf:close();
      if winapi then p:close(); end
      os_remove(item.tmp);
    end;

    function jobs_clear()
      while #Processes > 0 do jobs_wait(); end;
    end;

    function job_execute(cmd, callback)
      if n_threads < 2 then
        execute_wrapper(cmd, callback)
      else
        --dprint("job_execute\t%s\t%s", #Processes, n_threads)
        while #Processes > n_threads do jobs_wait(); end; -- job queue is full
        if #Processes == n_threads then
          jobs_wait(cmd, callback);
        else
          job_start(cmd, callback)
        end;
      end;
    end;
  end;

  concurrent_jobs = function(nj)
    local toi = tointeger or tonumber;
    nj = toi(nj);
    if not winapi or posix then return nil, "concurrent_jobs(): no threading available. winapi/posix needed." end;
    if type(nj) ~= 'number' then return nil, "concurrent_jobs(): number of jobs must be a integer" end;
    if not n_threads_forced then
      n_threads = nj;
      n_threads_forced = MAKELEVEL == 0;
      return true;
    else
      return nil, "overriden by command line.";
    end;
  end;

end;
--
local clMakeScript, MakeScript, clMake;
do -- [MakeScript Sandbox] ==================================================
  --
  local includepath;
  do -- includepath = package.path ...
    includepath = split(fn_path_lua(package.path):gsub("%?%.lua",""),";");
    local progdir = fn_path_lua(arg[0]):gsub("/[^/]*$","")
    insert(includepath, 1, progdir);
    for i = #includepath, 1, -1 do
      if #includepath[i] == 0 or includepath[i]:find("init.lua") then
        remove(includepath, i);
      else
        includepath[i] = includepath[i]:gsub("/$","");
      end;
    end;
  end;
  -- makescript filenames
  local scriptnames = {};

  clMakeScript = class.base:subclass("MakeScript", {
    __call  = function(self, filename)
      local makefile, err = loadfile (filename, "t", self);
      if makefile then
        if setfenv then setfenv(makefile, self); end; -- lua 5.1
        insert(scriptnames, clMakeScript.MAKEFILENAME);
        clMakeScript.MAKEFILENAME = filename;
        local path = fn_splitpath(filename);
        if path ~= "" then chdir(path); end;
        clMakeScript.PWD = PWD;
        if not clMakeScript.MAINSCRIPTDIR then
          clMakeScript.MAINSCRIPTDIR = PWD;
          insert(includepath, 1, PWD);
          includepath = class.StrList:new(includepath) -- cleans up double entries
        end;
        MAKELEVEL = MAKELEVEL + 1;
        clMakeScript.MAKELEVEL = MAKELEVEL;
        makefile();
        MAKELEVEL = MAKELEVEL - 1;
        clMakeScript.MAKELEVEL = MAKELEVEL;
        clMakeScript.MAKEFILENAME = remove(scriptnames);
        if path ~= "" then chdir("<"); end;
      else
        quit(err, 2);
      end;
    end,
    include = function(filename)
      filename = fn_defaultExt(filename, INCLUDESCRIPTEXT);
      local makefilename;
      local makefile, errmsg;
      for dir in includepath() do
        makefilename = fn_join(dir, filename);
        makefile, errmsg = loadfile (makefilename, "t", MakeScript);
        if makefile then break; end;
        if not errmsg:find("cannot open") then quit("make(): %s", errmsg); end;
      end;
      if makefile then
        if setfenv then setfenv(makefile, MakeScript); end; -- lua 5.1
        insert(scriptnames, clMakeScript.MAKEFILENAME);
        clMakeScript.MAKEFILENAME = makefilename;
        makefile();
        clMakeScript.MAKEFILENAME = remove(scriptnames);
      else
        quitMF("make(): cant find include file '%s'.", filename);
      end;
    end,
    WINDOWS = WINDOWS,
    assert  = assert,
    ENV     = ENV,
    ipairs  = ipairs,
    pairs   = pairs,
    pcall   = pcall,
    print   = print,
    require = require,
    type    = type,
    io      = roTable(io),
    math    = roTable(math),
    os      = roTable(os),
    string  = roTable(string),
    table   = roTable(table),
    quit    = quitMF,
    warning = warningMF,
  }); clMakeScript:protect();
  --
  MakeScript = clMakeScript:singleton{};
  --
  -- Extracts all but the suffix of each file name in names.
  -- If the file name contains a period, the basename is everything starting up to
  -- (and not including) the last period. Periods in the directory part are ignored.
  -- If there is no period, the basename is the entire file name. For example,
  --     `basename "src/foo.c src-1.0/bar hacks"`
  -- produces the result `"src/foo src-1.0/bar hacks"`.
  clMakeScript.basename = function(...)
    if select("#", ...) ~= 1 then quitMF("basename() need 1 parameter exactly."); end;
    local lst = select(1, ...);
    lst = split(lst);
    for i = 1, #lst do
      lst[i] = lst[i]:gsub("%.[^%.]*$", "");
    end;
    return concat(lst, " ");
  end;
  --
  -- The argument names is regarded as a series of names, separated by whitespace;
  -- suffix is used as a unit. The value of suffix is appended to the end of each
  -- individual name and the resulting larger names are concatenated with single
  -- spaces between them. For example,
  --   `addsuffix(".c", "foo bar")`
  -- produces the result `"foo.c bar.c"`.
  clMakeScript.addsuffix = function(...)
    if select("#", ...) ~= 2 then quitMF("addsuffix() need 2 parameter exactly."); end;
    local suffix, lst = select(1, ...);
    lst = split(lst);
    for i = 1, #lst do
      lst[i] = lst[i]..suffix;
    end;
    return concat(lst, " ");
  end;
  --
  -- The argument names is regarded as a series of names, separated by whitespace;
  -- prefix is used as a unit. The value of prefix is prepended to the front of each
  -- individual name and the resulting larger names are concatenated with single
  -- spaces between them. For example,
  --   `addprefix( "src/", "foo bar")`
  -- produces the result `"src/foo src/bar"`.
  clMakeScript.addprefix = function(...)
    if select("#", ...) ~= 2 then quitMF("addprefix() need 2 parameter exactly."); end;
    local prefix, lst = select(1, ...);
    lst = split(lst);
    for i = 1, #lst do
      lst[i] = prefix..lst[i];
    end;
    return concat(lst, " ");
  end;
  --
end;
--
local runMake; -- FORWARD()
do -- [Make] ================================================================
  --
  clMake = class.base:subclass("Make", {
    _VERSION    = VERSION,
    WINDOWS     = WINDOWS,
    Commandline = cmdl,
    utils       = roTable{
      ENV             = ENV,
      chdir           = chdir,
      choose          = choose,
      pick            = pick,
      split           = split,
      shell           = shell,
      execute         = execute,
      which           = fn_which,
      tempFinemane    = fn_temp,
      isabs           = fn_isabs,
      canonical       = fn_canonical,
      join            = fn_join,
      isFile          = fn_isFile,
      isDir           = fn_isDir,
      defaultExt      = fn_defaultExt,
      exists          = fn_exists,
      forceext        = fn_forceExt,
      splitext        = fn_splitext,
      get_ext         = fn_get_ext,
      splitpath       = fn_splitpath,
      basename        = fn_basename,
      path_lua        = fn_path_lua,
      abs             = fn_abs,
      filetime        = fn_filetime,
      get_files       = fn_get_files,
      files_from_mask = fn_files_from_mask,
      get_directories = fn_get_directories,
    },
    warning     = warning,
    warningMF   = warningMF,
    quit        = quit,
    quitMF      = quitMF,
  }); clMake:protect();

  clMake.__call  = function(self, cmd)
    local makefile, target;
    local function parseCommandline(cmd)
      local cmdl = require "Cmdl"
      local makefile, target;
      local options, msg = cmdl.parse(cmd);
      if not options then
        print(("* error in parameter:%s"):format(msg));
        os_exit(1);
      end;
      target = options.targets;
      clMake.options = options;
      --
      if options.printversion then -- -V, --version
        print(MSG1);
        os_exit();
      end;
      if options.jobs then         -- -j, --jobs
        local ok, err = concurrent_jobs(clMake.options.jobs)
        if not ok then warning(err) end;
      end;
      if options.makefile then     -- -f, --makefile
        options.makefile = fn_path_lua(fn_abs(fn_defaultExt(Make.options.makefile, SCRIPTEXT)));
        makefile = options.makefile;
      end;
      if options.question then     -- -q, --question
        Make.options.silent = true;
      end;
      -- Late execution of help text display.
      -- This way, loaded toolchains may insert aditional command line switches
      -- BEFORE the help message becomes generated.
      if options.printhelp then    -- -h, --help
        print(MSG1);
        print(USAGE:format(cmdl.help(1)));
        os_exit();
      end;
     --
      return makefile, target;
    end;
    --
    cmd = cmd or {};
    if type(cmd) == "string" then cmd = split(cmd); end;
    if MAKELEVEL == 0 then -- parse the command line ...
      makefile, target = parseCommandline(cmd);
      self.target = target;
      makefile = makefile or MAKEFILENAME;
    else
      makefile = cmd[1];
    end;
    --
    if not fn_isFile(makefile) then
      if not fn_isFile(makefile..SCRIPTEXT) then
        if fn_isDir(makefile) then
          makefile = fn_join(makefile, MAKEFILENAME);
        end;
        if not fn_isFile(makefile) then
          quit("make(): cant find '%s'.", makefile, 0);
        end;
      else
        makefile = makefile..SCRIPTEXT;
      end;
    end;
    --
    MakeScript(makefile);
    --
    if MAKELEVEL == 0 then runMake(); end; -- do the job ...
  end;

  clMake.newTool = function(...)
    return class.Tool:new(...);
  end;

  clMake.LUAVERSION = luaVersion();
  --
  Make = clMake:singleton();
  --
  clMakeScript.make = Make;
  --
end;
--
--=== [file & target handling] ==============================================
local clSourceFile, clGeneratedFile, clTargetList;
local GeneratedFiles, Targets;
do
  local clTreeNode, clTarget, clFile,
        target, default;
  local tSourceFileTimes = {}; -- caching file times.
  --
  -- generic make tree node.
  clTreeNode = class.base:subclass("TreeNode");
  clTreeNode.needsBuild       = function(self) --luacheck: ignore
    -- subclass has to redefine this method.
    error("clMaketreeNode:needsBuild(): abstract method called.");
  end;

  clTreeNode.getBuildSequence = function(self, buildAll)
    local FileList = clTargetList:new();
    local PresList = clTargetList:new();
    local maxLevel    = 0;
    local lvlTbl      = {};
    local Needs = Make.Needs;
    --
    local function deduceLvl(node, buildAll, lvl, needIMs)
      local function remember(node)
        --dprint("%s\t%s", node.level, node[1]);
        if not FileList:find(node[1]) then FileList:add(node); end;
      end;
      if node == nil or node:is("SourceFile") then return; end;
      needIMs = needIMs or node.bP21NeedsBuild;
      node.bP22NeedsBuild = needIMs and not node.bClean or node.bForce or buildAll;
      lvl = lvl or 1;
      if not node:is("TargetList Target") or node.action then lvl = lvl + 1; end;
      maxLevel = max(maxLevel, lvl);
      node.level = max(node.level or -1, lvl);
      -- expanding from's
      if node.from then
        for fs in node.from() do
          for n, v in pairs(Needs(fs)) do node[n]:add(v); end;
        end;
        node.from = nil;
      end;
      if node.prerequisites then
        for pre in node.prerequisites() do
          if PresList:find(pre[1]) then
            if lvl >= pre.level then
              deduceLvl(pre, buildAll, lvl); --TODO
            end;
          else
            PresList:add(pre);
            deduceLvl(pre, buildAll, lvl); --TODO
          end;
        end;
      end;
      if node:is("TargetList") then
        for t in node() do deduceLvl(t, buildAll, lvl, needIMs); end;
      elseif node:is("Target") then
        if node.action and node.bDirty then
          remember(node);
        else
          deduceLvl(node.deps, buildAll, lvl, needIMs);
        end;
      elseif node:is("GeneratedFile") then
        if node.bP22NeedsBuild then
          remember(node);
          deduceLvl(node.deps,  buildAll, lvl, node.bP22NeedsBuild);
          deduceLvl(node.needs, buildAll, lvl, node.bP22NeedsBuild);
        end;
      end;
    end;
    --
    deduceLvl(self, buildAll);
    -- filling the level table. (higher levels will be executed 1st.)
    for i = 1, maxLevel do lvlTbl[i] = {}; end;
    for n in FileList() do insert(lvlTbl[n.level], n); end;
    -- removing empty levels
    for i = #lvlTbl, 1, -1 do
      if #lvlTbl[i] == 0 then remove(lvlTbl, i); end;
    end;
    --[[-- debug messages
    if _DEBUG then -- print out some node status.
      local _min, _max = 1/0, -1/0;
      for _, t in ipairs(lvlTbl) do
        _min = math.min(_min, #t);
        _max = math.max(_max, #t);
      end;
      dprint("makeNodeQD(): %s nodes in %s level(s). %s..%s nodes/level", #FileList, #lvlTbl, _min, _max);
      -- print filenames ...
      for i, t in ipairs(lvlTbl) do
        dprint("========== level %i", i);
        for _, n in ipairs(t) do dprint(n[1]); end;
      end;
      dprint("===================");
    end;
    --]]--
    return lvlTbl, #FileList;
  end;
  --
  -- phony targets.
  clTarget = clTreeNode:subclass("Target", {
    init  = function(self, label, deps)
      self[1] = label;
      if type(deps) == "table" then
        if type(deps.action) == "function" then
          self.action = deps.action;
        end;
        self.deps = deps and clTargetList:new(deps);
      end;
      return self;
    end,
  });

  clTarget.add_deps   = function(self, deps)
    if self.deps == nil then
      self.deps = clTargetList:new();
    end;
    if class(deps, self.deps.__allowed) then
      if not self.deps:find(deps[1]) then
        self.deps:add(deps);
        deps.target = true;
      else
        quitMF(("cant overwrite value '%s'"):format(deps[1]));
      end;
    elseif type(deps) == "table" then
      for _, v in ipairs(deps) do
        self.deps:add(v, true);
        v.target = true;
      end;
    else
      quitMF("parameter needs to be a object or a list of objects.");
    end;
  end;

  clTarget.needsBuild = function(self)
    --dprint("clTarget.needsBuild():                   %s =>", self[1]);
    local dirty, modtime = false, -1;
    if self.deps then dirty, modtime = self.deps:needsBuild(); end;
    self.bDirty   = self.bForce or self.bDirty or dirty;
    self._nodeTime   = modtime;
    self.bP21Done = true;
    --dprint("clTarget.needsBuild():             %s %s", self.bDirty and "DIRTY" or "clean", self[1]);
    return self.bDirty, modtime;
  end;
  --
  -- generic files.
  clFile = clTreeNode:subclass("File", {
    init  = function(self, ...) -- ([<path>,]* filename)
      self[1] = fn_abs(fn_join(...));
      return self;
    end,
  });

  clFile.needsBuild  = function(self) --luacheck: ignore
    -- subclass has to redefine this method.
    error("clFile:needsBuild(): abstract method called.", 2);
  end;

  clFile.getFiletime = function(self)
    if not self._filetime then
      self._filetime = attributes(self[1], 'modification') or -1;
    end;
    return self._filetime;
  end;

  clFile.exists      = function(self)
    return (self._filetime or self:getFiletime()) ~= -1;
  end;

  clFile.mkdir       = function(self)
    if not self:exists() then
      fn_ensurePath(fn_splitpath(self[1]))
    end;
  end;

  clFile.concat      = function(self) -- for compatibility with `clTargetList` filename concatenation.
    return self[1];
  end;

  clFile.canonical   = function(self)
    return fn_canonical(self[1]);
  end;
  --
  clSourceFile = clFile:subclass("SourceFile", {
    init = function(self, ...) -- ([<path>,]* filename)
      clSourceFile.super.init(self, ...);
      local fn = self[1];
      if fn:find("[%*%?]+") then return; end; -- wildcard detected.
      local time = tSourceFileTimes[fn];
      if not time then
        time = clSourceFile.super.getFiletime(self);
        if time == -1 then quitMF("ERROR: cant find source file '%s'.", fn); end;
        tSourceFileTimes[fn] = time;
      end;
      self._filetime = time;
      return self;
    end;
  });

  clSourceFile.getFiletime = function(self)
    return self._filetime;
  end;

  clSourceFile.needsBuild  = function(self)
    --dprint("clSourceFile.needsBuild():               %s", self[1]);
    if self.bP21Done then return self.bDirty, self._nodeTime, not self.bDirty; end;
    local time = self:getFiletime();
    local dirty, modtime = false, -1;
    if self.deps then dirty, modtime = self.deps:needsBuild(); end;
    self._nodeTime = max(time or -1, modtime or -1);
    self.bDirty = dirty or (time < self._nodeTime);
    self.bP21Done = true;
    --dprint("clSourceFile.needsBuild():         %s %s", self.bDirty and "DIRTY" or "clean", self[1]);
    return self.bDirty, self._nodeTime, not self.bDirty;
  end;
  --
  clGeneratedFile = clFile:subclass("GeneratedFile", {
    init = function(self, ...) -- ([<path>,]* filename)
      clGeneratedFile.super.init(self, ...);
      GeneratedFiles:add(self);
      return self;
    end,
  });

  clGeneratedFile.needsBuild = function(self)
    if self.bP21Done then
      return self.bP21NeedsBuild, self._nodeTime, self.bClean;
    end;
    --
    local fileTime = self:getFiletime();
    local clean = self:exists();
    local dirty = not clean;
    local depTime,   depsDirty,  depsClean  = -1;
    local preTime,   presDirty,  presClean  = -1;
    local needsTime, needsDirty, needsClean = -1;
    --[[-- debug output
    dprint("clGeneratedFile.needsBuild():            %s => %s",
      self[1],
      self.bDirty and "?" or os.date("%Y/%m/%d %H:%M:%S", time)
    );
    --]]--
    --
    if self.prerequisites then presDirty,  preTime,   presClean  = self.prerequisites:needsBuild(); end;
    if self.deps          then depsDirty,  depTime,   depsClean  = self.deps:needsBuild();          end;
    if self.needs         then needsDirty, needsTime, needsClean = self.needs:needsBuild();         end;
    --
    self._nodeTime = max(fileTime, depTime, preTime, needsTime);
    dirty = dirty or depsDirty or presDirty or needsDirty or (fileTime < max(depTime, preTime, needsTime));
    self.bClean = clean and depsClean and needsClean and fileTime >= self._nodeTime;
    self.bP21NeedsBuild = dirty and self.target or false;
    self.bP21Done = true;
    --[[-- debug output
    dprint("clGeneratedFile.needsBuild():      %s %s => %s, %s",
      self.bDirty and "DIRTY" or "clean",
      self[1],
      self.bP21NeedsBuild,
      self._nodeTime == -1 and "" or os.date("%Y/%m/%d %H:%M:%S", self._nodeTime)
    );
    --]]--
    return self.bP21NeedsBuild, self._nodeTime, self.bClean;
  end;

  clGeneratedFile.delete     = function(self)
    local depfile = fn_forceExt(self[1], ".d");
    if self:exists() then
      if not Make.options.quiet then print("DELETE " .. fn_canonical(self[1])); end;
      if not Make.options.dont_execute then os_remove(self[1]); end;
      if fn_exists(depfile) then
        if not Make.options.quiet then print("DELETE " .. fn_canonical(depfile)); end;
        if not Make.options.dont_execute then os_remove(depfile); end;
      end;
    end;
  end;
  --
  clTargetList = class.UList:subclass("TargetList", {
    __allowed   = "TreeNode",
    __call = function(self, ...) -- iterator() or find(...)
      if select("#", ...) > 0 then return self:find(...) end;
      local i = 0;
      return function()
        i = i + 1;
        return self[i];
      end;
    end,
  });

  clTargetList.init              = function(self, param)
    self.__dir = {};
    if type(param) == "table" then self:add(param); end;
    return self;
  end;

  clTargetList.add               = function(self, item, isTarget)
    local kf = self.__key or 1;
    if class(item, self.__allowed) then
      if not self.__dir[item[kf]] then
        insert(self, item);
        self.__dir[item[kf]] = item;
        if class(item.prerequisites, "StringList") then
          self.prerequisites:add(item.prerequisites);
        end;
      else
        error(("cant overwrite value '%s'"):format(item[kf]));
      end;
    elseif type(item) == "table" then
      for _, v in ipairs(item) do
        self:add(v);
        if isTarget then v.target = true; end;
      end;
    else
      error("parameter needs to be a object or a list of objects.", 2);
    end;
    return self;
  end;

  clTargetList.needsBuild        = function(self)
    if self.bP21Done then
      return self.bDirty, self._nodeTime, self.bClean;
    end;
    local time, dirty, clean = -1, false, true;
    for n in self() do
      local d, mt, c = n:needsBuild();
      dirty = dirty or d;
      time = max(time, mt);
      clean = clean and c;
    end;
    self._nodeTime = time;
    self.bDirty    = dirty;
    self.bClean    = clean;
    self.bP21Done  = true;
    return dirty, time, clean;
  end;

  clTargetList.new_sourcefile    = function(self, ...)
    local item = clSourceFile:new(...);
    if item then self:add(item); end;
    return item;
  end;

  clTargetList.new_generatedfile = function(self, ...)
    local item = clGeneratedFile:new(...);
    if item then self:add(item); end;
    return item;
  end;

  clTargetList.new_target        = function(self, ...)
    local item = clTarget:new(...);
    self:add(item);
    return item;
  end;

  clTargetList.canonical         = function(self)
    local res = {};
    for f in self() do insert(res, f:canonical()); end;
    return concat(res," ");
  end;

  clTargetList.delete            = function(self)
    for f in self() do
      if f:is("GeneratedFile") then f:delete(); end;
    end;
  end;
  --
  GeneratedFiles = clTargetList:new(); -- all generated files.
  Targets        = clTargetList:new(); -- all phony targets.
  --
  function target(label, deps, ...)
    if select('#', ...) > 0 or deps == nil then quitMF("target(): parameter error. Did you use {}?"); end;
    local Target = Targets:find(label) or Targets:new_target(label);
    Target:add_deps(deps);
    return Target;
  end;

  function default(deps, ...)
    if select('#', ...) > 0 or deps == nil then quitMF("default(): parameter error. Did you use {}?"); end;
    return target("default", deps)
  end;
  --
  clMakeScript.default = default;
  clMakeScript.target  = target;
  --
  clMake.Targets   = Targets;
  --
end;
--
--=== [needs handling] ======================================================
local Needs;
do
  --
  local clNeeds;
  --
  clNeeds = class.UList:subclass("Needs", {
    __key  = 1,
    fields = class.StrList:new{"defines", "incdir", "libs", "libdir", "prerequisites"}, -- allowed fields.
  }); clNeeds:protect();

  clNeeds.__call = function(self, ...) -- need definition and reading
    local p1, p2, unused = select(1, ...);
    if type(unused) ~= "nil" then quitMF("%s: wrong parameter.", self.__classname); end;
    if (type(p1) == "string") and (p2 == nil)  then
      -- "alias = need" ?
      if p1:find("=") then
        local alias, need = p1:match("^(%w+)%s*=%s*(%S+)$");
        local a, n = self:find(alias), self:find(need);
        if not n then quitMF("needs.alias(): no need '%s' defined."); end;
        if a and (a[1] == alias) then quitMF("needs.alias(): '%s' is already defined as normal need.", alias); end;
        self.__dir[alias] = n;
        return n;
      end;
      -- "need:field" ?
      if p1:find("^[^:]+:.+$") then
        local n;
        local ns = p1:match("^([^:]+):.+$");
        n = self:find(ns);
        if not n then quit("needs(): no need '%s' found.", ns); end;
        local res = {};
        local fs = split(p1:match("^[^:]+:(.+)$"), ",");
        for _, fn in ipairs(fs) do
          if n[fn] then res[fn] = class.StrList:new(n[fn]); end;
        end;
        return res;
      end;
      -- "need" !
      return self:find(p1)
    end;
    if (type(p1) == "table") and (p2 == nil)  then
      local needname = p1[1];
      if self.__dir[needname] then quitMF("Need '%s' already defined.", p1[1]); end;
      local need = {needname};
      self.__dir[needname] = need;
      insert(self, need);
      for fn, v in pairs(p1) do
        if fn ~= 1 then
          if fn == "incdir" or fn == "libdir"  then
            v = fn_abs(v);
          end;
          if self.fields:find(fn) then
            need[fn] = class.StrList:new(v);
          else
            need[fn] = v;
          end;
        end;
      end;
    else
      quitMF("%s: wrong parameter.", self.__classname);
    end;
  end;

  Needs = clNeeds:new();

  clMakeScript.define_need = Needs;
  clMake.Needs = Needs;
  --
end;
--
do -- [make pass 2 + 3] =====================================================
  --
  function runMake()
    local always_make = Make.options.build;
    local just_print  = Make.options.dont_execute;
    local quiet       = Make.options.silent;
    local verbose     = Make.options.verbose;
    local strict      = not Make.options.nostrict; --TODO:
    local targets;
    --
    local function getTarget() --TODO: rework
      if targets == nil then
        if not Targets:find("default") then
          for node in GeneratedFiles() do
            if node.type == "prog" or node.type == "slib" or node.type == "dlib" then
              MakeScript.default(node);
            end;
          end;
        end;
        if Make.target then
          targets = split(Make.target, ",");
          for i = 1, #targets do
            local ts = targets[i];
            targets[i] = Targets:find(ts)
            if not targets[i] then
              quit("make(): no target '%s' defined.", ts, 0);
            end;
          end;
        else
          local startAt = Targets:find("default");
          if not startAt or #startAt == 0 then
            quit("make(): no idea, what to make. (no progs or libs defined.)", 0);
          end;
          targets = {startAt};
        end;
      end;
      return remove(targets, 1);
    end;
    -- pass 2
    local function needsBuild(treeNode)
      local res = treeNode:needsBuild();
      if Make.options.question then os_exit(res and 1 or 0); end;
      res = res or always_make;
      if not res and not quiet then print("... all up to date."); end;
      return res;
    end;
    -- pass 3
    local function makeNode(node)
      local lvlTbl;
      local nodesdone, numnodes = 0;
      -- execute a nodes action and/or commandline.
      local function buildNode(node)
        if node == nil then return; end;
        if not node.bP22NeedsBuild and not always_make then node.done = true; end;
        if node.done then return; end;
        if node:is("Target") and node.bForce then
          node:action();
        elseif node:is("TreeNode") then
          if node.bP22NeedsBuild or always_make then
            nodesdone = nodesdone + 1;
            -- construct command line
            if node:is("GeneratedFile") and not node.command then
              node.tool:build_command(node);
            end;
            if node.command and not quiet then
              if verbose then
                print(node.command);
              else
                local s = node.tool.CMD or fn_basename(fn_splitext(node.command:match("^(%S+)%s")));
                s = s:upper() .. string.rep(" ", 7 - #s) .. " " .. fn_canonical(fn_rel(node[1]));
                s = ("[%2d/%2d] "):format(nodesdone , numnodes)..s;
                print(s);
              end;
            end;
            if not just_print then
              if type(node.action) == "function" then
                if verbose then print("ACTION ".. node[1]); end;
                if not node.action_done then
                  node:action();
                  node.action_done = true;
                end;
              end;
              if node.command then
                fn_ensurePath(fn_splitpath(node[1]));
                if node.func then
                  local ok, msg = node.func();
                  if not ok and msg then print(msg); end;
                  if not ok and strict then --abort ...
                    jobs_clear();
                    os_exit(2);
                  end;
                  node.done = true;
                  node.bDirty = nil;
                else
                  job_execute(node.command,
                    function(ok, code, inf)
                      if verbose or not ok then
                        for l in inf:lines() do
                          print(l);
                        end;
                      end;
                      if not ok and strict then --abort ...
                        jobs_clear();
                        os_exit(code);
                      end;
                      node.done = true;
                      node.bDirty = nil;
                    end
                  );
                end;
              end;
            end;
          end;
        end;
      end;
      --
      lvlTbl, numnodes = node:getBuildSequence(always_make);
      for i = #lvlTbl, 1, -1 do
        for _, n in ipairs(lvlTbl[i]) do buildNode(n); end;
        jobs_clear();
      end;
    end;
    --
    local target = getTarget();
    while target do
      if not quiet then print("TARGET " .. target[1]); end;
      if needsBuild(target) then
        makeNode(target);
      end;
      target = getTarget();
    end;
  end;
  --
end;
--
do -- [tools & rules] =======================================================
  local clTool, Rule, Group;
  --
  clTool = class.base:subclass("Tool", {
    __call = function(self, ...)
      if self.__default then
        return self.__default(...);
      else
        error(("<class %s>: no default action."):format(self.__classname), 2);
      end;
    end,
  });
  -- utilities
  function clTool:readDepFile(TreeNode) -- return a TargetList with all included files. or nil.
    local function getField(name)
      return TreeNode.__par[name] or self.__par[name];
    end;
    local depFunc = getField("F_GETINCLUDES");
    if depFunc then
      local txt = depFunc(fn_forceExt(TreeNode[1], ".d"));
      if not txt then return; end;
      local tl  = clTargetList:new();
      for _, n in ipairs(txt) do
        if not (GeneratedFiles:find(n) or tl:find(n)) then
          tl:new_sourcefile(n);
        end;
      end;
      return tl;
    end;
  end;

  function clTool:checkParam(...)
    if select("#", ...) ~= 1 then quitMF("%s(): only one parameter alowed. Did you use {}?", self[1]); end;
    local par = select(1, ...);
    if type(par) ~= "table" then quitMF("%s(): parameter needs to be a table. Did you use {}?", self[1]); end;
    return par;
  end;

  function clTool:add_action(what, func)
    local fn = "action_"..what;
    if func then self[fn] = func; end;
    self[what] = function(...) return self[fn](self, ...); end;
    if not self.__default then self.__default = self[what]; end;
  end;
  -- command line generation
  function clTool:expand_DEFINES(TreeNode) --luacheck: ignore
    local values = class.StrList:new();
    values:add(TreeNode.defines);
    values:add(Make.options.define);
    if #values == 0 then return ""; end;
    return "-D"..concat(values, " -D");
  end;

  function clTool:expand_OPTIONS(TreeNode)
    local function getField(name)
      --return TreeNode and TreeNode.__par[name] or self.__par[name];
      return TreeNode.__par[name] or self.__par[name];
    end;

    local options = class.StrList:new();
    -- for non debug builds: strip debug infos from executables and dynlibs.
    local s = getField("SW_STRIP", TreeNode);
    if not MakeScript.DEBUG and s then options:add(s); end;
    -- dependency file generation
    local d = getField("SW_DEPGEN", TreeNode);
    if not MakeScript.NODEPS and d then options:add(d); end;
    -- optimize
    local o = getField("SW_OPTIMIZE", TreeNode);
    if o then
      if o:find("%*") then
        if MakeScript.OPTIMIZE then
          options:add(o:gsub("%*", MakeScript.OPTIMIZE));
        end;
      else
        options:add(o);
      end;
    end;
    -- insert cflags.
    if TreeNode.cflags then options:add(TreeNode.cflags:concat()); end;
    -- insert include dirs
    if TreeNode.incdir then
      for dir in TreeNode.incdir() do
        options:add("-I"..fn_canonical(dir));
      end;
    end;
    return concat(options, " ");
  end;

  function clTool:expand_LIBS(TreeNode) --luacheck: ignore
    local libs = class.StrList:new();
    for ld in TreeNode.libdir() do libs:add("-L"..fn_canonical(ld)); end;
    for l in TreeNode.libs()    do libs:add("-l"..fn_canonical(l));  end;
    return concat(libs, " ");
  end;

  function clTool:expand_SOURCES(TreeNode) --luacheck: ignore
    local result = {};
    if class(TreeNode, "GeneratedFile") then
      if class(TreeNode.deps, "File") then
        insert(result, fn_canonical(fn_rel(TreeNode.deps[1])));
      elseif class(TreeNode.deps, "TargetList") then
        for sf in TreeNode.deps() do
          insert(result, fn_canonical(fn_rel(sf[1])));
        end;
      end;
    elseif class(TreeNode, "TargetList") then
      for sf in TreeNode() do
        insert(result, fn_canonical(fn_rel(sf[1])));
      end;
    end;
    if #result == 0 then return ""; end;
    return concat(result, " ");
  end;
  clTool.expand_SOURCE = clTool.expand_SOURCES;
  function clTool:expand_OUTFILE(TreeNode) --luacheck: ignore
    if class(TreeNode, "GeneratedFile") then
      return fn_canonical(fn_rel(TreeNode[1]));
    else
      error("OUTFILE is not of class GeneratedFile", 2);
    end;
  end;

  function clTool:expand_PROG(TreeNode)
    return TreeNode.__par["prog"] or self.__par["prog"];
  end;

  function clTool:build_command(TreeNode)
    local function getField(name)
      local par = TreeNode.__par;
      return TreeNode[name] or par and par[name];
    end;
    local cmdln = getField("action");
    local function genfunc(func, src, dst)
      local p = {};
      for n in cmdln:gmatch"$(%u+)" do
        if n == "SOURCE" then
          if class(src, "File") then
            p.source = src[1];
          elseif class(src, "TargetList") and #src == 1 then
            p.source = src[1][1];
          else
            error("invalid parameter 'src'.");
          end;
        elseif n == "SOURCES" then
          if class(src, "File") then
            p.sources = {src[1]};
          elseif class(src, "TargetList") then
            p.sources = {};
            for i = 1, #src do insert(p.sources, src[i][1]); end;
          else
            error("invalid parameter 'src'.");
          end;
        elseif n == "OUTFILE" then
          if class(dst, "File") then
            p.outfile = dst[1];
          else
            quitMF("rule.create(): invalid $OUTFILE parameter.");
          end;
        else
          n = n:lower();
          if ("string boolean number nil"):find(type(getField(n))) then
            p[n] = getField(n);
          else
            quitMF("rule(): parameter '%s' needs to be string or number or boolean.", n);
          end;
        end;
      end;
      return function() return func(p); end;
    end;

    if TreeNode.func then
      TreeNode.func = genfunc(TreeNode.func, TreeNode.deps, TreeNode);
      cmdln = cmdln:gsub("%$SOURCES", self:expand_SOURCES(TreeNode)):gsub("%$OUTFILE", self:expand_OUTFILE(TreeNode)):gsub("%$%u+", "");
    else
      for j in cmdln:gmatch("%$(%u+)") do
        cmdln = cmdln:gsub("%$"..j.."%s*", (self["expand_"..j] and (self["expand_"..j](self, TreeNode)) or getField(j:lower()) or "").." ");
      end;
    end;
    TreeNode.command = cmdln;
  end;
  --
  function clTool:getSources(par)
    local function getField(name)
      return par[name] or self.__par and self.__par[name] or nil;
    end;
    local sources = clTargetList:new();
    sources.cflags        = class.StrList:new();
    sources.defines       = class.StrList:new();
    sources.incdir        = class.StrList:new();
    sources.libdir        = class.StrList:new();
    sources.libs          = class.StrList:new();
    sources.from          = class.StrList:new();
    sources.base          = fn_abs(par.base or ".");
    sources.needs         = clTargetList:new();
    sources.prerequisites = clTargetList:new();
    sources.tool          = self;
    local ParValue;
    -- src = ...
    ParValue = getField("src");
    if ParValue then
      if type(ParValue) == "string" then ParValue = split(ParValue); end;
      if type(ParValue) == "table" then
        local exts = split(getField("ext"));
        for _, n in ipairs(ParValue) do
          local list, f;
          local mask = fn_join(par.base, exts and fn_defaultExt(n, exts[1]) or n);
          if mask:find("*") then
            list = fn_files_from_mask(mask);
            if #list == 0 then quitMF("*ERROR: cant find source file '%s'.", mask); end;
          else
            list = {mask};
          end;
          if list then
            for _, i in ipairs(list) do
              sources:new_sourcefile(i);
            end;
          else
            for _, ext in ipairs(exts) do
              f = sources:new_sourcefile(par.base, fn_defaultExt(n, ext));
              if f then break; end;  -- source file found ...
            end;
            if not f then
              quitMF("*ERROR: cant find source file '%s'.", n);
            end;
          end;
        end;
        par.src = nil;
      else
        quitMF("invalid parameter `src`."); --TODO
      end;
    end;
    -- inputs = ...
    ParValue = getField("inputs");
    if ParValue  then
      if class(ParValue) then ParValue = {ParValue}; end;
      for _, node in ipairs(ParValue) do
        sources:add(node);
        if node.prerequisites then
          for pre in node.prerequisites() do
            if not sources.prerequisites:find(pre[1]) then
              sources.prerequisites:add(pre);
            end;
          end;
        end;
        -- TODO: copy more fields?
      end;
      par.inputs = nil;
    end;
    -- libs = ...
    ParValue = getField("libs");
    if ParValue    then
      sources.libs:add(ParValue);
      par.libs = nil;
    end;
    -- libdir = ...
    ParValue = getField("libdir");
    if ParValue  then
      sources.libdir:add(ParValue);
      par.libdir = nil;
    end;
    -- cflags = ...
    ParValue = getField("cflags");
    if ParValue  then
      sources.cflags:add(ParValue);
      par.cflags = nil;
    end;
    -- needs = ...
    ParValue = getField("needs");
    if ParValue   then
      local function pstring(need)
        if type(need) == "string" then need = split(need); end;
        for _, ns in ipairs(need) do
          local n = Needs:find(ns);
          if not n then quitMF("make(): unknown need '%s'.", ns); end
          for _, f in ipairs(Needs.fields) do
            if n[f] then
              if f == "prerequisites" then
                for pre in n[f]() do
                  local tgt = Targets:find(pre);
                  if tgt then
                    for node in tgt.deps() do
                      if not sources.prerequisites:find(node[1]) then
                        sources.prerequisites:add(node);
                      end;
                    end;
                  else
                    quitMF("no target '%s' defined.", pre);
                  end;
                end;
              else
                sources[f]:add(n[f]);
              end;
            end;
          end;
        end;
      end;
      local function pnode(need)
        for _, n in ipairs(need) do
          if type(n) == "string" then
            pstring(n);
          elseif class(n, "TreeNode") then
            sources.needs:add(n);
          elseif class(n, "TargetList") then
            pnode(n)
          else
            quitMF("invalid parameter type in 'needs'.");
          end;
        end;
      end;
      if type(ParValue) == "string" then
        pstring(ParValue);
      elseif class(ParValue, "TreeNode") then
        pnode({ParValue});
      elseif class(ParValue, "TargetList") then
        pnode(ParValue);
      elseif class(ParValue) then
        quitMF("invalid parameter type in 'needs'.");
      elseif type(ParValue) == "table" then
        pnode(ParValue);
      end;
      par.needs = nil;
    end;
    -- defines = ...
    ParValue = getField("defines");
    if ParValue then
      sources.defines:add(ParValue);
      par.defines = nil;
    end;
    -- incdir = ...
    ParValue = getField("incdir");
    if ParValue  then
      if type(par.incdir) == "string" then ParValue = split(ParValue); end;
      local base = getField("base");
      for _, d in ipairs(ParValue) do
        sources.incdir:add(fn_join(base, d));
      end;
      par.incdir = nil;
    end;
    -- deps = ...
    ParValue = getField("deps");
    if par.deps    then
      if class(ParValue, "GeneratedFile") then
        sources.prerequisites:add(ParValue)
      elseif type(ParValue) == "table" then
        for _, ts in ipairs(ParValue) do
          if class(ts, "TreeNode") then
            sources.prerequisites:add(ts);
          else
            quitMF("make(): parameter 'deps' needs to be a target or a list of targets.");
          end;
        end;
      else
        quitMF("make(): parameter 'deps' needs to be a target or a list of targets.");
      end;
      par.deps = nil;
    end;
    -- prerequisites = ...
    ParValue = getField("prerequisites");
    if ParValue then
      if type(ParValue) == "string" then ParValue = split(ParValue); end;
      if type(ParValue) == "table" then
        for _, ts in ipairs(ParValue) do
          local t = Targets:find(ts);
          if not t then quitMF("no target '%s' defined.", ts); end;
          sources.prerequisites:add(t[1]); --get real need name in case of alias.
        end;
      else
        quitMF("make(): parameter 'prerequisites' needs to be a string or a list of strings.");
      end;
      par.prerequisites = nil;
    end;
    -- from = ...
    ParValue = getField("from");
    if ParValue then
      sources.from:add(ParValue);
      par.from = nil;
    end;
    --
    par.base = nil;
    return sources;
  end; -- getSources(par)
  --
  Rule = class.Tool:new();
  --
  function Rule:action_create(...)
    local result;
    local par = self:checkParam(...);
    --
    local function getField(name)
      return par[name] or self.__par and self.__par[name] or nil;
    end;
    --
    par.odir   = getField("odir");
    par.base   = getField("base");
    par.ext    = getField("ext");
    par.func   = getField("func");
    par.prog   = getField("prog");
    par.action = getField("action");
    --
    -- parameter checks.
    if type(getField("action")) ~= "string" then quitMF("%s(): no valid 'action' parameter given.", self[1]); end;
    if par.prog and par.func then quitMF("%s(): .proc and .func cant be used at the same time.", self[1]); end;
    if par.prog then
      local prog = par.prog;
      if type(prog) == "string" then
        par.prog = nil;
      elseif class(prog, "File") then
        par.needs = clTargetList:new(par.needs);
        par.needs:add(prog);
        prog = par.prog[1];
        par.prog = nil;
      else
        quitMF("rule(): invalid parameter 'prog'.");
      end;
      prog = fn_canonical(prog);
      if par.action:find("$PROG%f[%U]") then
        par.action = par.action:gsub("$PROG", prog);
      else
        quitMF("rule(): no field '$PROG' in 'action' found.");
      end;
    end;
    if par.action:find("$SOURCE%f[%U]") and par.action:find("$SOURCES%f[%U]") then
      quitMF("rule(): $SOURCE and $SOURCES can't be used at the same time.");
    end;
    if not par.action:find("$OUTFILE%f[%U]") then
      quitMF("rule(): $OUTFILE needed in .action parameter.");
    end;
    --
    local src = self:getSources(par);
    if par.action:find("$SOURCE%f[%U]") then -- $SOURCE => one node for each source
      result = clTargetList:new();
      for sf in src() do
        local fn = fn_basename(sf[1]);
        fn = (par[1] or "*"):gsub("%*", fn);
        fn = fn_forceExt(fn, getField("outext"));
        local of = result:new_generatedfile(getField("odir"), fn);
        of.prerequisites = src.prerequisites;
        of.tool    = self;
        of.deps    = sf;
        of.defines = src.defines;
        of.cflags  = src.cflags;
        of.incdir  = src.incdir;
        of.libdir  = src.libdir;
        of.libs    = src.libs;
        of.needs   = src.needs;
        of.from    = src.from;
        of.base    = src.base;
        of.func    = par.func;
        of.action  = par.action;
        of.__par   = par;
        if class(sf, "SourceFile") then
          sf.deps    = (not MakeScript.NODEPS and self:readDepFile(of)) or nil;
        end;
      end;
    else -- $SOURCES => one node for ALL sources
      local fn = par[1];
      fn = fn_forceExt(fn, getField("outext"));
      result = Targets:new_generatedfile(getField("odir"), fn);
      result.prerequisites = src.prerequisites;
      result.tool    = self;
      result.deps    = src;
      result.defines = src.defines;
      result.cflags  = src.cflags;
      result.incdir  = src.incdir;
      result.libdir  = src.libdir;
      result.libs    = src.libs;
      result.needs   = src.needs;
      result.from    = src.from;
      result.type    = par.type;
      result.func    = par.func;
      result.action  = par.action;
      result.__par   = par;
    end;
    --
    par[1] = nil;
    return result;
  end;

  Rule:add_action("create");
  function Rule:action_define(...)
    local par = self:checkParam(...);
    local toolName = par.name or "tool";
    par.name = nil;
    local tool = clTool:new{toolName, __par = par};
    --tool._singletarget = not not (toolName:find(".prog$") or toolName:find(".dlib$") or toolName:find(".slib$"));
    tool.__default = function(...) return self.action_create(tool, ...); end;
    return tool;
  end;

  Rule:add_action("define");
  clMakeScript.rule = Rule;
  --
  local File = class.Tool:new{"file",
    __par = {
      ext      = ".*",
      outext   = ".*",
      action = choose(WINDOWS, "copy", "cp") .. " $SOURCES $OUTFILE",
    }
  };

  function File:action_copy(...)
    local par = self:checkParam(...);
    local sources = self:getSources(par);
    if type(par.odir) ~= "string" then quitMF("file.copy(): no valid 'odir' parameter."); end;
    local targets = clTargetList:new();
    for sf in sources() do
      local dfn = sf[1];
      dfn = (dfn:find(sources.base) == 1) and dfn:gsub(sources.base.."/","") or dfn:match("([^/]*)$");
      local target = targets:new_generatedfile(par.odir, dfn);
      target.deps = sf;
      target.tool = self;
      target.action = par.action or self.__par.action;
      if not target.action then quitMF("%s(): no valid 'action' parameter given.", self[1]); end;
    end;
    return targets;
  end;

  File:add_action("copy");
  clMakeScript.file = File;
  --
  Group = class.Tool:new{
    SRC_EXT = ".*";
  };

  function Group:action_create(...)
    local par = self:checkParam(...);
    if not par.inputs then
      local inputs = {};
      for i = 1, #par do
        inputs[i] = par[i];
        par[i] = nil;
      end;
      par.inputs = inputs;
    end;
    local res = self:getSources(par);
    for n in pairs(par) do quitMF("%s(): parameter '%s' not processed.", self[1] or "rule", n); end;
    return res;
  end;

  Group:add_action("create");
  clMakeScript.group = Group;
  --
end;
--
do -- [special targets] =====================================================
  --
  local function action_clean()
    for f in GeneratedFiles() do
      if not f.target then f:delete(); end;
    end;
  end;

  local function action_CLEAN()
    GeneratedFiles:delete();
  end;
  --
  Targets:new_target("clean",{action = action_clean}).bForce = true; -- allways execute
  Targets:new_target("CLEAN",{action = action_CLEAN}).bForce = true; -- allways execute
  --
end;
--
-- [main] ===================================================================
--
Make(arg);
