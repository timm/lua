-- demo.nua all nua features
local cat = table.concat
local fmt = string.format
local sort = function(x) return (table.sort(x); x) end
local keys = function(t) return sort((function() local __t={}; for k,_ in pairs(t) do if not k"^_" then push(__t,k) end end; return __t end)()) end

print(1);
os.exit()
print(2)

-- decorate-sort-undecorate (Schwartzian transform) 
-- cant inline decorated (nexted iterators... not trustworthy)
local function keysort(items, key) --> LIST[ANY]
local decorated = (function() local __t={}; for _,v in pairs(items) do push(__t,{key(v), v}) end; return __t end)()
  return (function() local __t={}; for _,v in sort(decorated) do push(__t,v[2]) end; return __t end)()  

local function o(x) --> STR
  if type(x) == "number" and x % 1 ~= 0 then return fmt("%.3f", x) end
  if type(x) == "table" then
    return "{" .. cat(#x > 0
      and (function() local __t={}; for _,v in pairs(x) do push(__t,o(v)) end; return __t end)()
      or  (function() local __t={}; for k in keys(x) do push(__t,fmt(":%s %s", k, o(x[k]))) end; return __t end)(), " ") .. "}" end
  return tostring(x) end

local function greet(name, excited) name=name==nil and "World" or name; excited=excited==nil and false or excited --> STR
  return "Hello " .. name .. (excited and "!" or ".") end

local function demo(t, f)
  t,f = {}, {}
  
  -- Lambda examples with types: function(args) return expr end
  f.double = function(x) return x*2 end
  f.add = function(a, b) return a+b end
  f.len = function(x) return #x end
  
  -- Function with defaults and types
  t.greeting1 = greet()
  t.greeting2 = greet("Alice")
  t.greeting3 = greet("Bob", true)
  
  -- Compound assignment operators
local counter = 0
local counter = counter + 1
local counter = counter * 2
  
  -- Default values
local name = name==nil and "Unknown" or name
  
  -- Nil-safe navigation
local result = t and t.nonexistent?.field
  
  -- String interpolation
local message = "Hello "..tostring(name)"..", count is "..tostring(counter)"..""
  
  -- Numeric comprehensions: {expr for x=a,b}
  t.squares = (function() local __t={}; for x =1,5 do push(__t,x*x) end; return __t end)()
  t.evens = (function() local __t={}; for x =1,10 do if x%2==0 then push(__t,x*2) end end; return __t end)()
  
  -- Iterator comprehensions: (function() local __t={}; for k,v in pairs(t) do push(__t,expr) end; return __t end)()
  t.data = {name="Alice", age=30, _private="secret", scores={85,92,78}}
  t.values = (function() local __t={}; for _,v in pairs(t.data.scores) do push(__t,v) end; return __t end)()
  t.doubled = (function() local __t={}; for _,v in pairs(t.data.scores) do push(__t,f.double(v)) end; return __t end)()
  
  -- Auto-pairs wrapping (no explicit pairs() needed)
  t.public_keys = (function() local __t={}; for k,_ in pairs(t.data) do if not k"^_" then push(__t,k) end end; return __t end)()
  
  -- Filtered comprehensions
  t.high_scores = (function() local __t={}; for _,v in pairs(t.data.scores) do if v>80 then push(__t,v) end end; return __t end)()
  
  -- Nested comprehensions
  t.matrix = (function() local __t={}; for j =1,3 do push(__t,{i*j) end; return __t end)() for i=1,3}
  
  -- Using utility functions
  t.all_keys = keys(t.data)
  t.sorted_scores = sort(t.values)
  
  -- Store the new features
  t.counter = counter
  t.name = name
  t.message = message
  
  -- Pretty print everything using o()
  (function() local __t={}; for k,v in pairs(t) do push(__t,print(k, o(v))) end; return __t end)()
  
  return t,f end

-- Private function (not exported, starts with _)
function _helper(x) --> Num
  return x * 2 end

-- Method (not made local, has colon)
local MyClass = {}
local function MyClass(name) --> Str
  return "Hello, " .. name end

demo()

return { 
cat=cat
, 
fmt=fmt
, 
sort=sort
, 
keys=keys
, 
keysort=keysort
, 
decorated=decorated
, 
o=o
, 
greet=greet
, 
demo=demo
, 
counter=counter
, 
counter=counter
, 
counter=counter
, 
name=name
, 
result=result
, 
message=message
, 
MyClass=MyClass
, 
MyClass=MyClass
 }
