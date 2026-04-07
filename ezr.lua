#!/usr/bin/env lua
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

-- ## Registry & Forward Declarations <a name=registry>

-- `l` is for misc library functions
local l = {} 
-- Types and constructors
local NUM, SYM, COLS, DATA, TREE = {}, {}, {}, {}, {} 
local Tree, Sym, Num, Cols, Data
-- Forward references needed for functions defined at end.
local add, sub, adds, mink, wins, split, same, bestRanks

-- Maths
local abs,min,max,log,exp = math.abs,math.min,math.max,math.log,math.exp
local floor,rand,randomseed = math.floor, math.random, math.randomseed

-- ## Structs <a name=structs>

-- Constructor for a tree node with a scoring function.
function Tree(fn_score)
  return l.new(TREE, {score=fn_score}) end

-- Constructor for symbolic (categorical) columns.
function Sym(s, n)
  return l.new(SYM, {txt=s or "", at=n or 0, has={}, n=0}) end

-- Constructor for numerics. "-+" menas heaven = 0,1 for minimze,maximize
function Num(s, n)
  return l.new(NUM, {txt=s or "", at=n or 0, n=0, mu=0, m2=0,
                     heaven=s and s:match"-$" and 0 or 1}) end

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
  if type(src)=="string" 
  then for    row in l.csv(src)        do add(data,row) end
  else for _, row in ipairs(src or {}) do add(data,row) end end
  return data end

-- Returns a new Data object with the same structure as the original.
function DATA.clone(i,rows)
  return adds(rows or {}, Data({i.cols.names})) end

-- ## Update <a name=update>

-- Removes a value is just adding with -`.
function sub(i,v) return i:add(v,-1) end

-- Bulk adds a list of values to some summary object (defaults to Num()).
function adds(vs,  summary)
  summary = summary or Num()
  for _, v in ipairs(vs or {}) do add(summary,v) end
  return summary end

-- Adds a value to a counter or a row to a dataset.
function add(i,v,w) 
  if v~="?" then i:_add(v,w or 1) end; return v end

-- Updates mean and variance for numbers.
function NUM._add(i,v,w,    err)
  i.n = i.n + w
  if w < 0 and i.n <= 1
  then i.n, i.mu, i.m2 = 0,0,0
  else
    err  = v-i.mu
    i.mu = i.mu + w * err/i.n
    i.m2 = i.m2 + w * err*(v-i.mu) end end

-- Updates frequency counts for symbols.
function SYM._add(i,v,w) i.has[v] = w + (i.has[v] or 0) end

-- Updates all columns with values from a row.
function COLS._add(i,row,w) 
  for _, col in ipairs(i.all) do add(col,row[col.at],w) end
  return row end

-- Adds a row and updates column stats.
function DATA._add(i,row,w)
  if not i.cols then i.cols=Cols(row) 
  else i._mid = nil
       add(i.cols, row, w)
       if w>0 
       then l.push(i.rows,row) 
       else 
         for n, r in ipairs(i.rows) do 
           if r==row then table.remove(i.rows,n) break end end end end end

-- ## Query <a name=query>

-- Mean for numbers.
function NUM.mid(i) return i.mu end

-- Mode for symbols.
function SYM.mid(i,    most,mode)
  most = -1
  for v, n in pairs(i.has) do if n>most then most,mode=n,v end end
  return mode end

-- List of midpoints for all columns.
function DATA.mid(i)
  i._mid = i._mid or l.map(i.cols.all, function(col) return col:mid() end)
  return i._mid end

-- Spread for numbers: standard deviation
function NUM.spread(i) 
  return i.n > 1 and (max(0,i.m2)/(i.n - 1))^0.5 or 0 end

-- Entropy for symbols: sum -p*log(p)
function SYM.spread(i,    fn) 
  return - sum(i.has, function(v) return v/i.n * log(v/i.n, 2) end) end

-- Sigmoid normalization.
function NUM.norm(i,v,    sd)
  if v=="?" then return v end
  z = (v - i.mu) / (spread() + 1e-32)
  return 1/(1 + exp(-1.7*l.crop(z,-3,3))) end

-- Minkowski distance to ideal goal.
function DATA.disty(i,row,    fn)
  fn = function(col) return abs(col:norm(row[col.at]) - col.heaven)^the.p end
  return (sum(i.cols.y,fn) / #i.cols.y) ^ (1/the.p) end

-- Probability of winning against the median row.
function wins(data,    ys,lo,n_mid)
  ys = l.sort(l.map(data.rows, function(row) return data:disty(row) end))
  lo, n_mid = ys[1], ys[#ys//2+1]
  return function(row) 
    return floor(100*(1 - ((data:disty(row)-lo) / (n_mid-lo+1e-32)))) end end

-- ## Tree <a name=tree>

-- Builds variance-minimizing tree.
function TREE.build(i,data,rows,    mid,best,bestW,w)
  mid, i.y = data:clone(rows):mid(), adds(l.map(rows, function(r) return i.score(r) end))
  i.mids = l.kv(data.cols.y, function(c) return c.txt end, function(c) return mid[c.at] end)
  if #rows < 2*the.leaf then return i end; best, bestW = nil, 1E32
  for _, col in ipairs(data.cols.x) do
    for _, cut in ipairs(col:splits(rows, i.score)) do
      w = cut.lhs.n * cut.lhs:spread() + cut.rhs.n * cut.rhs:spread()
      if w < bestW and min(#cut.left,#cut.right) >= the.leaf then 
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
    p[1]:nodes(fn, lvl+1, i.col.txt.." "..p[2].." "..l.o(i.cut)) end end

-- Prints tree to console.
function TREE.show(i)
  i:nodes(function(node,lvl,pre)
    local p = lvl > 0 and string.rep("|   ", lvl-1)..pre or ""
    io.write(l.fmt("%-"..the.Show.."s ,%5.2f ,(%3d),  %s\n",
      p, l.o(node.y:mid()), node.y.n, l.o(node.mids))) end) end 

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

-- ## Stats <a name=stats>

-- Non-parametric comparison.
-- Checks if two distributions are the same using Cliffs Delta and KS test.
local function same(xs,ys,eps,    n,m,ngt,nlt,ks,fn)
  xs,ys = l.sort(xs), l.sort(ys)
  n,m   = #xs,#ys

  if abs(xs[n//2+1] - ys[m//2+1]) <= eps then return true end -- cohen

  ngt,nlt = 0,0
  for _,v in ipairs(xs) do 
    ngt = ngt + l.bisect(ys,v)
    nlt = nlt + (m - l.bisect(ys,v+1e-32)) end
  if abs(ngt - nlt) / (n*m) > the.cliffs then return false end -- cliffs

  ks,fn = 0, function(v) return abs(l.bisect(xs,v)/n - l.bisect(ys,v)/m) end
  for _,v in ipairs(xs) do ks = max(ks, fn(v)) end
  for _,v in ipairs(ys) do ks = max(ks, fn(v)) end
  return ks <= the.ksconf * ((n+m)/(n*m))^0.5 end -- KS test
 
-- Groups results into top-tier ranks.
-- Sorts treatments by median and groups them into ranks using the same() test.
local function bestRanks(dict)
  local out,names,eps,rows = {},{}
  for k in pairs(dict) do l.push(names, k) end
  l.sort(names, function(a,b) return adds(dict[a]):mid() < adds(dict[b]):mid() end)
  eps = adds(dict[names[1]]):spread() * the.eps
  rows = dict[names[1]]
  out[names[1]] = adds(rows, Num(names[1]))
  for n=2,#names do
    if   same(rows, dict[names[n]], eps) 
    then out[names[n]] = adds(rows, Num(names[n])) 
    else break end end
  return out end 

-- ## Library <a name=lib>

-- Sets the metatable index for a new object to enable polymorphism.
function l.new(kl,obj) kl.__index=kl; return setmetatable(obj,kl) end

-- Crop number into range lo...hi
function l.crop(n,lo,hi) return max(lo, min(hi,n)) emd

-- Appends an item to the end of a table and returns the added item.
function l.push(t,x) t[1+#t]=x; return x end

-- Dictionary to lists.
function l.t2d(d,  u)
  u={}; for _,x in pairs(d) do u[1+#u] = x end; return u end

-- Return a sorter for lists of field x.
function l.lt(x) return function(a,b) return a[x] < b[x] end end

-- Sorts a table in-place using an optional comparator and returns the table.
function l.sort(t,f) table.sort(t,f); return t end

-- Transforms a table by applying a function to each element.
function l.map(t,f,  u) 
  u={}; for i,x in ipairs(t) do u[i]=f(x) end; return u end

-- Creates a new table by applying key and value transformation functions.
function l.kv(t,fk,fv,  u) 
  u={}; for _,x in ipairs(t) do u[fk(x)]=fv(x) end; return u end

-- Returns a subset of a table from index lo to hi.
function l.slice(t,lo,hi,  u) 
  u={}; for i=(lo or 1),(hi or #t) do u[1+#u]=t[i] end; return u end

-- Randomizes the order of elements in a table using the Fisher-Yates shuffle.
function l.shuffle(t,  j) 
  for i=#t,2,-1 do j=rand(i); t[i],t[j]=t[j],t[i] end; return t end

-- Returns a new table containing n randomly selected items from the input.
function l.many(t,n) return l.slice(l.shuffle(t),1,n) end

-- Finds the insertion point for x in a sorted table to maintain order.
function l.bisect(t,x,  lo,hi,m)
  lo,hi = 1,#t; while lo<=hi do 
    m=(lo+hi)//2; if t[m]<=x then lo=m+1 else hi=m-1 end 
  end; return lo-1 end

l.fmt = string.format

-- Recursively converts a value or table into a readable string representation.
function l.o(x,       u) 
  if type(x) ~= "table" then 
    return math.type(x) == "float" and string.format("%.2f", x) or tostring(x) end
  u = {}
  for k, v in pairs(x) do 
    u[1 + #u] = type(k) == "number" and l.o(v) or k .. "=" .. l.o(v) end
  return "{" .. table.concat(l.sort(u), ", ") .. "}" end

-- Coerces a string into its most appropriate type: boolean, number, or string.
function l.thing(s) return s=="true" or (s~="false" and (tonumber(s) or s)) end

-- Returns an iterator that yields parsed rows from a CSV file.
function l.csv(src,  f)
  f = io.open(src)
  return function(      s,t)
    s = f:read()
    if s then
      t={}
      for x in s:gmatch"[^,]+" do l.push(t,l.thing(x:match"^%s*(.-)%s*$")) end
      return t
    else f:close() end end end

-- Generates a random variable following the Weibull distribution.
function l.weibull(k, lambda) return lambda * (-log(1 - rand()))^(1/k) end

-- ## Eg (Examples) <a name=eg>
local eg = {}

-- Show help string.
eg["-h"] = function(_) print(help) end

-- Show config.
eg["--the"] = function(_) print(l.o(the)) end

-- Master test runner.
eg["--all"] = function(arg,   ss)
  ss = {}
  for k in pairs(eg) do if k ~= "--all" then l.push(ss, k) end end
  for _, k in ipairs(l.sort(ss)) do
    print("\n" .. k); randomseed(the.seed); eg[k](arg) end end

-- Dump CSV.
eg["--csv"] = function(f,   n) n=0; for r in l.csv(f) do 
  if n%30==0 then print(l.o(r)) end; n=n+1 end end

-- Synthetic distribution ranking.
-- Tests ranking logic by generating Weibull distributions.
-- Generates and ranks 20 treatments using different distribution shapes.
eg["--ranks"] = function(_,    dict,name,k,lambda,res)
  dict = {}
  for n=1,20 do
    name = "t"..n; dict[name] = {}
    k,lambda = (n<=5 and 2 or 1), (n<=5 and 10 or 20)
    for _ = 1,50 do l.push(dict[name], l.weibull(k,lambda)) end end
  print("\nTop Tier Treatments:")
  u = l.sort(l.t2d(bestRanks(dict)), l.lt"mu")
  for _,num in ipairs(u) do
    print(l.fmt("%-5s median: %5.2f", num.txt, num:mid())) end end
     
-- Column midpoints.
eg["--data"] = function(f,   d) d=Data(f); for _,c in ipairs(d.cols.y) do 
  print(c.txt, l.o(c:mid())) end end

-- Display tree.
eg["--tree"] = function(f,   d,rs) 
  d  = Data(f)
  rs = l.many(d.rows, the.Budget)
  d  = d:clone(rs)
  Tree(function(r) return d:disty(r) end):build(d, d.rows):show() end

-- Full optimization validation.
eg["--test"] = function(src)
  local data,stats,fn_win,n,test,d2,node,top,f_dist,f_leaf,f_dist2
  data = Data(src); stats = Num("win")
  if not data.cols then return end 
  fn_win = wins(data) 
  for _ = 1, 20 do
    l.shuffle(data.rows)
    n = #data.rows // 2
    test = l.slice(data.rows, n + 1)
    d2 = data:clone(l.slice(data.rows, 1, math.min(n, the.Budget)))
    f_dist  = function(r)   return d2:disty(r) end
    node    = Tree(f_dist):build(d2, d2.rows)
    f_leaf  = function(a,b) return node:leaf(a).y:mid() < node:leaf(b).y:mid() end
    f_dist2 = function(a,b) return d2:disty(a) < d2:disty(b) end
    l.sort(test, f_leaf)
    top = l.sort(l.slice(test, 1, the.Check), f_dist2)
    add(stats, fn_win(top[1])) end
  print(l.o(math.floor(stats:mid()))) end

-- ## Main <a name=main>

-- Use the `help` text to fill in `the`.
for k,v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)") do the[k]=l.thing(v) end

--  Cli contents either call `eg` functions or reset contents of `the`.
local function main(   k,v,n)
  n = 1
  while n <= #arg do
    n, k,v = n + 1, arg[n], arg[n+1]
    if eg[k] then 
      randomseed(the.seed)
      eg[k](v and l.thing(v) or nil)
      if v and not eg[v] then n=n+1 end
    else 
      for k1 in pairs(the) do 
        if k=="-"..k1:sub(1,1) then 
          the[k1] = l.thing(v)
          n=n+1 end end end end end

-- Maybe call main
if (arg[0] or ""):match"ezr.lua" then main() end

-- That's all folks
return {the=the, DATA=DATA, NUM=NUM, SYM=SYM, TREE=TREE, l=l}
