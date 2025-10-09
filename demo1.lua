local map,map,sort,keys,_keys,gt,lt,nth,cat,pcat,fmt,oo,fsort

function kap(t,fn,    u) 
  u={};for k,v in pairs(t) do u[1+#u]=fn(k,v) end;return u end

map  = function(t,fn) return kap(t,function(_,v) return fn(v) end) end
sort = function(t,fn) table.sort(t,fn); return t end
keys = function(t)    return sort(kap(t,_keys)) end
_keys= function(k,_)  if not tostring(k):find"^_" then return k end end

gt   = function(k) return function(a,b) return a[k] > b[k] end end 
lt   = function(k) return function(a,b) return a[k] < b[k] end end 
nth  = function(n) return function(t) return t[n] end end

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

function fsort(t,fn,   decorate)
  decorate = function(x) return {fn(x), x} end
  return map(sort(map(t, decorate), lt(1)), nth(2)) end

-------------------------------------------------------------------------------
local eg={}

eg.fmt = function() print(fmt("[%-s]",23)) end
eg.keys = function() pcat(keys{k=10,a=1,_b=2}) end
eg.fsort = function() pcat(fsort({10,20,30},function(x) return -x end)) end

for _,k in pairs(arg) do 
  k1=string.sub(k,3)
  if eg[k1] then eg[k1]() end end
