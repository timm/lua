local cat,fmt,sort,map,kap,_keys,keys,lt,nth

fmt  = string.format
sort = function(t,fn) table.sort(t,fn); return t end
map  = function(t,fn,    u) u={}; for _,v in pairs(t) do u[1+#u]=fn(v)   end; return u end
kap  = function(t,fn,    u) u={}; for k,v in pairs(t) do u[1+#u]=fn(k,v) end; return u end
keys = function(t) return sort(kap(t,_keys)) end
_keys= function(k,_) if not tostring(k):find"^_" then return k end end
lt   = function(k) return function(a,b) return a[k] < b[k] end end 
nth  = function(n) return function(t) return t[n] end end
cat  = function(t) return "{" .. table.concat(map(t,tostring),", ") .. "}" end

function keysort(t,fn,   fn1)
  fn1 = function(x) return {fn(x), x} end
  return map(sort(map(t, fn1), lt(1)), nth(2)) end

function o(x,      fn,u)
  if type(x) == "number" then return x%1==0 and o(x%1) or fmt("%.3f", x) end
  if type(x) == "table" then
    fn = function(k,v) return fmt(":%s %s", k,o(v)) end
    return cat(#x > 0 and map(x,o) or sort(kap(x,fn))) end
  return tostring(x) end

local eg={}
eg.fmt = function() print(fmt("[%-s]",23)) end
eg.keys = function() print(cat(keys{k=10,a=1,_b=2})) end
eg.keysort = function() print(cat(keysort({10,20,30},function(x) return -x end))) end

for _,k in pairs(arg) do 
  k1=string.sub(k,3)
  if eg[k1] then eg[k1]() end end
