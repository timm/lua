
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
  local t = "(function() local __t={}; for "..vars.." "..iter
  if cond then t = t.." do if "..cond.." then push(__t,"..expr
                        ..") end end"
  else         t = t.." do push(__t,"..expr..") end" end
  return t.."; return __t end)()" end

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
      if i>1 then push(result,", ") end 
      push(result, n.."="..n) end
    push(result, " }") end
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


