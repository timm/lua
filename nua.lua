Here's the complete nua system in Timm style:

```lua
-- nua.lua : sugar-Lua → plain Lua
-- 
-- Limitations:
-- - Function signatures must be on one line
-- - String interpolation #{} must be on one line
-- - Comprehensions must be on one line
-- - Each transpile pattern assumes single-line constructs
--
-- Usage:
--   lua nua.lua input.nua           # transpile to stdout
--   require "nua"; require "file"   # load .nua files automatically

local exps, push = {}, table.insert

local function comp(vars, iter, expr, cond)
  local t = "(function() local __t={} for "..vars.." "..iter
  if cond then t = t.." do if "..cond.." then push(__t,"..expr
                        ..") end end"
  else         t = t.." do push(__t,"..expr..") end" end
  return t.." return __t end)()" end

local rules = {
  -- Strip type annotations (must come first!)
  -- x:list[Str] ==> x
  {"([%a_][%w_]*)%s*:%s*[%a_][%w_]*%b[]", "%1"},
  -- x:Num ==> x
  {"([%a_][%w_]*)%s*:%s*[%a_][%w_]*", "%1"},
  -- |x| -> x*2  ==>  function(x) return x*2 end
  {"|([^|]*)|%s*%->%s*(.+)", 
   function(a,b) return "function("..a..") return "..b.." end" end},
  -- for x in t  ==>  for x in pairs(t)
  {"(%s+in%s+)([%a_][%w_.]*)(%s+if%s+)", "%1pairs(%2)%3"},
  {"(%s+in%s+)([%a_][%w_.]*)(%s*})", "%1pairs(%2)%3"},
  -- "hello #{name}"  ==>  "hello "..tostring(name)..""
  {"#%{([^}]+)%}", function(expr) 
    return '"..tostring('..expr..')".."' end},
  -- x?.method  ==>  x and x.method
  {"([%w_]+)%?%.([%w_]+)", "%1 and %1.%2"},
  -- x ||= 10  ==>  x = x==nil and 10 or x
  {"([%w_]+)%s*||=%s*(.+)", "%1 = %1==nil and %2 or %1"},
  -- x += 1  ==>  x = x + 1
  {"([%w_]+)%s*%+=%s*(.+)", "%1 = %1 + %2"},
  {"([%w_]+)%s*%-=%s*(.+)", "%1 = %1 - %2"},
  {"([%w_]+)%s*%*=%s*(.+)", "%1 = %1 * %2"},
  {"([%w_]+)%s*/=%s*(.+)", "%1 = %1 / %2"},
  -- {x*2 for x=1,10 if x%2==0}  ==>  comprehension with condition
  {"{%s*(.-)%s+for%s+([%a_][%w_]*)%s*=%s*(%d+)%s*,%s*(%d+)%s*if%s*(.-)%s*}",
   function(e,v,a,b,c) return comp(v, "="..a..","..b, e, c) end},
  -- {x*2 for x=1,10}  ==>  comprehension without condition
  {"{%s*(.-)%s+for%s+([%a_][%w_]*)%s*=%s*(%d+)%s*,%s*(%d+)%s*}",
   function(e,v,a,b) return comp(v, "="..a..","..b, e) end},
  -- {v for k,v in t if k>0}  ==>  iterator comprehension with condition
  {"{%s*(.-)%s+for%s+([%a_][%w_,]*)%s+in%s+(.-)%s*if%s*(.-)%s*}",
   function(e,v,i,c) return comp(v, "in "..i, e, c) end},
  -- {v for k,v in t}  ==>  iterator comprehension without condition
  {"{%s*(.-)%s+for%s+([%a_][%w_,]*)%s+in%s+(.-)%s*}",
   function(e,v,i) return comp(v, "in "..i, e) end} }

local patterns = {
  -- function with default args: function foo(x, y=10)
  {"^%s*function%s+([%a_][%w_.]*)%s*%(([^)]*)%)",
   function(name, args)
     local params, defaults = {}, {}
     for param in (args..","):gmatch("([^,]*),") do
       param = param:match("^%s*(.-)%s*$")
       if param ~= "" then
         local p, default = param:match("^([%a_][%w_]*)%s*=%s*(.+)$")
         if p then
           push(params, p)
           push(defaults, p.."="..p.."==nil and "..default.." or "..p)
         else
           push(params, param) end end end
     local result = "function "..name.."("..table.concat(params,", ")..")"
     if #defaults > 0 then
       result = result.." "..table.concat(defaults, "; ") end
     if not name:find(":") and name:sub(1,1)~="_" then 
       push(exps, name:match("([%a_][%w_]*)$"))
       result = "local "..result end
     return result end},
  -- x = 42  ==>  local x = 42 (plus export)
  {"^%s*([%a_][%w_]*)%s*=",
   function(n) 
     if n:sub(1,1)~="_" then push(exps,n) end 
     return "local "..n.." =" end} }

local function transpile(filepath)
  local result = {}
  exps = {}
  for line in io.lines(filepath) do
    for _,rule in pairs(rules) do
      line = line:gsub(rule[1], rule[2]) end
    for _,pattern in pairs(patterns) do
      line = line:gsub(pattern[1], pattern[2]) end
    push(result, line) end
  if #exps>0 then
    push(result, "\nreturn { ")
    for i,n in pairs(exps) do 
      if i>1 then io.write(", ") end 
      io.write(n.."="..n) end
    io.write(" }") end
  return table.concat(result, "\n") end

if arg and arg[1] then
  print(transpile(arg[1]))
else
  table.insert(package.searchers, function(name)
    local filepath = name:gsub("%.", "/") .. ".nua"
    local f = io.open(filepath, "r")
    if not f then return "\n\tno nua file '" .. filepath .. "'" end
    f:close()
    return function()
      return assert(load(transpile(filepath), "@"..filepath))() end end)
end

-- demo.nua : showcase all nua features
cat = table.concat
fmt = string.format
sort = |x| -> (table.sort(x), x)
keys = |t| -> sort({k for k,_ in t if not k:find"^_"})

function o(x) --> Str
  if type(x) == "number" and x % 1 ~= 0 then return fmt("%.3f", x) end
  if type(x) == "table" then
    return "{" .. cat(#x > 0
      and {o(v) for _,v in x}
      or  {fmt(":%s %s", k, o(x[k])) for k in keys(x)}, " ") .. "}" end
  return tostring(x) end

function greet(name:Str="World", excited:Bool=false) --> Str
  return "Hello " .. name .. (excited and "!" or ".") end

function demo(     t,f)
  t,f = {}, {}
  
  -- Lambda examples with types: |args| -> expr
  f.double = |x:Num| -> x*2
  f.add = |a:Num, b:Num| -> a+b
  f.len = |x:list[Any]| -> #x
  
  -- Function with defaults and types
  t.greeting1 = greet()
  t.greeting2 = greet("Alice")
  t.greeting3 = greet("Bob", true)
  
  -- Compound assignment operators
  counter = 0
  counter += 1
  counter *= 2
  
  -- Default values
  name ||= "Unknown"
  
  -- Nil-safe navigation
  result = t?.nonexistent?.field
  
  -- String interpolation
  message = "Hello #{name}, count is #{counter}"
  
  -- Numeric comprehensions: {expr for x=a,b}
  t.squares = {x*x for x=1,5}
  t.evens = {x*2 for x=1,10 if x%2==0}
  
  -- Iterator comprehensions: {expr for k,v in t}
  t.data = {name="Alice", age=30, _private="secret", scores={85,92,78}}
  t.values = {v for _,v in t.data.scores}
  t.doubled = {f.double(v) for _,v in t.data.scores}
  
  -- Auto-pairs wrapping (no explicit pairs() needed)
  t.public_keys = {k for k,_ in t.data if not k:find"^_"}
  
  -- Filtered comprehensions
  t.high_scores = {v for _,v in t.data.scores if v>80}
  
  -- Nested comprehensions
  t.matrix = {{i*j for j=1,3} for i=1,3}
  
  -- Using utility functions
  t.all_keys = keys(t.data)
  t.sorted_scores = sort(t.values)
  
  -- Store the new features
  t.counter = counter
  t.name = name
  t.message = message
  
  -- Pretty print everything using o()
  {print(k, o(v)) for k,v in t}
  
  return t,f end

-- Private function (not exported, starts with _)
function _helper(x:Num) --> Num
  return x * 2 end

-- Method (not made local, has colon)
MyClass = {}
function MyClass:greet(name:Str) --> Str
  return "Hello, " .. name end

demo()
