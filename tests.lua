--------------------------------------------------------------------------------
local lib=require"lib"

local the = {file = os.getenv("HOME") .. "/gits//moot/classify/diabetes.csv",
             seed = 1234567891}

math.randomseed(the.seed); print(math.random())

local n=0 -- sort,map,kap,fmt,trim,coerce
local fn=function(x) n=n+1; if n%75==0 then lib.oo(x) end end
lib.csv(the.file, fn) 

local t={40,10,50,30} -- push, reduce max
lib.push(t, 60)
print(lib.max(t)) 

print(lib.sum(t))  -- sum

--------------------------------------------------------------------------------
local what=require"what"
lib.oo(what.Num(10,"weight-")) -- new
