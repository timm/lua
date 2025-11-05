local function isa(x,y) return setmetatable(y,x) end
local function is(s,    t) t={a=s}; t.__index=t; return t end

local l = {}            -- misc library utilities
local NUM,SYM,COLS,DATA -- constructors
local Num,Sym,Cols,Data = is"Num", is"Sym", is"Cols", is"Data" -- objects
--------- --------- --------- --------- --------- --------- --------- --------- 
function NUM(at,txt)
  return isa(Num, {at=at, txt=txt, n=0, lo=1E30, hi= -1E30, mu=0, m2=2, sd=0,
                   heaven=(txt or ""):find"-$" and 0 or 1}) end

function SYM(at,txt)
  return isa(Sym, {at=at, txt=txt, n=0, has={}}) end

function COLS(t,     cols)
  cols = isa(Cols, {names=t, all={}, x={}, y={}})
  for at,txt in pairs(t) do
    col = (txt:find"^[A-Z]" and NUM or SYM)(at,txt)
    push(col, cols.all)
    if not txt:find"X$" then
      push(col, txt:find"[+-!]$" and cols.y or cols.x) end end  
  return cols end

function DATA(src,  ordered,    data)
  data = isa(Data, {rows={},cols={}})
  data.adds(data,src)
  if ordered then l.keysort(data.rows, data:d2h) end
  return data end

function Data.adds(data,src)
  if   type(src)=="string"
  then for   t in csv(src)         do data.add(t) end
  else for _,t in pairs(src or {}) do data.add(t) end end 
  return data end

function Data.clone(data1,  also)
  return Data.adds(DATA{data1.cols.names},also) end
--------- --------- --------- --------- --------- --------- --------- --------- 
function Data:add(data,t)
  if   #data.cols==0
  then data.cols = COLS(t)
  else l.push(data.cols:add(t),  data.rows) end end

function Cols:add(cols,t)
  for _,cols in pairs{cols.x, cols.y} do
    for _,col in pairs(cols) do
      col:add(t[col.at]) end end end

function Sym:add(sym,x) 
  if x ~= "?" then
    sym.n = sym.n + 1
    sym.has[x] = 1 + (sym.has[x] or 0) end end

function Num:add(num,x)
  if x ~= "?" then
    num.n = num.n + 1
    d      = x - num.mu
    num.mu = num.mu + d / num.n
    num.m2 = num.m2 + d * (x -  num.mu)
    num.sd = num.n > 1 ? (num.m2 / (num.n - 1))^.5 : 0
    num.lo = math.min(x, num.lo)
    num.hi = math.max(x, num.hi) end end
--------- --------- --------- --------- --------- --------- --------- --------- 
l.fmt = string.format
function l.push(x,t)     t[1+#t]=x; return x end
function l.sort(t,  fun) table.sort(t,fun); return t end

function l.map(t,fun,...) 
  local u={}; for _,v in pairs(t) do u[1+#u]=fun(v,...)   end; return u end

function l.kap(t,fun,...)
  local u={}; for k,v in pairs(t) do u[1+#u]=fun(k,v,...) end; return u end

function l.coerce(s1,    fun)
  function fun(s2)
    if s2=="nil" then return nil else return s2=="true" or (s2~="false" and s2) end end
  return math.tointeger(s1) or tonumber(s1) or fun(s1:match'^%s*(.*%S)') end

function l.cells(s1,    t)
  t={}; for s2 in s1:gmatch("([^,]+)") do t[1+#t]=l.coerce(s2) end;
  return t end

function l.csv(src)
  src = src=="-" and io.stdin or io.input(src)
  return function(   line)
     line = io.read()
     if line then return l.cells(line) else io.close(src) end end end

function l.rnd(n, ndecs)
  if type(n) ~= "number" then return n end
  if math.floor(n) == n  then return n end
  local mult = 10^(ndecs or 3)
  return math.floor(n * mult + 0.5) / mult end

function l.oo(x,  ndecs) print(l.o(x,ndecs)); return x end

function l.o(x,  ndecs,     fun, u)
  function fun(k, v)
    k = tostring(k)
    if not k:find "^_" then
      return l.fmt(":%s %s", k, l.o(v, ndecs)) end end
  if type(x) == "number" then return tostring(l.rnd(x,ndecs)) end
  if type(x) ~= "table" then return tostring(x) end
  u = #x == 0 and l.sort(l.kap(x, fun)) or l.map(x, l.o, ndecs)
  return "{"..table.concat(u,", ").."}" end

function l.keysort(t,fun,      u,v)
  u={}; for _,x in pairs(t) do u[1+#u]={x=x, y=fun(x)} end -- decorate
  table.sort(u, function(a,b) return a.y < b.y end) -- sort
  v={}; for _,xy in pairs(u) do v[1+#v] = xy.x end -- undecoreate
  return v end
