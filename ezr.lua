#!/usr/bin/env lua
-- ezr3.lua : explainable multi-objective optimization  
-- (c) 2026, Tim Menzies <timm@ieee.org>, MIT license   
    
local the, help = {}, [[   
    
ezr3.lua : explainable multi-objective optimization
(c) 2026, Tim Menzies <timm@ieee.org>, MIT license

  -B Budget=50     initial building budget
  -C Check=5       final check budget
  -c cliffs=0.195  Cliff's delta threshold
  -e eps=0.35      Cohen's threshold
  -k ksconf=1.36   KS test threshold
  -l leaf=3        min rows per tree leaf
  -p p=2           distance coefficient
  -s seed=1        random number seed
  -S Show=30       width LHS tree display
  -h               show help
]]

-- ## Registry & Forward Declarations

-- `l` is for misc library fuctnions
local l = {} 
-- Types and constructors
local NUM, SYM, COLS, DATA, TREE = {}, {}, {}, {}, {} 
local Tree, Sym, Num, Cols, Data
-- Forward references needed for functions defined at end.
local add, sub, adds, mink, wins, split, same, bestRanks

-- ## Structs

-- Constructor for a tree node with a scoring function.
function Tree(fn_score)
  return l.new(TREE, {score=fn_score}) end

-- Constructor for symbolic (categorical) columns.
function Sym(s, n)
  return l.new(SYM, {txt=s or "", at=n or 0, has={}, n=0}) end

-- Constructor for numeric columns. goal=0 for minimize (-), 1 for maximize (+).
function Num(s, n)
  return l.new(NUM, {txt=s or "", at=n or 0, n=0, mu=0, m2=0,
                   goal=s and s:match"-$" and 0 or 1}) end

-- Processes a list of names into specific column roles (Num or Sym).
function Cols(ss_names,    xs,ys,all,col)
  xs, ys, all = {}, {}, {}
  for n, s in ipairs(ss_names) do
    col = l.push(all, (s:match"^[A-Z]" and Num or Sym)(s, n))
    if not s:match"X$" then 
      l.push(s:match"[%+%-!]$" and ys or xs, col) end end
  return l.new(COLS, {x=xs, y=ys, all=all, names=ss_names}) end

-- Main data container for rows and summarized columns.
function Data(src,    data)
  data = l.new(DATA, {rows={}, cols=nil, _mid=nil})
  if type(src)=="string" then for row in l.things(src) do add(data,row) end
  else for _, row in ipairs(src or {}) do add(data,row) end end
  return data end

-- Returns a new Data object with the same structure as the original.
function DATA.clone(i,rows)
  return adds(rows or {}, Data({i.cols.names})) end

-- ## Update

-- Adds a value to a counter or a row to a dataset.
function add(i,v,w) 
  if v~="?" then i:add(v,w or 1) end; return v end

-- Removes a value (adds negative weight).
function sub(i,v) 
  return i:add(v,-1) end

-- Bulk adds a list of values to a counter.
function adds(vs,    num)
  num=num or Num(); for _, v in ipairs(vs or {}) do add(num,v) end; return num end

-- Updates mean and variance for numbers.
function NUM.add(i,v,w,    err)
  i.n = i.n + w
  if w < 0 and i.n <= 2 then i.n, i.mu, i.m2 = 0, 0, 0
  elseif i.n > 0 then
    err=v-i.mu; i.mu=i.mu+w*err/i.n; i.m2=i.m2+w*err*(v-i.mu) end end

-- Updates frequency counts for symbols.
function SYM.add(i,v,w) 
  i.n = i.n + w; i.has[v] = (i.has[v] or 0) + w end

-- Updates all columns with values from a row.
function COLS.add(i,row,w) 
  for _, col in ipairs(i.all) do add(col,row[col.at],w) end; return row end

-- Adds a row and updates column stats.
function DATA.add(i,row,w)
  if not i.cols then i.cols=Cols(row) else
    i._mid=nil; i.cols:add(row,w)
    if w>0 then l.push(i.rows,row) else
      for n, r in ipairs(i.rows) do if r==row then table.remove(i.rows,n); break end end 
    end end end

-- ## Query

-- Mean for numbers.
function NUM.mid(i) return i.mu end

-- Mode for symbols.
function SYM.mid(i,    most,mode)
  most = -1; for v, n in pairs(i.has) do if n>most then most,mode=n,v end end
  return mode end

-- List of midpoints for all columns.
function DATA.mid(i)
  i._mid = i._mid or l.map(i.cols.all, function(col) return col:mid() end); return i._mid end

-- Standard deviation for numbers.
function NUM.spread(i) 
  return i.n > 1 and (math.max(0,i.m2)/(i.n - 1))^0.5 or 0 end

-- Entropy for symbols.
function SYM.spread(i,    n) 
  n=0; for _,v in pairs(i.has) do if v>0 then n=n-v/i.n*math.log(v/i.n,2) end end; return n end

-- Sigmoid normalization.
function NUM.norm(i,v,    sd)
  if v=="?" then return v end
  sd = i:spread() + 1e-32; return 1/(1 + math.exp(-1.7*(v - i.mu)/sd)) end

-- Minkowski distance to ideal goal.
function DATA.disty(i,row,    fn,err,n)
  fn = function(col) return math.abs(col:norm(row[col.at]) - col.goal) end
  err, n = 0, 0
  for _, x in ipairs(l.map(i.cols.y, fn)) do n=n+1; err=err+x^the.p end
  return n==0 and 0 or (err/n)^(1/the.p) end

-- Probability of winning against the median row.
function wins(data,    vs_errs,lo,n_mid)
  vs_errs = l.sort(l.map(data.rows, function(row) return data:disty(row) end))
  lo, n_mid = vs_errs[1], vs_errs[#vs_errs//2+1]
  return function(row) 
    return math.floor(100*(1 - ((data:disty(row)-lo) / (n_mid-lo+1e-32)))) end end

-- ## Tree

-- Builds variance-minimizing tree.
function TREE.build(i,data,rows,    mid,best,bestW,w)
  mid, i.y = data:clone(rows):mid(), adds(l.map(rows, function(r) return i.score(r) end))
  i.mids = l.kv(data.cols.y, function(c) return c.txt end, function(c) return mid[c.at] end)
  if #rows < 2*the.leaf then return i end; best, bestW = nil, 1E32
  for _, col in ipairs(data.cols.x) do
    for _, cut in ipairs(col:splits(rows, i.score)) do
      w = cut.lhs.n * cut.lhs:spread() + cut.rhs.n * cut.rhs:spread()
      if w < bestW and math.min(#cut.left,#cut.right) >= the.leaf then 
        best, bestW = cut, w end end end
  if best then
    i.col, i.cut, i.at = best.col, best.cut, best.col.at
    i.left, i.right = Tree(i.score):build(data, best.left), 
                      Tree(i.score):build(data, best.right) 
  end; return i end

-- Traverses tree to find the relevant leaf for a row.
function TREE.leaf(i,row,    v)
  if not i.col then return i end; v = row[i.at]
  if v=="?" then return i.left:leaf(row) end
  local ok = i.col.mu and (v <= i.cut) or (v == i.cut)
  return (ok and i.left or i.right):leaf(row) end

-- Recursive visitor for nodes.
function TREE.nodes(i,fn,lvl,pre)
  lvl, pre = lvl or 0, pre or ""; fn(i,lvl,pre)
  if not i.col then return end
  local sy, sn = i.col.mu and "<=" or "==", i.col.mu and ">" or "!="
  local nds = l.sort({{i.left,sy},{i.right,sn}}, 
                     function(a,b) return a[1].y:mid() < b[1].y:mid() end)
  for _, p in ipairs(nds) do 
    p[1]:nodes(fn, lvl+1, i.col.txt.." "..p[2].." "..l.rat(i.cut)) end end

-- Prints tree to console.
function TREE.show(i)
  i:nodes(function(node,lvl,pre)
    local p = lvl > 0 and string.rep("|   ", lvl-1)..pre or ""
    io.write(string.format("%-"..the.Show.."s ,%4s ,(%3d),  %s\n",
      p, l.rat(node.y:mid()), node.y.n, l.rat(node.mids))) end) end

-- Partitions rows based on a test.
function split(col,rows,fn,cut,test,    lhs,rhs,L,R,ok)
  lhs, rhs, L, R = Num(), Num(), {}, {}
  for _, row in ipairs(rows) do
    ok = row[col.at]=="?" or test(row[col.at])
    l.push(ok and L or R, row); add(ok and lhs or rhs, fn(row)) end
  if #L >= the.leaf and #R >= the.leaf then
    return {col=col, cut=cut, left=L, right=R, lhs=lhs, rhs=rhs} end end

-- Numeric splits based on median.
function NUM.splits(i,rows,fn,    vs,mu,cut)
  vs = {}; for _, r in ipairs(rows) do if r[i.at]~="?" then l.push(vs, r[i.at]) end end
  if #vs < 2 then return {} end; l.sort(vs); mu = vs[#vs//2+1]
  cut = split(i, rows, fn, mu, function(v) return v<=mu end)
  return cut and {cut} or {} end

-- Symbolic splits based on discrete values.
function SYM.splits(i,rows,fn,    seen,out,cut)
  seen, out = {}, {}
  for _, r in ipairs(rows) do
    local v = r[i.at]
    if v~="?" and not seen[v] then
      seen[v], cut = true, split(i, rows, fn, v, function(x) return x==v end)
      if cut then l.push(out, cut) end end end; return out end

-- ## Stats

-- Non-parametric comparison.
function same(xs,ys,eps,    n,m,ngt,nlt,ks,fn)
  xs,ys = l.sort(xs),l.sort(ys); n,m = #xs,#ys
  if math.abs(xs[n//2+1] - ys[m//2+1]) <= eps then return true end
  ngt, nlt = 0, 0
  for _, v in ipairs(xs) do
    ngt = ngt + l.bisect(ys,v); nlt = nlt + (m - l.bisect(ys, v+1e-32)) end
  if math.abs(ngt - nlt) / (n*m) > the.cliffs then return false end
  ks, fn = 0, function(v) return math.abs(l.bisect(xs,v)/n - l.bisect(ys,v)/m) end
  for _, v in ipairs(xs) do ks = math.max(ks, fn(v)) end
  for _, v in ipairs(ys) do ks = math.max(ks, fn(v)) end
  return ks <= the.ksconf * ((n+m)/(n*m))^0.5 end

-- Groups results into top-tier ranks.
function bestRanks(dict,    names,eps,rows,out)
  names, out = {}, {}; for k in pairs(dict) do l.push(names, k) end
  l.sort(names, function(a,b) return adds(dict[a]):mid() < adds(dict[b]):mid() end)
  eps = adds(dict[names[1]]):spread() * the.eps; rows = dict[names[1]]
  out[names[1]] = adds(rows)
  for i=2,#names do
    if not same(rows, dict[names[i]], eps) then rows = dict[names[i]] end
    out[names[i]] = adds(rows) end; return out end

-- ## Library

-- Sets the metatable index for a new object to enable class-like inheritance.
function l.new(kl,obj) kl.__index=kl; return setmetatable(obj,kl) end

-- Appends an item to the end of a table and returns the added item.
function l.push(t,x) t[1+#t]=x; return x end

-- Sorts a table in-place using an optional comparator and returns the table.
function l.sort(t,f) table.sort(t,f); return t end

-- Transforms a table by applying a function to each element.
function l.map(t,f,  u) u={}; for i,x in ipairs(t) do u[i]=f(x) end; return u end

-- Creates a new table by applying key and value transformation functions.
function l.kv(t,fk,fv,  u) u={}; for _,x in ipairs(t) do u[fk(x)]=fv(x) end; return u end

-- Returns a subset of a table from index lo to hi.
function l.slice(t,lo,hi,  u) 
  u={}; for i=(lo or 1),(hi or #t) do u[1+#u]=t[i] end; return u end

-- Randomizes the order of elements in a table using the Fisher-Yates shuffle.
function l.shuffle(t,  j) 
  for i=#t,2,-1 do j=math.random(i); t[i],t[j]=t[j],t[i] end; return t end

-- Returns a new table containing n randomly selected items from the input.
function l.many(t,n) return l.slice(l.shuffle(t),1,n) end

-- Finds the insertion point for x in a sorted table to maintain order.
function l.bisect(t,x,  lo,hi,m)
  lo,hi = 1,#t; while lo<=hi do 
    m=(lo+hi)//2; if t[m]<=x then lo=m+1 else hi=m-1 end 
  end; return lo-1 end

-- Recursively converts a value or table into a readable string representation.
function l.rat(x)
  if type(x)~="table" then 
    return math.type(x)=="float" and string.format("%.2f",x) or tostring(x) 
  end
  local u={}; for k,v in pairs(x) do 
    u[1+#u]=type(k)=="number" and l.rat(v) or k.."="..l.rat(v) 
  end
  return "{"..table.concat(l.sort(u),", ").."}" end

-- Coerces a string into its most appropriate type: boolean, number, or string.
function l.thing(s) return s=="true" or (s~="false" and (tonumber(s) or s)) end

-- Returns an iterator that yields parsed rows from a CSV file.
function l.things(src,  f)
  f = io.open(src); return function()
    local s = f:read(); if s then
      local t={}; for x in s:gmatch"[^,]+" do 
        l.push(t, l.thing(x:match"^%s*(.-)%s*$")) 
      end; return t
    else f:close() end end end

-- Generates a random variable following the Weibull distribution.
function l.weibull(k, lambda) return lambda * (-math.log(1 - math.random()))^(1/k) end

-- ## Eg (Examples)
local eg = {}

-- Show help string.
eg["-h"] = function() print(help) end

-- Show config.
eg["--the"] = function() print(l.rat(the)) end

-- Master test runner.
eg["--all"] = function(arg,   ss)
  ss = {}
  for k in pairs(eg) do if k ~= "--all" then l.push(ss, k) end end
  for _, k in ipairs(l.sort(ss)) do
    print("\n" .. k); math.randomseed(the.seed); eg[k](arg) end end

-- Dump CSV.
eg["--csv"] = function(f,   n) n=0; for r in l.things(f) do 
  if n%30==0 then print(l.rat(r)) end; n=n+1 end end

-- Synthetic distribution ranking.
eg["--ranks"] = function(    dict,name,k,len)
  dict = {}
  for n = 1, 20 do
    name = "t"..n; dict[name] = {}
    k, len = (n <= 5 and 2 or 1), (n <= 5 and 10 or 20)
    for _ = 1, 50 do l.push(dict[name], l.weibull(k, len)) end end
  print("\nTop Tier Treatments:"); for k, v in pairs(bestRanks(dict)) do 
    print(string.format("  %-5s median: %s", k, l.rat(v:mid()))) end end

-- Column midpoints.
eg["--data"] = function(f,   d) d=Data(f); for _,c in ipairs(d.cols.y) do 
  print(c.txt, l.rat(c:mid())) end end

-- Display tree.
eg["--tree"] = function(f,   d,rs) d=Data(f); rs=l.many(d.rows, the.Budget); d=d:clone(rs)
  Tree(function(r) return d:disty(r) end):build(d, d.rows):show() end

-- Full optimization validation.
eg["--test"] = function(f,   d,outs,fw,n,ts,d2,node,top,fy,fs)
  d = Data(f); outs = Num("win"); fw = wins(d)
  for _ = 1, 20 do
    l.shuffle(d.rows); n = #d.rows // 2; ts = l.slice(d.rows, n + 1)
    d2 = d:clone(l.slice(d.rows, 1, math.min(n, the.Budget)))
    node = Tree(function(r) return d2:disty(r) end):build(d2, d2.rows)
    l.sort(ts, function(a,b) return node:leaf(a).y:mid() < node:leaf(b).y:mid() end)
    top = l.sort(l.slice(ts, 1, the.Check), function(a,b) 
      return d2:disty(a) < d2:disty(b) end)
    add(outs, fw(top[1])) end
  print(l.rat(math.floor(outs:mid()))) end

-- ## Main

-- Use the `help` text to fill in `the`.
for k,v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)") do the[k]=l.thing(v) end

--  Cli contents either call `eg` functions or reset cotnents of `the`.
local function main(   k,v,n)
  n=1; while n <= #arg do
    k,v = arg[n], arg[n+1]
    n=n+1
    if eg[k] then 
      math.randomseed(the.seed)
      eg[k](v and l.thing(v) or nil)
      if v and not eg[v] then n=n+1 end
    else 
      for k1,v1 in pairs(the) do 
        if k=="-"..k1:sub(1,1) then 
          the[k1]=l.thing(v); n=n+1 end end end end end

-- Maybe call main
if (arg[0] or ""):match"ezr.lua" then main() end

-- That's all folks
return {the=the, DATA=DATA, NUM=NUM, SYM=SYM, TREE=TREE, l=l}
