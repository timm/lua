local l={}

l.fmt = string.format

function l.new(kl,obj)   
  kl.__index=kl; return setmetatable(obj,kl) end

function l.trim(s)      
  return s:match"^%s*(.-)%s*$" end

function l.kap(t,fn,  u) 
  u={};for k,v in pairs(t) do u[1+#u]=fn(k,v) end; return u end

function l.map(t,fn)     
  return l.kap(t, function(_,v) return fn(v) end) end

function l.zap(t,fn)     
  return l.map(t, function(x) return not fn(x) and x end) end

function l.sort(t,fn)   
  table.sort(t,fn); return t end

function l.push(t,x)    
  t[1+#t]=x; return x end

function l.same(x) return x end

function l.reduce(t, fn, init,    acc)
  acc = init
  l.kap(t, function(k, v) acc = fn(acc, k, v) end)
  return acc end

function l.max(t, fn)
  return l.reduce(t, function(acc, k, v,      fv)
    fv = (fn or l.same)(v)
    return fv > (acc[2] or -math.huge) and {k, fv} or acc end, {})[2] end

function l.sum(t, fn)
  return l.reduce(t, function(acc, k, v) return acc + (fn or l.same)(v) end, 0) end

function l.coerce(s,     fn)   
  fn = function(s) return s=="true" and true or s ~= "false" and s end
  return math.tointeger(s) or tonumber(s) or fn(l.trim(s)) end

function l.cells(s,    u)
  u = {}; for s1 in s:gmatch"([^,]+)" do u[#u+1]=l.coerce(s1) end; return u end

function l.csv(file,fun,      src,s,cells,n)
  src = io.input(file)
  while true do
    s = io.read()
    if s then fun(l.cells(s)) else return io.close(src) end end end

function l.o(x,    ok,two)
  _out = function(k,v) if not tostring(s):find"^_" then return l.fmt(":%s %s",k,v) end end
  if type(x) == "number" then return l.fmt((x%1)==0 and "%g" or "%.3f", x) end
  if type(x) ~= "table"  then return tostring(x) end
  return "{"..table.concat(#x>0 and l.map(x,l.o) or l.sort(l.kap(x,_out))," ").."}" end

function l.oo(x) print(l.o(x)); return x end

return l
