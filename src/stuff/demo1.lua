local the,help = {}, [[
ezr.py (v0.5): lightweight XAI for multi-objective optimization   
(c) 2025, Tim Menzies <timm@ieee.org>, MIT license      
[code](https://github.com/timm/ezr) :: 
[data](https://github.com/timm/moot)    

Options:
   
    -a  acq=near          label with (near|xploit|xplor|bore|adapt)
    -A  Any=4             on init, how many initial guesses?   
    -B  Budget=30         when growing theory, how many labels?   
    -C  Check=5           budget for checking learned model
    -D  Delta=smed        effect size test for cliff's delta
    -F  Few=128           sample size of data random sampling  
    -K  Ks=0.95           confidence for Kolmogorovâ€"Smirnov test
    -l  leaf=3            min items in tree leaves
    -m  m=1               Bayes low frequency param
    -p  p=2               distance co-efficient
    -s  seed=1234567891   random number seed   
    -f  file=../moot/optimize/misc/auto93.csv    data file 
    -h                     show help  ]] 

local map,map,sort,keys,_keys,gt,lt,nth,cat,pcat,fmt,oo,fsort
local coerce,csv,trim,cells
local sqrt,max,min=math.sqrt,math.max, math.min
local SYM,NUM,COLS,DATA = {},{},{},{}
local BIG = 1E32

-------------------------------------------------------------------------------
function SYM:new(  i,is) 
  return new(SYM, {n=0, i=i or 0, is=is or "", has={}}) end

function NUM:new(  i,is)
  return new(NUM, {n=0, i=i or 0, is= is or "", 
                   mu=0, sd=0, m2=0, lo=BIG, hi=-BIG,
                   best = (is or ""):find"-$" and 0 or 1}) end

function COLS:new(names,     all,x,y,col)
  all,x,y = {},{},{}
  for i,is in pairs(names) do
    col = push(all, (is:find"^[A-Z]" and NUM or SYM):new(i,is))
    if not is:find"X$" then
      push(is:find"[!+-]$" and y or x, col) end end
  return new(COLS, {names=names, all=all, x=x, y=y}) end

function DATA:new(    rows) 
  return adds(rows, new(DATA, {rows={}, cols=nil})) end

function DATA:clone(  rows) 
  return adds(rows, DATA:new({self.cols.names})) end

-------------------------------------------------------------------------------
function adds(src, it)
  it = it or Num()
  for _,x in pairs(src or {}) do add(it,x) end
  return it end

function sub(x, v, zap) return add(x, v, -1, zap or false) end

function add(x, v, inc, zap)
  if v == "?" then return v end
  x.n = x.n + (inc or 1)
  x:_add(v, inc or 1, zap or false)
  return v end

function Num:_add(v, inc)
  self.lo = min(v, self.lo)
  self.hi = max(v, self.hi)
  if inc < 0 and self.n < 2 then
    self.sd, self.m2, self.mu, self.n = 0, 0, 0, 0
  else
    local d = v - self.mu
    self.mu = self.mu + inc * (d / self.n)
    self.m2 = self.m2 + inc * (d * (v - self.mu))
    self.sd = self.n < 2 and 0 or sqrt(max(0, self.m2) / (self.n - 1)) end end

function Sym:_add(v, inc)
  self.has[v] = inc + (self.has[v] or 0) end

function Data:_add(v, inc, zap)
  self.mid = nil
  if inc > 0 then
    table.insert(self.rows, v)
  elseif zap then
    for i, row in ipairs(self.rows) do
      if row == v then table.remove(self.rows, i); break end end end
  for _, col in ipairs(self.cols.all) do add(col, v[col.at], inc, zap) end end

-- -----------------------------------------------------------------------------------
function DATA:csv(file)
  csv(file, function(n,row) self:add(row) end); return self end

function DATA:from(  rows)
  for _,row in pairs(rows or {}) do self:add(row) end
  return self end

--## Lib

function new(kl,obj)
  kl.__index=kl; kl.__tostring=o; return setmetatable(obj,kl) end

-- Map
map = function(t,fn) return kap(t,function(_,v) return fn(v) end) end

function kap(t,fn,    u) 
  u={};for k,v in pairs(t) do u[1+#u]=fn(k,v) end;return u end

-- Sort
sort = function(t,fn) table.sort(t,fn); return t end
keys = function(t)    return sort(kap(t,_keys)) end
_keys= function(k,_)  if not tostring(k):find"^_" then return k end end

function fsort(t,fn,   decorate)
  decorate = function(x) return {fn(x), x} end
  return map(sort(map(t, decorate), lt(1)), nth(2)) end

-- Higher order
gt   = function(k) return function(a,b) return a[k] > b[k] end end 
lt   = function(k) return function(a,b) return a[k] < b[k] end end 
nth  = function(n) return function(t) return t[n] end end

-- Lists
push = function(t,x) t[1+#t]=x; return x end

-- Show
fmt  = string.format
cat  = function(t) return "{"..table.concat(map(t,tostring),", ").."}" end
pcat = function(t) print(cat(t)) end
oo   = function(x) print(o(x)); return x end

function o(x,      fn,u)
  if type(x)=="number" then return x%1==0 and o(x//1) or fmt("%.3f", x) end
  if type(x)=="table" then
    kv = function(k,v) return fmt(":%s %s", k,o(v)) end
    return cat(#x > 0 and map(x,o) or sort(kap(x,kv))) end
  return tostring(x) end

-- Strings to things
function coerce(s,     fun)   
  fun = function(s) return s=="true" and true or s ~= "false" and s end
  return math.tointeger(s) or tonumber(s) or fun(trim(s)) end

function csv(file,fun,      src,s,cells,n)
  src = io.input(file)
  while true do
    s = io.read()
    if s then fun(cells(s)) else return io.close(src) end end end

function cells(s,    t)
  t={}; for s1 in s:gmatch"([^,]+)" do push(t,coerce(s1)) end; return t end

function trim(s)  return s:match"^%s*(.-)%s*$" end

-------------------------------------------------------------------------------
local eg={}

eg.fmt = function() print(fmt("[%-s]",23)) end
eg.keys = function() pcat(keys{k=10,a=1,_b=2}) end
eg.fsort = function() pcat(fsort({10,20,30},function(x) return -x end)) end

-------------------------------------------------------------------------------
help:gsub("\n%s+-%S%s(%S+)[^=]+=%s+(%S+)", function(k,v) the[k]=coerce(v) end)
math.randomseed(the.seed)

for _,k in pairs(arg) do 
  k1=string.sub(k,3)
  if eg[k1] then eg[k1]() end end
