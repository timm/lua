function new(kl,obj)   
  kl.__index=kl; return setmetatable(obj,kl) end

local NUM,SYM,COLS,DATA = {},{},{},{}

function trim(s) return s:match"^%s*(.-)%s*$" end

function cast(s) 
  return s=="true" or s~="false" and (math.tointeger(s) or tonumber(s) or s) end

function s2row(s,c,    t) 
  t={}; for x in s:gmatch("[^"..c.."]+") do t[#t+1]=cast(trim(x)) end return t end

function csv(file,    src)
  src = assert(io.open(file))
  return function(s)
    s=src:read()
    if s then return casts(s) else src:close() end end end

function sort(t,fn) table.sort(t,fn) return t end
function map(t,f, u) u={}; for i,x in ipairs(t) do u[i]=f(x) end; return u end

function cat(t) return "{"..table.concat(t,", ") .."}" end

function rat(x,  u) 
  if math.type(x)=="float" then return string.format("%.2f",x) end
  if type(x)~="table"      then return tostring(x) end
  if #x>0                  then return cat(map(x,rat)) end
  u={}; for k,v in pairs(x) do u[#u+1]=string.format("%s=%s",k,rat(v)) end
  return cat(sort(u)) end

local Num,Sym,Cols,Data

function Sym(at,s) return new(SYM, {txt=s, at=at or 0, n=0, has={}}) end
function Num(at,s) return new(SYM, {txt=s, at=at or 0, n=0, mu=0,m2=0} end

function cast(s) return int(s) or tonumber(s) or s:match"^%s*(.-)%s*$" end

function casts(s,    t) t={}; for x in s:gmatch"[^,]+" do t[1+#t]=cast(x) end; return t end

-- functional -----------------------------------------------------
local function sum(t,f,   n) 
  n=0; for _,v in pairs(t) do n=n+f(v) end
  return n end

local function kap(t,f,   u) 
  u={}; for k,v in pairs(t) do u[1+#u]=f(k,v) end
  return u end

l
function Cols(names,   x,y,col,cols)
  x,y,cols = {},{},{}
  for at,s in pairs(names) do
    col = push(cols, (s:find"^[A-Z]" and Num or Sym)(at,s)) 
    if not s:find"X$" then 
      push(s:find"[+-!]$" and y or x, col) end end
  return new(COLS,{x=x, y=y, all=cols, names=names}) end

function Data() 
  return new(DATA, {rows={}, cols=nil}) end

-------------------------------------------------------------------------------
function DATA.add(i,row)
  if i.cols 
  then push(i.rows, i.cols:add(row))
  else i.cols = COLS:new(row) end end
function SYM.add(i,v)
  if v ~= "?" then
    i.n = i.n + 1
    i.has[v] = 1 + (i.has[v] or 0)
    if i.has[v] > i.most then 
      i.most, i.mode = i.has[v], v end end 
  return v end

function NUM.add(i,v,    d)
  if v ~= "?" then
    i.n  = i.n + 1
    d    = x - i.mu
    i.mu = i.mu + d / i.n
    i.m2 = i.m2 + d * (x - i.mu)
    i.sd = i.n < 2 and 0 or (i.m2/(i.n - 1))^.5 
    if x > i.hi then i.hi = x end
    if x < i.lo then i.lo = x end end 
  return v end 

-


