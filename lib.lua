-- lib.lua: batteries for Lua
-- (c) 2026 Tim Menzies timm@ieee.org, MIT license
-- vim: set et sw=2 tw=90 :

local lib = {}
local floor,min,abs,log = math.floor,math.min,math.abs,math.log
local rand = math.random

-- oo --
function lib.new(kl,obj) kl.__index=kl; return setmetatable(obj,kl) end

-- tables --
function lib.push(t,x)       t[1+#t]=x; return x end
function lib.sort(t,fn)      table.sort(t,fn); return t end
function lib.map(t,f,     u) u={}; for i,x in ipairs(t) do u[i]=f(x) end; return u end
function lib.kap(t,f,     u) u={}; for k,v in pairs(t) do u[1+#u]=f(k,v) end; return u end
function lib.sum(t,f,     n) n=0; for k,v in pairs(t) do n=n+f(k,v) end; return n end
function lib.kv(t,fk,fv,  u) 
  u={}; for _,x in ipairs(t) do u[fk(x)]=fv(x) end; return u end
function lib.cat(t)          return "{"..table.concat(t,", ").."}" end
function lib.slice(t,lo,hi,  u)
  u={}; for i=(lo or 1),min(hi or #t,#t) do u[1+#u]=t[i] end; return u end
function lib.shuffle(t,     j)
  for i=#t,2,-1 do j=rand(i); t[i],t[j]=t[j],t[i] end; return t end
function lib.many(t,n) return lib.slice(lib.shuffle(t),1,n) end

-- strings --
lib.fmt = string.format
function lib.trim(s) return s:match"^%s*(.-)%s*$" end
function lib.rat(x,     u)
  if math.type(x)=="float" then return lib.fmt("%.2f",x) end
  if type(x)~="table"      then return tostring(x) end
  if #x>0 then return lib.cat(lib.map(x,lib.rat)) end
  u={}; for k,v in pairs(x) do u[1+#u]=k.."="..lib.rat(v) end
  return lib.cat(lib.sort(u)) end
function lib.oo(x) print(lib.rat(x)); return x end

-- io --
function lib.thing(s)
  return s=="true" or 
    (s~="false" and (math.tointeger(s) or tonumber(s) or s)) end
function lib.things(file,     src)
  src=assert(io.open(file))
  return function(     s,t)
    s=src:read(); if s then
      t={}; for x in s:gmatch"[^,]+" do 
        lib.push(t, lib.thing(lib.trim(x))) end; return t 
    end end end

-- math --
function lib.bisect(t, x,    lo, hi, mid)
  lo, hi = 1, #t
  while lo <= hi do
    mid = (lo + hi) // 2
    if t[mid] <= x then lo = mid + 1 else hi = mid - 1 end end
  return lo - 1 end
function lib.weibull(k, lambda)
  return lambda * (-log(1 - rand()))^(1/k) end

return lib
