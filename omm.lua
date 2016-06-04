#!/usr/bin/env lua
--[[ **One More Maketool**

## OMM, a lua based extensible build engine.

Inspired by and stealing code snippets from Steve Donovan's [lake].  

Using modified versions of 
Roland Yonaba's [30log] and Gary V. Vaughan's [optparse].

required 3rd party modules:
[luafilesystem], [winapi] / [luaposix]

(best viewed with a folding editor like [ZBS].)

[lake]:          https://github.com/stevedonovan/Lake
[30log]:         https://github.com/Yonaba/30log
[optparse]:      https://github.com/gvvaughan/optparse)
[luafilesystem]: https://github.com/keplerproject/luafilesystem/
[winapi]:        https://github.com/stevedonovan/winapi
[luaposix]:      https://github.com/luaposix/luaposix/
[ZBS]:           https://github.com/pkulchenko/ZeroBraneStudio

copyright (C) 2016 [Ulrich Schmidt](mailto:u.sch.zw@gmx.de)

The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]--------------------------------------------------------
--
--[[ **TODO:**

- Not well tested on linux yet. 
  Still some changes needed to work on linux properly in all cases. (see: TODO comments)

- optparse: better check for parameter values
  For instance "omm -j default" takes "default" as a -j parameter but as target.
  
- better english in messages and comments.

- More sophisticated needs handling.
  - OS specific needs
    - What is a good syntax for?
    - default/fallback needs?
  - Need aliases (done)

- M32/M64 handling.

- msc toolchain.
  - It is a untested skeleton right now.

- lua toolchain. what are useful actions to implement and what is a good syntax for?
  .strip action? (remove comments and whitespaces from source)
  .glue action?  (preload lua modules in main source)
  .program?      (make self running executable.)
  .ldoc?         (generate documentation)
  
- implement a patch ability.

- dependency file generation and handling.

- how to deal with zip/... achives?

- svn toolchain. 
  svn.checkout works, but need better ideas, HOW to deal with repositories at all.
  svn.checkout is not part of the make tree now. Threfore it is being executed 
  allways in pass 1. Should be executed in pass 3 only when the target requests it.
  A patch ability would be nice to apply local changes to the downloded files.
  - Maybe better implement a "repository" tool, that handles svn, git, zip, .. downloads
  
- correct silent/normal/verbose message print (doublecheck)

- make compiler warnings to errors? How to implement this? commandline? flag?

- create a documentation.

- create a test suite.

- remove old style pass3 when the new pass3 is well tested and noone complains.

--]]-------------------------------------------------------
--
local USAGE = [=[
omm 0.1-alpha
 A lua based extensible build engine.

Usage: omm [options] [target[,...]]
 
Options:

  -b, --always-make           Unconditionally make all targets.
  -f, --makefile=FILE         makefile to run. (default:"makefile.omm")
  -n, --just-print,           Don't actually run any command; just print them.
  -s, --nostrict              Don't compile strictly.
  -D, --define=DEFINES[,...]  DEFINEs for compilation. eg: "build_mode=debug,BUILD_DLL"
  
  -I, --import-needs=[FILE]   Read needs from needs definition file.
  -E, --export-needs=[FILE]   Append new needs to needs definition file.
  -N, --use-needs=[FILE]      Like '-I -E'.
  
  -j, --jobs=[N]              Run N jobs parallel (default: # of cores)
  -J, --fastjobs=[N]          Like '-j'. Faster but unordered job execution.
  
  -v, --verbose               Be verbose. print commands executed, ...
  -q, --quiet                 Don't echo commands executed
  -w, --print-warnings        Print some diagnostic warnings.
  
  -t, --toolchains=NAME[,...] Preload a Toolchain. This toolchain's tools may supersede
                              tools from other toolchains.
      --version               Display version information, then exit
  -h, --help                  Display this help, then exit

special targets:
 * clean    delete all intermediate files.
 * CLEAN    delete all intermediate and result files.
 
Please report bugs at u.sch.zw@gmx.de
]=];
--
--_DEBUG = true; -- enable some debugging output. see: dprint()
--
local MAKEFILENAME = "makefile.omm"; -- default makefile name.

--[[ How to prefix a external toolchain name.  
This prefix may trigger a search in a sub folder or simply be a filename prefix.
The predefined default will search a non-internal toolchain "lua" in a file
`"omm_lua.lua"` and afterward in `"tc_lua.lua"`. This way it becomes possible to 
override/extend the preloaded toolchains with self written external toolchains.
The internal prefix `"tc_"` is hardcoded and can be used to adress the preloaded 
module directly. eg. `require "tc_gnu"`
--]]--
local TOOLCHAIN_PREFIX = "omm_";
--
-- [oop, ...] ==================================================================
--
package.preload["33log"]    = function(...) 
  
  local pairs, ipairs, type, getmetatable, rawget, select =
        pairs, ipairs, type, getmetatable, rawget, select;
  local insert,       concat,       remove = 
        table.insert, table.concat, table.remove;
  
  local classinfo = {
    classcount  = 0;
    classes     = {};
  };
  
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
    dst = dst or {};
    for k, v in pairs(src) do
      dst[k] = v;
    end;
    return dst;
  end;
   
  local function pairsByKeys(t)
    local a = {};
    for n in pairs(t) do 
       insert(a, n); 
    end;
    table.sort(a, function(a, b)
       return (type(a) == type(b)) and (a < b)  or (type(a) < type(b))
      end
    );
    local i = 0;        -- iterator variable
    return function()   -- iterator function
      i = i + 1;
      return a[i], a[i] and t[a[i]];
    end;
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
      local kMT = classinfo.classes[n];
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
    
  local function class_dump(var, depth, ...) 
    local level, rtbl = ...;
    rtbl  = rtbl or {var};
    level = level or 0;
    depth = depth or 0; 
    --
    local t = type(var);
    local st = {};
    if t == "nil" then 
      return t;
    end;
    if t == "string" then
      -- string beautifiing can be done much better than this
      return("'" .. var:gsub("\n", "\\n"):sub(1, 64) .. "'");
    end;
    if t == "number" then
      return var;
    end;
    if t == "boolean" then
      return (var and "true") or "false";
    end;
    if (t == "table") then
      local bObject;
      if isClass(var) then
        bObject = true;
        if rawget(var,'__classname') then
          insert(st, ('<class %s>#%i '):format((rawget(var,'__classname')), #var));
        else
          insert(st, ('<object of %s>#%i '):format((rawget(getmetatable(var), '__classname')), #var));
        end;
      end;
      if (level < depth) then 
        local rtptr = #rtbl
        local function isrecursive(v)
          if type(v) ~= "table" then return false; end;
          for i = 1, rtptr do
            if v == rtbl[i] then return i; end;
          end
          return false
        end;
        insert(st, "{");
        for _, v in pairsByKeys(var) do
          if (type(v) == "table") and not isrecursive(v) then
            insert(rtbl, v);
          end
        end
        local fields;
        for k, v in pairsByKeys(var) do
          fields = true;
          if type(k) == "number" then
            insert(st, "[" .. k .. "]=");
          else
            insert(st, k .. "=");
          end;
          if v == _G then
            insert(st, "_G"); 
          else
            local ir = isrecursive(v)
            if ir then
              insert(st, "<Table#".. ir ..">")
            else
              insert(st, class_dump(v, depth, level + 1, rtbl));
            end;
          end;
          insert(st, ", ");
        end
        if fields then remove(st) end;
        insert(st, "}");
      elseif not bObject then
        insert(st, "<table>");
      end 
      return(concat(st))
    end;-- table
    return "<"..t..">"
  end;
  
  local function class_tostring(self)
    return class_dump(self, self.__dumpdepth);
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
    if self.__init then
      if type(self.__init) == 'table' then
        copy(self.__init, instance);
      else
        return self.__init(instance, ...);
      end
    end
    return instance;
  end;
  
  local function class_singleton(self, ...)
    local o = self:new(...);
    self.new = function(self, ...)
      return o;
    end;
    return o;
  end;
  
  local function class_is_singleton(self)
    return self.new ~= class_new;
  end;
  
  local function class_subclass(self, extra_params)
    local newClass       = copy(extra_params, copy(self));
    classinfo.classcount = classinfo.classcount + 1;
    newClass.__classname      = extra_params.__classname or "class#" .. classinfo.classcount;
    newClass.super       = self;
    newClass             = setmetatable(newClass, self);
    if classinfo.classes[newClass.__classname] then 
      error(("subclass(): class '%s' already defined."):format(newClass.__classname), 2); 
    end;
    classinfo.classes[newClass.__classname] = newClass;
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
  local clBase = setmetatable({
      __classname  = "class";            
      __index      = class_index;
      __tostring   = class_tostring;     
      __dumpdepth  = 1;
      __init       = class_init;         
      new          = class_new;
      singleton    = class_singleton;
      is_singleton = class_is_singleton;
      subclass     = class_subclass;
      is           = class_is;
      protect      = class_protect;
      unprotect    = class_unprotect;
    },{
      __tostring  = class_tostring;
    }
  );
  --
  class = setmetatable({
      -- Base class.
      Base = clBase;
    },{
      __call      = isClass;
      __tostring  = function(self) return class_dump(self, 1); end;
      __index     = classinfo;
    }
  );
  --
  classinfo.classcount = 1;
  classinfo.classes[clBase.__classname] = clBase;
  --
  return class;
  --  
end;

package.preload["Optparse"] = function(...) 
  
  local assert       = assert
  local error        = error
  local getmetatable = getmetatable
  local ipairs       = ipairs
  local pairs        = pairs
  local print        = print
  local require      = require
  local setmetatable = setmetatable
  local tostring     = tostring
  local type         = type
  
  local io_open      = io.open
  local io_stderr    = io.stderr
  local os_exit      = os.exit
  local string_len   = string.len
  local table_insert = table.insert
  
  local function getmetamethod (x, n)
    local m = (getmetatable (x) or {})[n]
    if type (m) == "function" then return m end
    return (getmetatable (m) or {}).__call
  end
  
  local function len (x)
    local m = getmetamethod (x, "__len")
    if m then return m (x) end
    if type (x) ~= "table" then return #x end
  
    local n = #x
    for i = 1, n do
      if x[i] == nil then return i -1 end
    end
    return n
  end
  
  local function last (t)
    return t[len (t)]
  end
  
  local optional, required
  local function normalise (self, arglist)
    local normal = {}
    local i = 0
    while i < len (arglist) do
      i = i + 1
      local opt = arglist[i]
  
      -- Split '--long-option=option-argument'.
      if opt:sub (1, 2) == "--" then
        local x = opt:find ("=", 3, true)
        if x then
          local optname = opt:sub (1, x -1)
  
    -- Only split recognised long options.
    if self[optname] then
            table_insert (normal, optname)
            table_insert (normal, opt:sub (x + 1))
    else
      x = nil
    end
        end
  
        if x == nil then
    -- No '=', or substring before '=' is not a known option name.
          table_insert (normal, opt)
        end
  
      elseif opt:sub (1, 1) == "-" and string_len (opt) > 2 then
        local orig, split, rest = opt, {}
        repeat
          opt, rest = opt:sub (1, 2), opt:sub (3)
  
          split[#split + 1] = opt
  
    -- If there's no handler, the option was a typo, or not supposed
    -- to be an option at all.
    if self[opt] == nil then
      opt, split = nil, { orig }
  
          -- Split '-xyz' into '-x -yz', and reiterate for '-yz'
          elseif self[opt].handler ~= optional and
            self[opt].handler ~= required then
      if string_len (rest) > 0 then
              opt = "-" .. rest
      else
        opt = nil
      end
  
          -- Split '-xshortargument' into '-x shortargument'.
          else
            split[#split + 1] = rest
            opt = nil
          end
        until opt == nil
  
        -- Append split options to normalised list
        for _, v in ipairs (split) do table_insert (normal, v) end
      else
        table_insert (normal, opt)
      end
    end
  
    normal[-1], normal[0]  = arglist[-1], arglist[0]
    return normal
  end
  
  local function set (self, opt, value)
    local key = self[opt].key
    local opts = self.opts[key]
  
    if type (opts) == "table" then
      table_insert (opts, value)
    elseif opts ~= nil then
      self.opts[key] = { opts, value }
    else
      self.opts[key] = value
    end
  end
  
  function optional (self, arglist, i, value)
    if i + 1 <= len (arglist) and arglist[i + 1]:sub (1, 1) ~= "-" then
      return self:required (arglist, i, value)
    end
  
    if type (value) == "function" then
      value = value (self, arglist[i], nil)
    elseif value == nil then
      value = true
    end
  
    set (self, arglist[i], value)
    return i + 1
  end
  
  
  function required (self, arglist, i, value)
    local opt = arglist[i]
    if i + 1 > len (arglist) then
      self:opterr ("option '" .. opt .. "' requires an argument")
      return i + 1
    end
  
    if type (value) == "function" then
      value = value (self, opt, arglist[i + 1])
    elseif value == nil then
      value = arglist[i + 1]
    end
  
    set (self, opt, value)
    return i + 2
  end
  
  
  local function finished (self, arglist, i)
    for opt = i + 1, len (arglist) do
      table_insert (self.unrecognised, arglist[opt])
    end
    return 1 + len (arglist)
  end
  
  
  local function flag (self, arglist, i, value)
    local opt = arglist[i]
    if type (value) == "function" then
      set (self, opt, value (self, opt, true))
    elseif value == nil then
      local key = self[opt].key
      self.opts[key] = true
    end
  
    return i + 1
  end
  
  
  local function help (self)
    print (self.helptext)
    os_exit (0)
  end
  
  
  local function version (self)
    print (self.versiontext)
    os_exit (0)
  end
  
  
  
  local boolvals = {
    ["false"] = false, ["true"]  = true,
    ["0"]     = false, ["1"]     = true,
    no        = false, yes       = true,
    n         = false, y         = true,
  }
  
  
  local function boolean (self, opt, optarg)
    if optarg == nil then optarg = "1" end -- default to truthy
    local b = boolvals[tostring (optarg):lower ()]
    if b == nil then
      return self:opterr (optarg .. ": Not a valid argument to " ..opt[1] .. ".")
    end
    return b
  end
  
  
  local function file (self, opt, optarg)
    local h, errmsg = io_open (optarg, "r")
    if h == nil then
      return self:opterr (optarg .. ": " .. errmsg)
    end
    h:close ()
    return optarg
  end
  
  local function opterr (self, msg)
    local prog = self.program
    -- Ensure final period.
    if msg:match ("%.$") == nil then msg = msg .. "." end
    io_stderr:write (prog .. ": error: " .. msg .. "\n")
    io_stderr:write (prog .. ": Try '" .. prog .. " --help' for help.\n")
    os_exit (2)
  end
  
  local function on (self, opts, handler, value)
    if type (opts) == "string" then opts = { opts } end
    handler = handler or flag -- unspecified options behave as flags
  
    local normal = {}
    for _, optspec in ipairs (opts) do
      optspec:gsub ("(%S+)",
                    function (opt)
                      -- 'x' => '-x'
                      if string_len (opt) == 1 then
                        opt = "-" .. opt
  
                      -- 'option-name' => '--option-name'
                      elseif opt:match ("^[^%-]") ~= nil then
                        opt = "--" .. opt
                      end
  
                      if opt:match ("^%-[^%-]+") ~= nil then
                        -- '-xyz' => '-x -y -z'
                        for i = 2, string_len (opt) do
                          table_insert (normal, "-" .. opt:sub (i, i))
                        end
                      else
                        table_insert (normal, opt)
                      end
                    end)
    end
  
    -- strip leading '-', and convert non-alphanums to '_'
    local key = last (normal):match ("^%-*(.*)$"):gsub ("%W", "_")
  
    for _, opt in ipairs (normal) do
      self[opt] = { key = key, handler = handler, value = value }
    end
  end
  
  
  local function parse (self, arglist, defaults)
    self.unrecognised, self.opts = {}, {}
  
    arglist = normalise (self, arglist)
  
    local i = 1
    while i > 0 and i <= len (arglist) do
      local opt = arglist[i]
  
      if self[opt] == nil then
        table_insert (self.unrecognised, opt)
        i = i + 1
  
        -- Following non-'-' prefixed argument is an optarg.
        if i <= len (arglist) and arglist[i]:match "^[^%-]" then
          table_insert (self.unrecognised, arglist[i])
          i = i + 1
        end
  
      -- Run option handler functions.
      else
        assert (type (self[opt].handler) == "function")
  
        i = self[opt].handler (self, arglist, i, self[opt].value)
      end
    end
  
    -- Merge defaults into user options.
    for k, v in pairs (defaults or {}) do
      if self.opts[k] == nil then self.opts[k] = v end
    end
  
    -- metatable allows `io.warn` to find `parser.program` when assigned
    -- back to _G.opts.
    return self.unrecognised, setmetatable (self.opts, {__index = self})
  end
  
  
  local function set_handler (current, new)
    assert (current == nil, "only one handler per option")
    return new
  end
  
  
  local function _init (self, spec)
    local parser = {}
  
    parser.versiontext, parser.version, parser.helptext, parser.program =
      spec:match ("^([^\n]-(%S+)\n.-)%s*([Uu]sage: (%S+).-)%s*$")
  
    if parser.versiontext == nil then
      error ("OptionParser spec argument must match '<version>\\n" ..
             "...Usage: <program>...'")
    end
  
    -- Collect helptext lines that begin with two or more spaces followed
    -- by a '-'.
    local specs = {}
    parser.helptext:gsub ("\n  %s*(%-[^\n]+)",
                          function (spec) table_insert (specs, spec) end)
  
    -- Register option handlers according to the help text.
    for _, spec in ipairs (specs) do
      local options, handler = {}
  
      -- Loop around each '-' prefixed option on this line.
      while spec:sub (1, 1) == "-" do
  
        -- Capture end of options processing marker.
        if spec:match "^%-%-,?%s" then
          handler = set_handler (handler, finished)
  
        -- Capture optional argument in the option string.
        elseif spec:match "^%-[%-%w]+=%[.+%],?%s" then
          handler = set_handler (handler, optional)
  
        -- Capture required argument in the option string.
        elseif spec:match "^%-[%-%w]+=%S+,?%s" then
          handler = set_handler (handler, required)
  
        -- Capture any specially handled arguments.
        elseif spec:match "^%-%-help,?%s" then
          handler = set_handler (handler, help)
  
        elseif spec:match "^%-%-version,?%s" then
          handler = set_handler (handler, version)
        end
  
        -- Consume argument spec, now that it was processed above.
        spec = spec:gsub ("^(%-[%-%w]+)=%S+%s", "%1 ")
  
        -- Consume short option.
        local _, c = spec:gsub ("^%-([-%w]),?%s+(.*)$",
                                function (opt, rest)
                                  if opt == "-" then opt = "--" end
                                  table_insert (options, opt)
                                  spec = rest
                                end)
  
        -- Be careful not to consume more than one option per iteration,
        -- otherwise we might miss a handler test at the next loop.
        if c == 0 then
          -- Consume long option.
          spec:gsub ("^%-%-([%-%w]+),?%s+(.*)$",
                     function (opt, rest)
                       table_insert (options, opt)
                       spec = rest
                     end)
        end
      end
  
      -- Unless specified otherwise, treat each option as a flag.
      on (parser, options, handler or flag)
    end
  
    return setmetatable (parser, getmetatable (self))
  end
  
  
  --
  return setmetatable ({
    prototype = setmetatable ({
      -- Prototype initial values.
      opts        = {},
      helptext    = "",
      program     = "",
      versiontext = "",
      version     = 0,
    }, {
      _type = "OptionParser",
  
      __call = _init,
  
      __index = {
        boolean  = boolean,
        file     = file,
        finished = finished,
        flag     = flag,
        help     = help,
        optional = optional,
        required = required,
        version  = version,
  
        on     = on,
        opterr = opterr,
        parse  = parse,
      },
    }),
  }, {
    _type = "Module";
    -- Pass through options to the OptionParser prototype.
    __call = function (self, ...) return self.prototype (...) end;
    __index = function (self, name)
      local ok, t = pcall (require, "Optparse." .. name)
      if ok then
        rawset (self, name, t)
        return t
      end
    end,
  })
  
end;
--
-- [] ==========================================================================
--
local REQUIRED = pcall(debug.getlocal, 4, 1);
local class    = require "33log";
local lfs      = require "lfs";
local attributes, touch, mkdir = lfs.attributes, lfs.touch, lfs.mkdir;
--
--
local concat, insert, remove = table.concat, table.insert, table.remove;
local type, select, ipairs, pairs = type, select, ipairs, pairs;
local max       = math.max;
--
local DIRSEP    = package.config:sub(1, 1);
local WINDOWS   = DIRSEP == '\\' or nil;
local MAKELEVEL = 0;
local Make;
--
--=== [utils] ==================================================================
local warning, warningMF, quit, quitMF, dprint, chdir, choose, pick, split, 
      split2, collect, shell, execute, roTable, pairsByKeys, subst, substitute, 
      flatten_tbl, luaVersion, 
      ENV, PWD, LUAVER, NUMCORES;
do
  local update_pwd;
  --
  local dir_stack = {};
  local push, pop = table.insert, table.remove;
  function update_pwd()
    local dir = lfs.currentdir();
    if WINDOWS then dir = dir:lower() end;
    PWD = dir:gsub("\\", "/");
  end;
  
  function chdir(path)
    if not path then return end
    if path == '!' or path == '<' then
      lfs.chdir(pop(dir_stack))
    else
      push(dir_stack, lfs.currentdir())
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
    for n in pairs(t) do 
       insert(a, n); 
    end;
    table.sort(a, function(a, b)
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
        cond = cond~='0' and cond~='false'
    end
    if cond then return v1 else return v2 end;
  end;
  
  function pick(a, b, ...)
    if a ~= nil then 
      return a 
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

  function split2(s, delim)
    return s:match('([^'..delim..']+)'..delim..'(.*)')
  end;

  function collect(table, field)
    local res = {}
    for _, o in ipairs(table) do
      insert(res, o[field]);
    end;
    return res;
  end;

  function shell(cmd, ...)
    cmd = subst(cmd):format(...)
    local inf = io.popen(cmd..' 2>&1','r');
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
    local res1, _, res3 = os.execute(cmd)
    if LUAVER == "LUA5.1" or LUAVER == "LUAJIT" then
      return res1 == 0, res1;
    else
      return res1, res3;
    end
  end;
  
  function subst(str, exclude, T)
    local count;
    T = T or _G;
    repeat
      local excluded = 0
      str, count = str:gsub('%$%(([%w,_]+)%)', function (f)
          if exclude and exclude[f] then
            excluded = excluded + 1;
            return '$('..f..')';
          else
            --local s = T[f]
            --if not s then return ''
            --else return s end
            return T[f] or "";
          end
        end
      )
    until count == 0 or exclude;
    return str;
  end;

  function substitute(str, T) 
    return subst(str, nil, T);
  end;

  function flatten_tbl(tbl, n)
    local result = {};
    for i = 1, n or #tbl do
      if type(tbl[i]) == "table" then
        local t = flatten_tbl(tbl[i]);
        for j = 1, #t do 
          insert(result, t[j]); 
        end;
      elseif tbl[i] ~= nil then 
        insert(result, tbl[i]); 
      end;
    end;
    return result;
  end;
  -- debug print when `_DEBUG = true`
  function dprint(msg, ...)
    if _DEBUG then print(msg:format(...)); end;
  end;
  --
  ENV = setmetatable({}, {
      __index = function(self,key)
        return os.getenv(key)
      end;
      __newindex = function(self, key, value)
        local M = require("winapi") or require("posix") or quitMF("ENV[]: need winapi/posix for environment writes.", 2);
        M.setenv(key, value);
      end;
    }
  );
  
  --
  update_pwd();
  --
end;

--
do -- [list classes] ===========================================================
  --
  local clList   = class.Base:subclass{
    __classname = "List";
    __call = function(self) -- iterator
      local i = 0;
      return function()
        i = i + 1;
        return self[i];
      end;
    end;
  };
  
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
      for _, v in ipairs(tbl) do
        insert(self, v);
      end;
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
      if v[field] == value then
        return v;
      end;
    end;
  end;
  
  clList.erase   = function(self, l2)
    for _, v in ipairs(l2) do
      local idx = self:index(v);
      if idx then
        remove(self, idx);
      end;
    end;
  end;
 
  clList.concat  = function(self, field, sep)
    local res = {};
    for _, o in ipairs(self) do
      insert(res, o[field]);
    end;
    return concat(res, sep or " ");
  end;

  class.List = clList;
  --
  -- [unique list class] ==============================================
  --
  local clUList    = clList:subclass{
    __classname      = "UList";
    __key       = 1;       -- default
    __allowed   = "class"; -- default
  };
  
  clUList.__init   = function(self, ...)
    clUList.super.__init(self, ...);
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
      if not self.__dir[item[kf]] then
        insert(self, item);
        self.__dir[item[kf]] = item;
      else
        error(("cant overwrite value '%s'"):format(item[kf]));
        --return nil, self.__dir[item[kf]];
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
  class.UList = clUList;
  --
  -- [string list class] ===============================================
  --
  local clStrList  = clList:subclass{
    __classname      = "StringList";
  };
  
  clStrList.__init = function(self, stringlist, ...)
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
    if type(item) == "string" then 
      item = split(item, delim);
    end;
    if type(item) == "table" then  
      for _, v in ipairs(item) do 
        if type(v) ~= "string" then 
          quit("<%s>: parameter needs to be a string or a list of strings.", self.__classname, 2);
        end;
        if #v > 0 and not self.__dir[v] then
          insert(self, v);
          self.__dir[v] = v;
        end;
      end;
    else
      quit("parameter needs to be a string or a list of strings.", 2);
    end;
    return self;
  end;
  
  clStrList.find   = function(self, value)
    return self.__dir[value];
  end;
  
  clStrList.concat = function(self, sep)
    return concat(self, sep or " ");
  end;
  class.StrList = clStrList;
  --
end; -- list classes
--
----- [filename and path functions] ============================================
local fn_temp,     fn_isabs,      fn_canonical,  fn_join,      fn_isFile,   
      fn_isDir,    fn_defaultExt, fn_exists,     fn_forceExt,  fn_splitext,  
      fn_get_ext,  fn_splitpath,  fn_ensurePath, fn_basename,  fn_path_lua,  
      fn_abs,      fn_which,      fn_filetime,   fn_get_files, fn_files_from_mask,
      fn_get_directories;
do
  --
  local gsub = string.gsub;
  --
  function fn_temp ()
    local res = os.tmpname();
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

  function fn_join(...)
    local param = flatten_tbl({select(1, ...)}, select("#", ...))
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
    return concat(param, "/", idx)
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
    if attributes(fname) ~= nil then
      return fname;
    end;
    return nil;
  end;
  
  function fn_forceExt(fname, ext)
    if #ext > 0 and (ext:sub(1,1) ~= ".") then ext = "." .. ext end;
    return gsub(fname, "%.[%w_]*$", "") .. ext;
  end;

  function fn_splitext(path)
    local i = #path;
    local ch = path:sub(i, i);
    while i > 0 and ch ~= '.' do
      if ch == '/' or ch == '\\' then
        return path,''
      end
      i = i - 1;
      ch = path:sub(i, i)
    end
    if i == 0 then
      return path, '';
    else
      return path:sub(1, i - 1), path:sub(i);
    end;
  end;
  
  function fn_get_ext(path)
    local _, p2 = fn_splitext(path)
    return p2
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
    -- shorten path by removing ".."s.
    while path:find("/[^%./]+/%.%./") do
      path = path:gsub("/[^%./]+/%.%./", "/");
    end;
    path = path:gsub("/[^%./]+/%.%.$", "");
    return path;
  end;

  function fn_which(prog)
    if fn_isabs(prog) then return prog end;
    if WINDOWS then -- no 'which' commmand, so do it directly
      -- use the PATHEXT environment var. This way we find executable scripts too.
      local pathext = split(ENV.PATHEXT:lower(), ';')
      if fn_get_ext(prog) ~= '' then 
        pathext = {''}
      end;
      local path = split(ENV.PATH, ';')
      for _, dir in ipairs(path) do
        dir = fn_path_lua(dir);
        for _, ext in ipairs(pathext) do
          local f = fn_exists(dir, prog..ext)
          if f then return f end;
        end;
      end;
      return false;
    else
      local res = shell('which %s 2> /dev/null',prog);
      if res == '' then return false end;
      return res;
    end
  end;
 
  function fn_filetime(fname)
    return attributes(fname, 'modification') or -1;
  end;
  
  function fn_get_files(files, path, pat, recurse)
    for f in lfs.dir(path) do
      if f ~= '.' and f ~= '..' then
        local file = f;
        if path ~= '.' then file = fn_join(path, file) end;
        if recurse and fn_isDir(file) then
          fn_get_files(files, file, pat, recurse);
        elseif f:find(pat) then
          insert(files, file);
        end;
      end;
    end;
  end;
  
  function fn_files_from_mask(mask, recurse)
    local path, pat = fn_splitpath(mask);
    if not pat:find('%*') then return nil end;
    local files = {};
    if path == '' then path = '.' end;
    -- turn shell-style wildcard into Lua regexp
    pat = pat:gsub('%.','%%.'):gsub('%*','.*')..'$'
    fn_get_files(files, path, pat, recurse);
    return files;
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
do -- [os & hardware detection ] =============================================== 
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
    local t = {nil, [false]  = 'LUA5.1', [true] = 'LUA5.2', [1/'-0'] = 'LUA5.3', [1] = 'LUAJIT' };
    return t[1] or t[1/0] or t[f()==f()];
  end;
  LUAVER = luaVersion();
  --
  local function getCores()
    if WINDOWS then
      return ENV.NUMBER_OF_PROCESSORS or 1;
    else
      local t = fn_get_directories("/sys/devices/system/cpu");
      for i= #t, 1, -1 do
        if not t[i]:find("/cpu[%d]+$") then 
          remove(t,i); 
        end;
      end;
      return #t
    end;
  end;
  NUMCORES = getCores();
  --
  dprint("Running on %s. %s cores detected.",  LUAVER, NUMCORES);
  --
end;
--
do -- [error handling] =========================================================
  --
  local scriptfile = REQUIRED and select(2, ...) or arg[0];
  --dprint(scriptfile);
  --
  function warning(reason, ...)
    if not Make.options or Make.options.verbose or Make.options.print_warnings then
      reason = reason or '?'
      io.stderr:write(reason:format(...), '\n')
    end;
  end;
  
  function warningMF(reason, ...)
    if not Make or Make.options.verbose or Make.options.print_warnings then
      reason = reason or '?';
      local i = 0;
      local info;
      repeat
        i = i + 1;
        info = debug.getinfo(i);
        --dprint(scriptfile, info.short_src)
      until info.short_src ~= scriptfile;
      io.stderr:write(
        ("%s:%1.0d: - "):format(fn_canonical(info.short_src), info.currentline) ..
        reason:format(...) .. "\n"
      );
    end;
  end;
  
  function quit(reason, ...)
    reason = reason or '?';
    reason = reason:format(...);
    local idx = select("#", ...);
    local lvl = (idx == 0) and 1 or select(idx, ...);
    if type(lvl) ~= "number" then 
      lvl = 2; 
    else
      lvl = lvl + 1;
    end;
    local sFileLine = "";
    if lvl > 1 then
      local errtbl = debug.getinfo(lvl);
      sFileLine = ("%s:%1.0d: - "):format(fn_canonical(fn_abs(errtbl.short_src)), errtbl.currentline);
    end;
    reason = sFileLine .. reason;
    io.stderr:write(reason, '\n');
    os.exit(1);
  end;
  
  function quitMF(reason, ...)
    reason = reason or '?';
    local i = 0;
    local info;
    repeat
      i = i + 1;
      info = debug.getinfo(i);
      --dprint(scriptfile, info.short_src)
    until info.short_src ~= scriptfile;
    io.stderr:write(
      ("%s:%1.0d: - "):format(fn_canonical(info.short_src), info.currentline) ..
      reason:format(...) .. "\n"
    );
    os.exit(1);
  end;
  --
end;
--
----- [Concurrent job handling] ================================================
local concurrent_jobs; -- FORWARD(nj);
local job_execute;     -- FORWARD(cmd, callback);
local jobs_clear;      -- FORWARD();
do
  --
  local function command_line(cmd)
    local tmpfile, cmdline = fn_temp();
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
    local inf = io.open(tmpfile, 'r');
    callback(ok, code, inf)
    inf:close();
    os.remove(tmpfile);
  end;
  
  job_execute = execute_wrapper;
  jobs_clear  = function() end;
  local found_threads, winapi, posix;
  local n_threads, n_threads_forced = 1, false;
  local Processes  = class.List:new();
  local Outputs    = class.List:new();
  local spawn;     -- FORWARD(cmd)
  local wait;      -- FORWARD([cmd])
  local job_start; -- FORWARD(cmd)
  local jobs_wait; -- FORWARD()
  if WINDOWS then
    found_threads, winapi = pcall(require, 'winapi')
    if found_threads then 
      local comspec = ENV.COMSPEC .. ' /c ';
      --
      function spawn(cmd)
        --dprint("spawn", #Processes, n_threads)
        return winapi.spawn_process(comspec..cmd);
      end;
      --
      function wait()
        --dprint("wait", #Processes, n_threads)
        local idx, err = winapi.wait_for_processes(Processes, false)
        if err then 
          return nil, err 
        end;
        local p = Processes[idx]
        return idx, p:get_exit_code(), err
      end;
      --
    end;
  else
    found_threads, posix = pcall(require, 'posix')
    if found_threads then
      --
      function spawn(cmd)
        local cpid = posix.fork()
        if cpid == 0 then
          if posix.exec('/bin/sh','-c',cmd) == -1 then
            local _, code = posix.errno()
            os.exit(code)
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
  if found_threads then
    
    function job_start(cmd, callback)
      local cmdline, tmpfile = command_line(cmd)
      local p, r = spawn(cmdline)
      Outputs:insert{read=r, callback=callback, tmp=tmpfile}
      Processes:insert(p);
    end;
    
    function jobs_wait(cmd, callback)
      --dprint("jobs_wait", #Processes, n_threads)
      if #Processes == 0 then 
        if cmd then job_start(cmd, callback); end;
        return 
      end;
      local idx, code, err = wait();
      if cmd then job_start(cmd, callback); end;
      if err then return nil, err end;
      local item, p = Outputs[idx], Processes[idx];
      local inf, _ = io.open(item.tmp, 'r');
      Processes:remove(idx);
      Outputs:remove(idx);
      --dprint("callback", #Processes, n_threads)
      item.callback(code == 0, code, inf);
      if item.read then item.read:close() end;
      inf:close();
      if winapi then p:close(); end
      os.remove(item.tmp);
    end;
    
    function jobs_clear()
      --dprint("jobs_clear", #Processes, n_threads)
      while #Processes > 0 do 
        jobs_wait(); 
      end;
    end;
    
    function job_execute(cmd, callback)
      if n_threads < 2 then
        execute_wrapper(cmd, callback)
      else
        --dprint("job_execute", #Processes, n_threads)
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
    local toi = math.tointeger or tonumber;
    nj = toi(nj);
    if not found_threads then return nil, "concurrent_jobs(): no threading available. winapi/posix needed." end;
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
do -- [MakeScript Sandbox] =====================================================
  --
  clMakeScript = class.Base:subclass{
    __classname  = "MakeScript";
    __call  = function(self, filename)
      local makefile, err = loadfile (filename, "t", self);
      if makefile then 
        if setfenv then setfenv(makefile, self); end; -- lua 5.1
        local path = fn_splitpath(filename);
        if path ~= "" then chdir(path); end;
        clMakeScript.PWD = PWD;
        MAKELEVEL = MAKELEVEL or 0;
        MAKELEVEL = MAKELEVEL + 1;
        clMakeScript.MAKELEVEL = MAKELEVEL;
        makefile();
        MAKELEVEL = MAKELEVEL - 1;
        clMakeScript.MAKELEVEL = MAKELEVEL;
        if path ~= "" then chdir("<"); end;
      else 
        quit(err, 2);
      end;
    end,
    __index = function(self, i)
      local res = clMakeScript.super.__index(self, i);
      if res ~= nil or type(i) ~= "string" then return res; end;
      return Make.Tools(i); -- try to activate a _loaded_ Tool named i
    end,
    WINDOWS = WINDOWS,
    assert  = assert,
    ENV     = ENV,
    print   = print,
    string  = roTable(string),
    table   = roTable(table),
    quit    = quitMF,
    warning = warningMF,
  }; clMakeScript:protect();
  --
  MakeScript = clMakeScript:singleton{};
  --
end;
--
local runMake; -- FORWARD()
do -- [Make] ===================================================================
  --
  local optparser;
  --
  clMake = class.Base:subclass{
    __classname  = "Make",
    WINDOWS   = WINDOWS,
    utils     = roTable{
      chdir      = chdir, 
      choose     = choose,  
      pick       = pick,  
      split      = split,   
      split2     = split2 , 
      shell      = shell, 
      execute    = execute, 
      subst      = subst, 
      roTable    = roTable, 
      substitute = substitute, 
      which      = fn_which;
      ENV        = ENV
    },
    path      = roTable{
      temp            = fn_temp,     
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
    warning   = warning,
    warningMF = warningMF,
    quit      = quit,
    quitMF    = quitMF,
    --concurrent_jobs = concurrent_jobs;
  }; clMake:protect();
  clMake.__call = function(self, cmd) 
    local makefile, target;
    local function parseCommandline(cmd)
      local makefile, target;
      optparser = require "Optparse" (USAGE);
      cmd, clMake.options = optparser:parse(cmd);
      clMake.options.define = clMake.options.define and split(clMake.options.define, ",") or {};
      if #cmd > 1 then quit('too many or misspelled arguments in command line.', 0); end;
      target = cmd[1];
      --
      local defaultNeedsFilename = fn_join(fn_splitpath(arg[0]), "needs.omm"); --TODO: linux: default "~/needs.omm"
      if clMake.options.fastjobs then   -- -J, --fastjobs
        if tonumber(clMake.options.fastjobs) or not tonumber(clMake.options.jobs) then
          clMake.options.jobs = clMake.options.fastjobs;
        end;
      end;
      if clMake.options.jobs then       -- -j, --jobs
        if clMake.options.jobs == true then 
          clMake.options.jobs = NUMCORES; 
        end;
        local ok, err = concurrent_jobs(clMake.options.jobs)
        if not ok then warning(err) end;
      end;
      if Make.options.makefile then     -- -f, --makefile
        makefile = fn_defaultExt(Make.options.makefile, "omm");
      end;
      if Make.options.toolchains then   -- -t, --toolchains
        Make.Tools:load(split(Make.options.toolchains,","));
      end;
      if Make.options.use_needs then    -- -N, --use-needs=[FILE] 
        if type(Make.options.use_needs) == "boolean" then
          Make.options.use_needs = defaultNeedsFilename;
        end;
        Make.options.use_needs = fn_abs(Make.options.use_needs);
        if not Make.options.import_needs then
          Make.options.import_needs = true;
        end;
        if not Make.options.export_needs then
          Make.options.export_needs = true;
        end;
        
      end;
      if Make.options.import_needs then -- -I, --import-needs=[FILE]  
        if type(Make.options.import_needs) == "boolean" then
          Make.options.import_needs = Make.options.use_needs or defaultNeedsFilename;
        end;
        Make.options.import_needs = fn_abs(Make.options.import_needs);
        Make.Needs:import(Make.options.import_needs);
      end;
      if Make.options.export_needs then -- -E, --export-needs=[FILE]  
        if type(Make.options.export_needs) == "boolean" then
          Make.options.export_needs = Make.options.use_needs or defaultNeedsFilename;
        end;
        Make.options.export_needs = fn_abs(Make.options.export_needs);
      end;
      --
      return makefile, target;
    end;
    --
    cmd = cmd or {};
    if type(cmd) == "string" then cmd = split(cmd); end;
    if MAKELEVEL == 0 then -- parse the command line ...
      makefile, target = parseCommandline(cmd);
      --print(optparser.program .." "..optparser.version);
      if target and target:find("[^%w,]") then 
        quit("invalid command line parameter '%s'.\n(Try '%s -h' for help.)", target, optparser.program, 0); 
      end;
      self.target = target;
      makefile = makefile or MAKEFILENAME;
      -- Load preloaded toolchains in alphabetical order
      -- This way tollchain "gnu" becomes loaded before "msc".
      -- TODO: toolchain "msc" is still alpha/untested.
      -- Someone may prefer to load the toolchains in a explicit order.
      -- To Do so, you can write..
      --   `Make.Tools:load("gnu msc files targets repositories");`
      -- .. and remove the for loop below.
      for n in pairsByKeys(package.preload) do
        if n:find("^tc_") then
          Make.Tools:load(n);
        end;
      end;
      --
    else
      makefile = cmd[1];
    end;
    --
    if fn_isDir(makefile) then makefile = fn_join(makefile, MAKEFILENAME); end;
    if not fn_isFile(makefile) then quit("make(): cant find '%s'.", makefile, 0); end;
    --
    MakeScript(makefile);
    --
    if MAKELEVEL == 0 then runMake(); end; -- do the job ...
  end;
  
  --
  Make   = clMake:singleton();
  --
  package.preload["Make"]  = function(...) return Make; end;
  --
  clMakeScript.make = Make;
  --
end;
--
do -- [flag handling] ==========================================================
  --
  local function setFlag(n, v)
    clMakeScript[n] = v; 
  end;
  --
  local flagtable = {
    CC       = setFlag, 
    CXX      = setFlag, 
    OPTIMIZE = setFlag, 
    STRICT   = setFlag,
    DEBUG    = setFlag,
    PREFIX   = setFlag,
    SUFFIX   = setFlag,
    --M32     = setFlag, --TODO
    --PLAT    = setFlag, --TODO ??
    NODEPS   = setFlag, --TODO
  };
  --
  local function set_flags(params, ...)
    if select('#', ...) ~= 0   then quitMF("set_flags() expects one argument!\nDid you use {}?"); end;
    if type(params) ~= "table" then quitMF("set_flags() parameter needs to be a table/list."); end;
    --if make.MAKELEVEL ~= 1   then warning("set_flags() in nested makefiles ignored."); return; end;
    for n, v in pairs(params) do
      if flagtable[n] then flagtable[n](n, v);
      else quitMF("set_flags() unknown flag '%s'.", n); end; 
    end;  
  end;
  --
  local function get_flag(flag)
    if flagtable[flag] == setFlag then
      return clMakeScript[flag];
    else
      quitMF("get_flag() unknown flag '%s'.", flag);
    end;
  end;
  --
  clMake.set_flags = set_flags;
  clMake.get_flag  = get_flag;
  --
  set_flags{ -- default values
    OPTIMIZE  = "O2", 
    STRICT    = false, 
    DEBUG     = false, 
    --PREFIX  = "",
    --SUFFIX  = "",
    --M32     = false, 
    --PLAT    = choose(WINDOWS, "windows", ""); --TODO: other platforms
    NODEPS    = false, 
  };
  --
end;

--
--=== [file & target handling] =================================================
local clSourceFile, clTempFile, clTargetFile, clTargetList;
local Sources, Intermediates, ProgsAndLibs, Targets; 
do 
  local clMaketreeNode, clTarget, clFile, clGeneratedFile, target, default;
  --
  -- generic make tree node.
  clMaketreeNode = class.Base:subclass{
    __classname   = "FilesAndTargets";
  };
  
  clMaketreeNode.add_deps   = function(self, deps)
    if self.deps == nil then
      self.deps = clTargetList:new(deps)
    else
      self.deps:add(deps)
    end
  end;
  --
  clMaketreeNode.needsBuild = function(self)
    -- each subclass has to redefine this method.
    error("clMaketreeNode:needsBuild(): abstract method called.");
  end;

  clMaketreeNode.presDirty  = function(self)
    if self.prerequisites then
      if class(self.prerequisites, "StringList") then
        local pres = clTargetList:new();
        for n in self.prerequisites() do
          local t = Targets:find(n);
          if not t then quitMF("no target '%s' defined.", n); end;
          pres:add(t); 
        end;
        self.prerequisites = pres;
      end;
      return self.prerequisites:needsBuild();
    end;
    return false, -1;
  end;
  
  clMaketreeNode.depsDirty  = function(self)
    if self.deps then
      return self.deps:needsBuild();
    end;
    return false, -1; 
  end;
  --
  -- phony targets.
  clTarget = clMaketreeNode:subclass{
    __classname   = "Target";
    __init   = function(self, label, deps, ...)
      self[1] = label;
      if type(deps) == "table" then
        if type(deps.action) == "function" then
          self.action = deps.action;
        end;
        self.deps = deps and clTargetList:new(deps);
      end;
      return self;
    end;
  };
  
  clTarget.needsBuild = function(self)
    local dirty, modtime = self:presDirty();
    if self.deps then
      dirty, modtime = self.deps:needsBuild();
    end;
    self.dirty = self.dirty or dirty;
    --dprint(("clTarget.needsBuild():        %s %s"):format(self.dirty and "DIRTY" or "clean", self[1]));
    return self.dirty, modtime;
  end;
  --
  -- generic files.
  clFile = clMaketreeNode:subclass{
    __classname = "File";
    __init  = function(self, ...) -- ([<path>,]* filename)
      self[1] = fn_abs(fn_join(fn_join(flatten_tbl({...}, select("#", ...)))));
      return self;
    end;
  };
  
  clFile.needsBuild = function(self)           
    -- each subclass has to redefine this method.
    error("clFile:needsBuild(): abstract method called.");
  end;
  
  clFile.filetime   = function(self)
    return attributes(self[1], 'modification');
  end;
  
  clFile.exists     = function(self)
    return self:filetime() ~= nil;
  end;
  
  clFile.touch      = function(self)
    touch(self.filename, os.time());
  end;
  
  clFile.mkdir      = function(self)
    if not self:exists() then
      fn_ensurePath(fn_splitpath(self[1]))
    end;
  end;
  
  clFile.concat     = function(self) -- for compatibility with `clTargetList` filename concatenation.
    return self[1];
  end;
  --
  clSourceFile = clFile:subclass{
    __classname  = "SourceFile";
    __init  = function(self, ...) -- ([<path>,]* filename)
      clSourceFile.super.__init(self, ...);
      local fn = self[1];
      local sf = Sources.__dir[fn];
      if sf then return sf; end; -- already created entry ..
      if fn:find("[%*%?]+") then return; end; -- wildcard detected.
      if self:exists() then 
        Sources:add(self); 
      else
        quitMF("ERROR: cant find source file '%s'.", fn); 
      end;
      return self;
    end;
  };
  
  clSourceFile.needsBuild = function(self)
    --return false, self:filetime();
    if not self:exists() then
      quit("make(): sourcefile '%s' does not exist.", self[1], 0); 
    end;
    local dirty, modtime, filetime = false, -1, self:filetime();
    if self.deps then
      dirty, modtime = self.deps:needsBuild();
    end;
    self.dirty = self.dirty or dirty or filetime < modtime;
    --self._time = modtime;
    --dprint(("clSourceFile.needsBuild():    %s %s"):format(self.dirty and "DIRTY" or "clean", self[1]));
    return self.dirty, max(filetime, modtime);
  end;
  --
  clGeneratedFile = clFile:subclass{
    __classname  = "GeneratedFile",
  };
  
  clGeneratedFile.needsBuild = function(self)
    local dirty, modtime = self:presDirty();
    local time = self:filetime() or -1;
    if self.deps then
      dirty, modtime = self.deps:needsBuild();
      self.dirty = dirty or (time < modtime);
    end;
    --dprint(("clGeneratedFile.needsBuild(): %s %s"):format(self.dirty and "DIRTY" or "clean", self[1]));
    return self.dirty or (not self:is("TempFile") and self.dirty), max(time, modtime);
  end;
  
  clGeneratedFile.delete     = function(self)
    if self:exists() then 
      if not Make.options.quiet then
        print("DELETE " .. fn_canonical(self[1]))
      end;
      os.remove(self[1]);
    end;
  end;
  --
  clTempFile = clGeneratedFile:subclass{
    __classname  = "TempFile",
    __init  = function(self, ...) -- ([<path>,]* filename)
      clTempFile.super.__init(self, ...);
      Intermediates:add(self);
      return self;
    end,
  };
  
  clTempFile.needsBuild = function(self)
    if not self:exists() and pick(self.deps, self.action) == nil then -- error
      quit("make(): file '%s' does not exist.", self[1], 0); 
    end;
    local dirty, modtime = self:presDirty();
    local time = self:filetime() or -1;
    self.dirty = self.dirty or dirty or time < modtime;
    time = max(time, modtime);
    if self.deps then
      dirty, modtime = self.deps:needsBuild();
      self.dirty = self.dirty or dirty or (time < modtime);
    end;
    --dprint(("clTempFile.needsBuild():      %s %s"):format(self.dirty and "DIRTY" or "clean", self[1]));
    return false, max(time, modtime);
  end;
  --
  clTargetFile = clGeneratedFile:subclass{
    __classname  = "TargetFile",
    __init  = function(self, ...) -- ([<path>,]* filename)
      clTargetFile.super.__init(self, ...);
      ProgsAndLibs:add(self);
      return self;
    end,
  };
  --
  clTargetList = class.UList:subclass{
    __classname = "TargetList",
    __allowed   = "FilesAndTargets",
    __init      = function(self, param, ...)
      self.__dir = {};
      if type(param) == "table" then
        self:add(param);
      end;
      return self;
    end,
  };
  
  clTargetList.needsBuild     = function(self)
    local time, dirty, modtime = -1, false, -1;
    for n in self() do
      dirty, modtime = n:needsBuild();
      self.dirty = self.dirty or dirty;
      time = max(time, modtime);
    end;
    return self.dirty, time;
  end;
  
  clTargetList.new_sourcefile = function(self, ...) 
    local item = clSourceFile:new(...);
    if item then 
      self:add(item); 
    end;
    return item;
  end;
  
  clTargetList.new_tempfile   = function(self, ...)
    local item = clTempFile:new(...);
    if item then 
      self:add(item); 
    end;
    return item;
  end;
  
  clTargetList.new_targetfile = function(self, ...) 
    local item = clTargetFile:new(...);
    if item then 
      self:add(item); 
    end;
    return item;
  end;
  
  clTargetList.new_target     = function(self, ...)
    local item = clTarget:new(...);
    self:add(item);
    return item;
  end;
  
  clTargetList.delete         = function(self, ...)
    for f in self() do 
      if f:is("GeneratedFile") then f:delete(); end;
    end;
  end;
  -- 
  Sources       = clTargetList:new(); -- all sources.
  ProgsAndLibs  = clTargetList:new(); -- all programs, static and dynamic libs to build.
  Intermediates = clTargetList:new(); -- all intermediate files.
  Targets       = clTargetList:new(); -- all phony targets.
  --
  function target(label, deps, ...)
    if select('#', ...) > 0 or deps == nil then quitMF("target(): parameter error. Did you use {}?"); end;
    local Target = Targets:find(label);
    if Target then
      Target:add_deps(deps);
    else
      Target = Targets:new_target(label, deps);
    end;
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
  clMake.Sources      = Sources;
  clMake.Tempfiles    = Intermediates;
  clMake.ProgsAndLibs = ProgsAndLibs;
  clMake.Targets      = Targets;
  --
end;
--
--=== [needs handling] =========================================================
local Needs;
do
  --
  local clNeeds;
  --
  clNeeds = class.UList:subclass{
    __classname = "Needs",
    __key  = 1,
    fields = {"defines", "incdir", "libs", "libdir", "prerequisites"}, -- allowed fields.
    exportfields = {"defines", "incdir", "libs", "libdir"},
  }; clNeeds:protect();
  
  clNeeds.__call = function(self, ...) -- need definition and reading
    local p1, p2, unused = select(1, ...);
    if type(unused) ~= "nil" then 
      quitMF("%s: wrong parameter.", self.__classname); 
    end;
    if (type(p1) == "string") and (p2 == nil)  then
      -- "alias = need" ?
      if p1:find("=") then
        local alias, need = p1:match("^(%w+)%s*=%s*(%w+)$");
        local a, n = self:find(alias), self:find(need);
        if not n then quitMF("needs.alias(): no need '%s' defined."); end;
        if a and (a[1] == alias) then quitMF("needs.alias(): '%s' is already defined as normal need.", alias); end;
        self.__dir[alias] = n;
        return n;
      end;
      -- "need:field" ?
      if p1:find(":") then
        local n;
        local ns = p1:match("^([^:]+):.+$");
        if ns then
          n = self:find(ns);
        else
          quit("needs(): no need '%s' found.", ns);
        end;
        local res = {};
        local fs = split(p1:match("^[^:]+:(.+)$"), ",");
        for _, fn in ipairs(fs) do
          if n[fn] then
            res[fn] = class.StrList:new(n[fn]);
          else
            quit("need(): need '%s' has no field '%s'.", ns, fn);
          end;
        end;
        return res;
      end;
      -- "need" !
      return self:find(p1)
    end;
    if (type(p1) == "string") and (type(p2) == "function") then
      local t = p2();
      if type(t) ~= "table" then quitMF("need-function should return a table."); end;
      t[1] = p1;
      p1 = t;
      p2 = nil;
    end;
    if (type(p1) == "table") and (p2 == nil)  then
      local needname = p1[1];
      local need = self.__dir[needname];
      if need then
        if need.predefined then
          for _, fn in ipairs(self.exportfields) do
            need[fn] = nil;
          end;
          need.predefined = nil;
        else
          quitMF("Need '%s' already defined.", p1[1]);
        end;
      else
        need = {needname};
        self.__dir[needname] = need;
        insert(self, need);
      end;
      for _, fn in ipairs(self.fields) do
        if p1[fn] then
          need[fn] = class.StrList:new(p1[fn]);
        end;
      end;
    else
      quitMF("%s: wrong parameter.", self.__classname);
    end;
  end;
  
  clNeeds.export = function(self, filename)
    filename = filename or "needs.omm";
    local OldNeeds = clNeeds:new();
    local sandbox = {define_need = OldNeeds};
    local f, err = loadfile (filename, "t", sandbox);
    if f then 
      if setfenv then setfenv(f, sandbox); end; -- lua 5.1
      f();
    end;
    for _, need in ipairs(OldNeeds) do
      if not self.__dir[need[1]] then
        self.__dir[need[1]] = need;
        insert(self, need);
      end;
    end;
    f, err = io.open(filename, "w+");
    if f then
      for _, need in ipairs(self) do
        f:write(('define_need{ "%s",\n'):format(need[1]));
        for _, fn in ipairs(self.exportfields) do
          if need[fn] then
            f:write(('  %s = "%s",\n'):format(fn, need[fn]:concat()));
          end;
        end;
        f:write("};\n\n");
      end;
      f:close();
    else
      quit("needs.export(): can't create '%s'.", filename, 0);
    end;
  end;
  
  clNeeds.import = function(self, filename)
    filename = filename or "needs.omm";
    local NewNeeds = clNeeds:new();
    local sandbox = {define_need = NewNeeds};
    local f, err = loadfile (filename, "t", sandbox);
    if f then 
      if setfenv then setfenv(f, sandbox); end; -- lua 5.1
      f();
    else
      warning(("needs.import(): cant import '%s'."):format(fn_canonical(filename)));
    end;
    for _, need in ipairs(NewNeeds) do
      local needname = need[1];
      local storedNeed = self.__dir[needname];
      if storedNeed then
        if storedNeed.predefined then
          for _, fn in ipairs(self.exportfields) do
            storedNeed[fn] = need[fn]
          end;
        else
          warning("needs.import(): need '%s' already defined.", needname);
        end;
      else
        need.predefined = true;
        self.__dir[needname] = need;
        insert(self, need);
      end;
    end;
  end;
  
  Needs = clNeeds:new();
  
  clMakeScript.define_need = Needs;
  clMake.Needs = Needs;
  --
  Needs{'windows', libs = 'kernel32 user32 gdi32 winspool comdlg32 advapi32 shell32 uuid oleaut32 ole32 comctl32 psapi mpr'};
  Needs"windows".predefined=true;
  Needs{'unicode', defines = 'UNICODE _UNICODE'};
  Needs"unicode".predefined=true;
  --
end;
--
do -- [make pass 2 + 3] ========================================================
  --
  function runMake()
    local always_make = Make.options.always_make;
    local just_print  = Make.options.just_print;
    local quiet       = Make.options.quiet;
    local verbose     = Make.options.verbose;
    local strict      = not Make.options.nostrict;
    local targets;
    --
    local function getTarget()
      if targets == nil then
        if not Make.Targets:find("default") then
          MakeScript.default(ProgsAndLibs);
        end;
        if Make.target then
          targets = split(Make.target, ",");
          for i = 1, #targets do
            local ts = targets[i];
            targets[i] = Make.Targets:find(ts)
            if not targets[i] then 
              quit("make(): no target '%s' defined.", ts, 0); 
            end;
          end;
        else
          local startAt = Make.Targets:find("default");
          if #startAt == 0 then 
            quit("make(): no idea, what to make. (no progs or libs defined.)", 0); 
          end;
          targets = {startAt};
        end;
      end;
      local target = targets[1];
      if target then 
        remove(targets, 1); 
      end;
      return target;
    end;
    
    --
    -- returns the dirty status of a given node.
    local function isDirty(treeNode)
      local res = treeNode:needsBuild();
      if not res then 
        if not quiet then print("... all up to date."); end;
      end;
      return res;
    end;
    --
    -- execute a nodes action and/or commandline.
    local function buildNode(node)
      if node == nil then return; end;
      if not node.dirty and not always_make then node.done = true; end;
      if node.done then return; end;
      if node:is("FilesAndTargets") then 
        if always_make or node.dirty then
          -- construct command line
          if node:is("GeneratedFile") and not node.command then
            node.command = node.tool:build_command(node);
          end;
          if node.command and not quiet then 
            if verbose then
              print(node.command); 
            else
              local s = node.tool.CMD or node.command:match("^(%S+)%s");
              s = s:upper() .. string.rep(" ", 6 - #s) .. " " .. fn_canonical(node[1]);
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
              job_execute(node.command, 
                function(ok, code, inf)
                  if verbose or not ok then
                    for l in inf:lines() do
                      print(l);
                    end;
                  end;
                  if not ok and strict then --abort ...
                    jobs_clear();
                    os.exit(code);
                  end;
                  node.done = true;
                  node.dirty = nil;
                end
              );
            end;
          end;
        end;
      end;
    end;
    --
    -- pass 3 new way. quick but overlapping targets.
    -- may become the default in the future.
    local function makeNodeQD(node) 
      local targets  = clTargetList:new();
      local lvltbl = {};
      local maxlevel = 0;
      local function remember(node)
        --dprint("%s\t%s",node.level, node[1]);
        if not targets:find(node[1]) then targets:add(node); end;
      end;
      local function deduceLevel(node, lvl)
        lvl = lvl or 1; 
        if not node:is("TargetList Target") or node.action then
          lvl = lvl + 1;
        end;
        if node == nil or node:is("SourceFile") then return; end;
        maxlevel = max(maxlevel, lvl);
        node.level = max(node.level or -1, lvl);
        -- expanding from's
        if node.from then
          for fs in node.from() do
            local ft = Needs(fs);
            for n, v in pairs(ft) do
              node[n]:add(v);
            end;
          end;
          node.from = nil;
        end;
        if node.prerequisites and #node.prerequisites > 0 then 
          deduceLevel(node.prerequisites, lvl);
        end;
        --
        if node.action then 
          remember(node); 
        end;
        --
        if node:is("TargetList") then
          for t in node() do deduceLevel(t, lvl); end;
        elseif node:is("Target") then
          --if not (always_make or node.dirty) then return; end;
          deduceLevel(node.deps, lvl);
        elseif node:is("GeneratedFile") then
          if not (always_make or node.dirty) then return; end;
          remember(node);
          deduceLevel(node.deps, lvl);
        end;
      end;
      --
      deduceLevel(node);
      -- filling the level table. (higher levels become executed 1st.)
      for i = 1, maxlevel do lvltbl[i] = {}; end;
      for n in targets() do insert(lvltbl[n.level], n); end;
      -- removing empty levels
      for i = #lvltbl, 1, -1 do
        if #lvltbl[i] == 0 then remove(lvltbl, i); end;
      end;
      if _DEBUG then -- print out some node status.
        local _min, _max = 1/0, -1/0;
        for _, t in ipairs(lvltbl) do
          _min = math.min(_min, #t);
          _max = math.max(_max, #t);
        end;
        dprint(("makeNodeQD(): %s nodes in %s level(s). %s..%s nodes/level"):format(#targets, #lvltbl, _min, _max));
        -- print filenames ...
        --for i,t in ipairs(lvltbl) do dprint("========== level "..i); for _, n in ipairs(t) do dprint(n[1]); end; end;
      end;
      for i = #lvltbl, 1, -1 do
        for _, n in ipairs(lvltbl[i]) do buildNode(n); end;
        jobs_clear();
      end;
    end;
    --
    -- pass 3 simple way. ordered build but not much concurency.
    -- may become removed in the future.
    local function makeNodeSW(node) 
      if (node == nil) or node.done then return; end;
      -- expanding from's
      if node.from then
        for fs in node.from() do
          local ft = Needs(fs);
          for n, v in pairs(ft) do
            node[n]:add(v);
          end;
        end;
      end;
      if node.prerequisites then 
        makeNodeSW(node.prerequisites); 
      end;
      if node:is("TargetList") then
        for n in node() do makeNodeSW(n); end;
        jobs_clear();
      elseif node:is("FilesAndTargets") then 
        if always_make or node.dirty then
          if node.deps then makeNodeSW(node.deps); end;
          buildNode(node);
        end;
      end;
      node.done = true;
    end;
    --
    local makeNode = Make.options.fastjobs and makeNodeQD or makeNodeSW;
    local target = getTarget();
    while target do
      if not quiet then print("TARGET " .. target[1]); end;
      if always_make or isDirty(target) then makeNode(target); end;
      target = getTarget();
    end;
    --
    if Make.options.export_needs then
      Needs:export(Make.options.export_needs)
    end;
  end;
  --
end;
--
do -- [tools] ==================================================================
  local clTool, clToolchain, clTools, Tools;
  local SearchFieldList = class.StrList:new { -- may be toolchain global fields
    "PROG", "SRC_EXT", "OBJ_EXT", "DLL_EXT", "LIB_EXT", "EXE_EXT",
    "command", "command_slib", "command_dlib", "command_prog", "command_dep",
    "SW_SHARED", "SW_COMPILE", "PROG_slib",
    };
  --
  clTool = class.Base:subclass{
    __classname = "Tool",
    __call = function(self, ...)
      if self.__default then 
        return self.__default(...); 
      else
        error(("<class %s>: no default action."):format(self.__classname), 2);
      end;
    end,
    __index = function(self, idx)
      local res = clToolchain.super.__index(self, idx);
      if res  ~= nil then 
        return res; 
      end;
      if SearchFieldList:find(idx) then
        return self.toolchain[idx];
      end;
    end
  };
  
  -- utilities
  function clTool:collect_defines(TreeNode)
    local res = class.StrList:new();
    if TreeNode.defines then 
      res:add(TreeNode.defines); 
    end;
    if Make.options.define then 
      res:add(Make.options.define);
    end;
    while not class(TreeNode, "SourceFile") do
      TreeNode = TreeNode.deps;
      if TreeNode then
        if TreeNode.defines then res:add(TreeNode.defines); end;
      else
        break
      end;
    end;
    return res
  end;
  
  -- command line generation
  function clTool:process_DEFINES(TreeNode)
    local values = self:collect_defines(TreeNode);
    if #values == 0 then return ""; end;
    return "-D"..concat(values, " -D");
  end;

  function clTool:process_OPTIONS(TreeNode)
    local options = class.StrList:new();
    if not Make.get_flag("DEBUG") and (TreeNode.type == "prog" or TreeNode.type == "dlib") then
      options:add("-s");
    end;
    for d in TreeNode.incdir() do
      options:add("-I"..fn_canonical(d));
    end;
    
    return concat(options, " ");
  end;
  
  function clTool:process_LIBS(TreeNode)
    local libs = class.StrList:new();
    for ld in TreeNode.libdir() do
      libs:add("-L"..fn_canonical(ld));
    end;
    for l in TreeNode.libs() do
      libs:add("-l"..fn_canonical(l));
    end;
    return concat(libs, " ");
  end;
  
  function clTool:process_OPTIMIZE(TreeNode)
    if Make.get_flag("DEBUG") then
      return "";
    else
      return "-" .. Make.get_flag("OPTIMIZE"); --TODO:
    end;
  end;
  
  function clTool:process_SOURCES(TreeNode)
    local result = {};
    if class(TreeNode, "GeneratedFile") then
      if class(TreeNode.deps, "File") then 
        insert(result, fn_canonical(TreeNode.deps[1]));
      elseif class(TreeNode.deps, "TargetList") then
        for sf in TreeNode.deps() do
          insert(result, fn_canonical(sf[1]));
        end;
      end;
    elseif class(TreeNode, "TargetList") then
      for sf in TreeNode() do
        insert(result, fn_canonical(sf[1]));
      end;
    end;
    if #result == 0 then 
      return ""; 
    end;
    return concat(result, " ");
  end;
  
  function clTool:process_OUTFILE(TreeNode)
    if class(TreeNode, "GeneratedFile") then
      return fn_canonical(TreeNode[1]);
    else
      error("OUTFILE is not of class GeneratedFile", 2);
    end;
  end;

  function clTool:process_PREFIX(TreeNode)
    local px = Make.get_flag("PREFIX");
    if px and #px > 0 then
      px = px:gsub("%-?$","-");
    else
      px = "";
    end;
    local s = TreeNode.tool["command_"..(TreeNode.type or "")] or TreeNode.tool.command;
    TreeNode.tool["COMMAND_" .. TreeNode.type] = s:gsub("%$PREFIX%f[%U]", px);
    return px
  end;

  function clTool:process_SUFFIX(TreeNode)
    local px = Make.get_flag("SUFFIX");
    if px and #px > 0 then
      px = px:gsub("^%-?","-");
    else
      px = "";
    end;
    local s = TreeNode.tool["command_"..(TreeNode.type or "")] or TreeNode.tool.command;
    TreeNode.tool["COMMAND_" .. TreeNode.type] = s:gsub("%$SUFFIX", px);
    return px
  end;

  function clTool:process_PROG(TreeNode)
    local s = TreeNode.tool["command_"..(TreeNode.type or "")] or TreeNode.tool.command;
    TreeNode.tool["COMMAND_" .. TreeNode.type] = s:gsub("%$PROG%f[%U]", self.PROG);
    return self.PROG; 
  end;
  
  function clTool:build_command(TreeNode)
    local result = pick(self["command_"..(TreeNode.type or "")], self.command);
    for j in result:gmatch("%$(%u*)") do
      result = result:gsub("%$"..j, (self["process_"..j](self, TreeNode)));
    end;
    return result;--:gsub("%s+", " ");
  end;
  --
  function clTool:getSources(par)
    local sources = clTargetList:new{__allowed = "SourceFile"};
    sources.prerequisites = clTargetList:new();
    sources.defines = class.StrList:new();
    sources.incdir  = class.StrList:new();
    sources.libdir  = class.StrList:new();
    sources.libs    = class.StrList:new();
    sources.from    = class.StrList:new();
    sources.base    = fn_abs(par.base or ".");
    sources.tool    = self;
    -- src = ...
    if par.src     then
      if type(par.src) == "string" then
        par.src = split(par.src);
      end;
      if type(par.src) == "table" then
        local exts = split(pick(par.ext, self.SRC_EXT));
        for _, n in ipairs(par.src) do
          local f;
          local mask = fn_join(par.base, fn_defaultExt(n, exts[1]));
          local list = fn_files_from_mask(mask);
          if list then
            if #list == 0 then quitMF("*ERROR: cant find source file '%s'.", mask); end;
            for _, n in ipairs(list) do
              sources:new_sourcefile(n);
            end;
          else
            for _, ext in ipairs(exts) do
              f = sources:new_sourcefile(par.base, fn_defaultExt(n, ext));
              if f then break; end; -- source file found ...
            end;
            if not f then
              quitMF("*ERROR: cant find source file '%s'.", n);
            end;
          end;
        end;
        par.src = nil;
      end;
    end;
    -- inputs = ...
    if par.inputs  then
      sources:add(par.inputs);
      -- TODO: copy fields too?
      par.inputs = nil;
    end;
    -- libs = ...
    if par.libs    then
      sources.libs:add(par.libs);
      par.libs = nil;
    end;
    -- needs = ...
    if par.needs   then
      if type(par.needs) == "string" then
        par.needs = split(par.needs);
      end;
      for _, ns in ipairs(par.needs) do
        local n = Make.Needs:find(ns);
        if not n then quitMF("make(): unknown need '%s'.", ns); end
        for _, f in ipairs(Make.Needs.fields) do
          if n[f] then
            if f == "prerequisites" then
              for pre in n[f]() do
                local tgt = Targets:find(pre);
                if tgt then 
                  sources.prerequisites:add(tgt); 
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
      par.needs = nil;
    end;
    -- defines = ...
    if par.defines then
      sources.defines:add(par.defines);
      par.defines = nil;
    end;
    -- prerequisites = ...
    if par.prerequisites then 
      if type(par.prerequisites) == "string" then
        par.prerequisites = split(par.prerequisites);
      end;
      if type(par.prerequisites) == "table" then
        for _, ts in ipairs(par.prerequisites) do
          local t = Targets:find(ts);
          if not t then quitMF("no target '%s' defined.", ts); end;
          sources.prerequisites:add(t.deps);
        end;
      else
        quitMF("make(): parameter 'prerequisites' needs to be a string or a list of strings."); 
      end;
      par.prerequisites = nil;
    end;
    -- from = ...
    if par.from then
      sources.from:add(par.from);
      par.from = nil;
    end;
    --
    return sources;
  end; -- getSources(par)

  function clTool:checkParam(...)
    if select("#", ...) ~= 1 then 
      quitMF("%s(): only one parameter alowed. Did you use {}?", self[1]); 
    end;
    local par = select(1, ...);
    if type(par) ~= "table" then 
      quitMF("%s(): parameter needs to be a table. Did you use {}?", self[1]); 
    end;
    return par;
  end;
  
  function clTool:checkFileNameParam(...)
    local par = select(1, ...);
    if type(par[1]) ~= "string" then quitMF("%s(): no valid file name at index [1].", self[1]); end;
    return par[1];
  end;

  --
  function clTool:action_group(...)
    local par = self:checkParam(...);
    local sources = self:getSources(par);
    if par.odir then
      local result = clTargetList:new();
      for sf in sources() do
        local fn = fn_forceExt(fn_basename(sf[1]),self.OBJ_EXT or self.toolchain.OBJ_EXT);
        if type(par[1]) == "string" then fn = par[1] .. "_" .. fn; end;
        local of = result:new_tempfile(par.odir, fn);
        of.deps    = sf;
        of.tool    = self;
        of.type    = "obj";
        of.base    = sources.base;
        of.defines = sources.defines;
        of.incdir  = sources.incdir;
        of.libdir  = sources.libdir;
        of.libs    = sources.libs;
        of.needs   = sources.needs;
        of.from    = sources.from;
      end;
      return result;
    else
      return sources;
    end;
  end;
  
  function clTool:action_program(...)
    local par = self:checkParam(...);
    local sources = self:getSources(par);
    local target = clTargetFile:new(par.odir, fn_forceExt(self:checkFileNameParam(par), self.toolchain.EXE_EXT));
    target.deps    = sources;
    target.defines = sources.defines;
    target.incdir  = sources.incdir;
    target.libdir  = sources.libdir;
    target.libs    = sources.libs;
    target.needs   = sources.needs;
    target.from    = sources.from;
    target.tool    = self;
    target.type    = "prog"
    return target;
  end;
  
  function clTool:action_shared(...)
    local par = self:checkParam(...);
    local sources = self:getSources(par);
    local target = clTargetFile:new(par.odir, fn_forceExt(self:checkFileNameParam(par), self.toolchain.DLL_EXT));
    target.deps = sources;
    target.defines = sources.defines;
    target.incdir  = sources.incdir;
    target.libdir  = sources.libdir;
    target.libs    = sources.libs;
    target.needs   = sources.needs;
    target.from    = sources.from;
    target.tool    = self;
    target.type    = "dlib"
    return target;
  end;
  
  function clTool:action_library(...)
    local par = self:checkParam(...);
    local sources = self:getSources(par);
    local target = clTargetFile:new(par.odir, fn_forceExt(self:checkFileNameParam(par), self.toolchain.LIB_EXT));
    target.deps = sources;
    target.defines = sources.defines;
    target.incdir  = sources.incdir;
    target.libdir  = sources.libdir;
    target.libs    = sources.libs;
    target.needs   = sources.needs;
    target.from    = sources.from;
    target.tool    = self;
    target.type    = "slib"
    return target;
  end;
  --
  function clTool:add_action(what, func)
    if func then 
      self["action_"..what] = func; 
    end;
    self[what] = function(...)
      return self["action_"..what](self, ...);
    end;
    if not self.__default then 
      self.__default = self[what]; 
    end;
  end;
  
  function clTool:add_group(func)
    self:add_action("group", func);
  end;
  
  function clTool:add_program(func)
    self:add_action("program", func);
  end;
  
  function clTool:add_shared(func)
    self:add_action("shared", func);
  end;
  
  function clTool:add_library(func)
    self:add_action("library", func);
  end;
  --
  clToolchain = class.UList:subclass{ -- list of tools.
    __classname = "Toolchain";
    __key  = 1;
    __allowed = "Tool";
    __satisfy = {};
  };
  
  function clToolchain:satisfy(toolname)
    -- test provided tools 
    if self.__dir[toolname] then return true; end;
    -- test toolchain/symbolic name
    for _, n in ipairs(self.__satisfy) do
      if n == toolname then return true; end;
    end;
    return false;
  end;
  
  function clToolchain:new_tool(...)
    local tool = clTool:new(...);
    tool.toolchain = self;
    self:add(tool);
    return tool;
  end;
  --
  clTools = class.List:subclass{ -- list of toolchains.
    __classname = "Tools";
    __allowed   = "Toolchain";
    satisfied   = class.List:new(); -- satisfied tools needs.
    tools       = clToolchain:new();
  };
  
  function clTools:inject()
    for n, v in pairs(self.tools.__dir) do
      clMakeScript[n] = v;
    end;
  end;
  
  function clTools:satisfy(...)
    local par;
    if select("#", ...) > 1 then 
      par = {...}; 
    elseif select("#", ...) == 1 then 
      par = select(1, ...); 
    else 
      quit("clToolchains:satisfy(): no parameter.", 2)
    end;
    --
    local function satisfied(tool)
      return self.tools:find(tool) or self.satisfied:index(tool);
    end;
    --
    if type(par) == "table" then
      local res = true;
      for _, n in ipairs(par) do
        res = res and self:satisfy(n);
      end;
      return (res and true) or nil;
    elseif type(par) == "string" then
      if not satisfied(par) then 
        for _, tchn in ipairs(self) do
          if tchn:satisfy(par) then 
            self.tools:add(tchn);
            if tchn.flags then Make.set_flags(tchn.flags); end;
            self:inject();
            return tchn.__dir[par];
          end; 
        end;
      return nil, ("clToolchains.satisfy(): cant satisfy tool '%s'."):format(par);
      end;
    else
      return nil, "clToolchains.satisfy(): wrong parameter.";
    end;
  end;
  
  function clTools:new_toolchain(...)
    local tc = clToolchain:new(...)
    self:add{tc};
    return tc;
  end;
  
  function clTools:load(name)
    local function loadtc(name)
      if type(name) == "table" then
        for _, n in ipairs(name) do
          loadtc(n);
        end;
      elseif type(name) == "string" then
        if name:find("^tc_") or name:find("^"..TOOLCHAIN_PREFIX) then  
          require(name);
        else 
          local _ = pcall(require, TOOLCHAIN_PREFIX .. name) or 
                    pcall(require, "tc_" .. name) or 
                    quit("* Cant find Toolchain '%s'.", name, 0);
        end;
      else
        error("clToolchains.load(): wrong parameter", 3);
      end;
    end;
    if type(name) == "string" then name = split(name); end;
    loadtc(name);
  end;
  
  clTools.__call = clTools.satisfy;
  --
  Tools = clTools:singleton();
  clMake.Tools = Tools;
  --
end;
--
--=== [toolchains & special targets] ===========================================
--
package.preload["tc_msc"]          = function(...) --TODO
  --
  if not WINDOWS then return; end; -- MSC available on Windows only.
  --
  local Make = require "Make";
  --
  local Toolchains = Make.Tools;
  local fn         = Make.path;
  local warning    = Make.warning;
  --
  -- environmet variables fit gnu tools?
  local CC = os.getenv("CC");
  if CC then
    CC = fn.splitext(fn.basename(CC));
    if not CC:find("%f[%a]cl%f[%A]") then 
      warning("CC environment var does not fit to msc toolchain.")
      return; 
    end;
  end;
  
  local CXX = os.getenv("CXX");
  if CXX then
    CXX = fn.splitext(fn.basename(CXX));
    if not CXX:find("%f[%a]cl%f[%A]") then 
      warning("CXX environment var does not fit to msc toolchain.")
      return; 
    end;
  end;
  --
  local Toolchain = Toolchains:new_toolchain{
    __satisfy = {"msc"},
    flags = {CC= CC or "cl"; CXX= CXX or "cl"},
    OBJ_EXT      = ".obj",
    EXE_EXT      = ".exe",
    DLL_EXT      = ".dll",
    LIB_EXT      = ".lib",
    command_slib = "lib /nologo /nodefaultlib /OUT:$OUTFILE $SOURCES", --TODO
  };
  --
  local Tool;
  Tool = Toolchain:new_tool{ "cc",
    SRC_EXT      = ".c",
    CMD          = "CC",
    PROG         = "cl",
    command_obj  = "$PREFIX$PROG$SUFFIX /nologo OPTIMIZE -c $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dlib = "$PREFIX$PROG$SUFFIX /nologo OPTIMIZE -shared $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command      = "$PREFIX$PROG$SUFFIX /nologo OPTIMIZE $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dep  = "$PREFIX$PROG$SUFFIX /nologo MM -MF $DEPFILE $OPTIONS $DEFINES $SOURCES",
  };
  Tool:add_group();
  Tool:add_program();
  Tool:add_shared();
  Tool:add_library();
  --
  Tool = Toolchain:new_tool{ "c99",
    SRC_EXT      = ".c",
    CMD          = "C99",
    PROG         = "cl",
    command_obj  = "$PREFIX$PROG$SUFFIX /nologo $OPTIMIZE -c $OPTIONS $DEFINES $SOURCES /Fo$OUTFILE",
    command_dlib = "$PREFIX$PROG$SUFFIX /nologo $OPTIMIZE -shared $OPTIONS $DEFINES $SOURCES $LIBS /Fo$OUTFILE",
    command      = "$PREFIX$PROG$SUFFIX /nologo $OPTIMIZE $OPTIONS $DEFINES $SOURCES $LIBS /Fo$OUTFILE",
    command_dep  = "$PREFIX$PROG$SUFFIX /nologo -MM -MF $DEPFILE $OPTIONS $DEFINES $SOURCES",
  };
  Tool:add_group();
  Tool:add_program();
  Tool:add_shared();
  Tool:add_library();
  --
  Tool = Toolchain:new_tool{ "cpp",
    SRC_EXT      = ".cpp .cxx .C",
    CMD          = "CPP",
    PROG         = "cl",
    command_obj  = "$PREFIX$PROG$SUFFIX /nologo $OPTIMIZE -c $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dlib = "$PREFIX$PROG$SUFFIX /nologo $OPTIMIZE -shared $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command      = "$PREFIX$PROG$SUFFIX /nologo $OPTIMIZE $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dep  = "$PREFIX$PROG$SUFFIX /nologo -MM -MF $DEPFILE $OPTIONS $DEFINES $SOURCES",
  };
  Tool:add_group();
  Tool:add_program();
  Tool:add_shared();
  Tool:add_library();
  --
  Tool = Toolchain:new_tool{ "wresource";
    SRC_EXT   = ".rc",
    OBJ_EXT   = ".res",
    CMD       = "RES",
    command   = "cl /nologo  $OPTIONS $SOURCES -o $OUTFILE",
  };
  Tool:add_group();
  --
  Tool = Toolchain:new_tool{ "asm",
    SRC_EXT     = ".s",
    CMD         = "ASM",
    PROG        = "as",
    command     = "$PREFIX$PROG $OPTIMIZE $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dep = "$PREFIX$PROG -MD $DEPFILE $OPTIONS $DEFINES $(SOURCES)",
  };
  Tool:add_group();
  Tool:add_program();
  Tool:add_shared();
  Tool:add_library();
  --
  
  return Toolchain;
  
end;

package.preload["tc_gnu"]          = function(...) 
  
  local Make = require "Make";
  --
  local Toolchains = Make.Tools;
  local utils      = Make.utils;
  local fn         = Make.path;
  local choose     = utils.choose;
  local warning    = Make.warning;
  --
  local WINDOWS    = Make.WINDOWS;
  --
  -- environmet variables fit gnu tools?
  local CC = os.getenv("CC");
  if CC then
    CC = fn.splitext(fn.basename(CC));
    if not CC:find("%f[%a]gcc%f[%A]") then 
      warning("CC environment var does not fit to gnu toolchain.")
      return; 
    end;
  end;
  
  local CXX = os.getenv("CXX");
  if CXX then
    CXX = fn.splitext(fn.basename(CXX));
    if not CXX:find("%f[%a]g++%f[%A]") then 
      warning("CXX environment var does not fit to gnu toolchain.")
      return; 
    end;
  end;
  --
  local Toolchain = Toolchains:new_toolchain{
    __satisfy = {"gnu"},
    flags = {CC= CC or "gcc"; CXX= CXX or "g++"},
    OBJ_EXT      = ".o",
    EXE_EXT      = choose(WINDOWS, ".exe", ""),
    DLL_EXT      = choose(WINDOWS, ".dll", ".so"),
    LIB_EXT      = ".a",
    command_slib = "$PREFIXgcc-ar rcus $OUTFILE $SOURCES",
  };
  --
  local Tool;
  Tool = Toolchain:new_tool{ "cc",
    SRC_EXT      = ".c",
    CMD          = "CC",
    PROG         = "gcc",
    command_obj  = "$PREFIX$PROG$SUFFIX $OPTIMIZE -c $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dlib = "$PREFIX$PROG$SUFFIX $OPTIMIZE -shared $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command      = "$PREFIX$PROG$SUFFIX $OPTIMIZE $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dep  = "$PREFIX$PROG$SUFFIX -MM -MF $DEPFILE $OPTIONS $DEFINES $SOURCES",
  };
  Tool:add_group();
  Tool:add_program();
  Tool:add_shared();
  Tool:add_library();
  --
  Tool = Toolchain:new_tool{ "c99",
    SRC_EXT      = ".c",
    CMD          = "C99",
    PROG         = "gcc",
    command_obj  = "$PREFIX$PROG$SUFFIX -std=gnu99 $OPTIMIZE -c $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dlib = "$PREFIX$PROG$SUFFIX -std=gnu99 $OPTIMIZE -shared $OPTIONS $DEFINES $SOURCES $LIBS -o $OUTFILE",
    command      = "$PREFIX$PROG$SUFFIX -std=gnu99 $OPTIMIZE $OPTIONS $DEFINES $SOURCES $LIBS -o $OUTFILE",
    command_dep  = "$PREFIX$PROG$SUFFIX -MM -MF $DEPFILE $OPTIONS $DEFINES $SOURCES",
  };
  Tool:add_group();
  Tool:add_program();
  Tool:add_shared();
  Tool:add_library();
  --
  Tool = Toolchain:new_tool{ "cpp",
    SRC_EXT      = ".cpp .cxx .C",
    CMD          = "CPP",
    PROG         = "g++",
    command_obj  = "$PREFIX$PROG$SUFFIX $OPTIMIZE -c $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dlib = "$PREFIX$PROG$SUFFIX $OPTIMIZE -shared $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command      = "$PREFIX$PROG$SUFFIX $OPTIMIZE $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dep  = "$PREFIX$PROG$SUFFIX -MM -MF $DEPFILE $OPTIONS $DEFINES $SOURCES",
  };
  Tool:add_group();
  Tool:add_program();
  Tool:add_shared();
  Tool:add_library();
  --
  Tool = Toolchain:new_tool{ "wresource";
    SRC_EXT   = ".rc",
    OBJ_EXT   = ".o",
    CMD       = "RES",
    command   = "windres $OPTIONS $SOURCES -o $OUTFILE",
  };
  Tool:add_group();
  --
  Tool = Toolchain:new_tool{ "asm",
    SRC_EXT     = ".s",
    CMD         = "ASM",
    PROG        = "as",
    command     = "$PREFIX$PROG $OPTIMIZE $OPTIONS $DEFINES $SOURCES -o $OUTFILE",
    command_dep = "$PREFIX$PROG -MD $DEPFILE $OPTIONS $DEFINES $(SOURCES)",
  };
  Tool:add_group();
  Tool:add_program();
  Tool:add_shared();
  Tool:add_library();
  --
  return Toolchain;
end;

package.preload["tc_files"]        = function(...) 
  --
  local Make       = require "Make";
  local Toolchains = Make.Tools;
  local choose     = Make.utils.choose;
  local WINDOWS    = Make.WINDOWS;
  
  local tc = Toolchains:new_toolchain{__satisfy = {"files"}};
  --
  local Tool = tc:new_tool{ "file",
    SRC_EXT      = ".*",
    OUT_EXT      = ".*",
    command_copy = choose(WINDOWS, "copy", "cp") .. " $SOURCES $OUTFILE    ",
    command_link = choose(WINDOWS, "copy", "cp --link") .. " $SOURCES $OUTFILE    ",
  };
  
  function Tool:action_copy(...)
    local par = self:checkParam(...);
    local sources = self:getSources(par);
    if type(par.odir) ~= "string" then quitMF("file.copy(): 'odir' is missing."); end;
    local targets = clTargetList:new();
    for sf in sources() do
      local target = targets:new_targetfile(par.odir, sf[1]:sub(#sources.base+2));
      target.deps = sf;
      target.tool = self;
      target.type = "copy";
    end;
    return targets;
  end;
  
  Tool:add_action("copy");
  --
  function Tool:action_link(...)
    local par = self:checkParam(...);
    local sources = self:getSources(par);
    if type(par.odir) ~= "string" then quitMF("file.link(): 'odir' is missing."); end;
    local targets = clTargetList:new();
    for sf in sources() do
      local target = targets:new_targetfile(par.odir, sf[1]:sub(#sources.base+2));
      target.deps = sf;
      target.tool = self;
      target.type = "link";
    end;
    return targets;
  end;
  
  Tool:add_action("link");
  --
  Tool = tc:new_tool{"group";
    SRC_EXT = ".*";
  };
  function Tool:action_group(...)
    local par = self:checkParam(...);
    if not par.inputs then
      local inputs = {};
      for i = 1, #par do
        inputs[i] = par[i];
        par[i] = nil;
      end;
      par.inputs = inputs;
    end;
    return self:getSources(par);
  end;
  Tool:add_group();
  --
  return tc;
end;

package.preload["tc_repositories"] = function(...) --TODO
  --
  local Make       = require "Make";
  local Toolchains = Make.Tools;
  local utils      = Make.utils;
  local fn         = Make.path;
  local choose     = utils.choose;
  local warning    = Make.warning
  local WINDOWS    = Make.WINDOWS;
  
  if not utils.which("svn"..choose(WINDOWS, ".exe", "")) then 
    warning("'svn' not found in path.");
    return; 
  end;
  
  local tc = Toolchains:new_toolchain{__satisfy = {"repositories"}};
  --
  local Tool = tc:new_tool{"svn"};
  --
  function Tool:action_checkout(...)
    local par = self:checkParam(...);
    local dir = par[1] or par.odir;
    if type(dir) ~= "string" then quitMF("no valid odir given."); end;
    local fnx = (function(a,b)return a.."."..b;end)(fn_splitpath(fn_forceExt(dir,".svn")));
    local url =par[2] or par.src;
    if type(url) ~= "string" then quitMF("no valid url given."); end;
    if fn.exists(dir) and not fn.isDir(dir) then quitMF("cant overwrite '%s'.", dir); end;
    local filetime_delta = os.time() - fn_filetime(fnx);
    if filetime_delta < 86400 then return; end; -- checkout at least 24 hours old ?
    local cmd = "svn checkout " .. url .. " " .. dir;
    if Make.options.verbose then
      print(cmd);
    elseif not Make.options.quiet then
      print("SVN-CO "..url);
    end;
    
    if not utils.execute(cmd, Make.options.quiet) then
      quitMF("svn checkout failed.");
    else 
      local f = io.open(fnx,"w+");
      if f then
        f:write(("%s checked out with:\n%s ."):format(dir, cmd));
        f:close();
      end;
      
    end;
  end;
  Tool:add_action("checkout");
  --
  return tc;
end;

package.preload["tc_targets"]      = function(...)
  --
  local Make       = require "Make";
  local Targets    = Make.Targets;
  --
  local function action_clean(self)
    Make.Tempfiles:delete();
  end;

  local function action_CLEAN(self)
    Make.Tempfiles:delete();
    Make.ProgsAndLibs:delete();
  end;
  --
  local t;
  t = Targets:new_target("clean",{action = action_clean});
  t.dirty = true; -- allways execute
  t = Targets:new_target("CLEAN",{action = action_CLEAN});
  t.dirty = true; -- allways execute
  --
  return nil; -- no new toolchain to return.
end;
--
-- [main] ======================================================================
--
if REQUIRED then return Make; end;
Make(arg);
