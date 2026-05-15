#!/usr/bin/env fun
-- vim: ft=fun
let the, help= {}, [[
ezr.fun : explainable multi-objective optimization
(c) 2026, Tim Menzies <timm@ieee.org>, MIT license
  -B Budget=50     initial building budget
  -C Check=5       final check budget
  -c cliffs=0.195  Cliff's delta threshold
  -e eps=0.35      Cohen's threshold
  -f file=auto93.csv  data file
  -k ksconf=1.36   KS test threshold
  -l leaf=3        min rows per tree leaf
  -p p=2           distance coefficient
  -s seed=1        random number seed
  -S Show=30       width LHS tree display
  -h               show help
]]
let DATA, NUM, SYM, TREE, l

-- ## Registry
-- Forward declarations.
l= {}
let COLS= {}
let Tree, Sym, Num, Cols, Data
let add, sub, adds, mink, wins, split, same, bestRanks

-- Math shortcuts.
let abs,min,max,log,exp =
  math.abs, math.min, math.max, math.log, math.exp
let floor,rand,randomseed=
  math.floor, math.random, math.randomseed
let mtype= math.type

-- ## Classes
-- Tree node with scoring fn.
let TREE={}
Tree= fun(fn_score)
  !l.new(TREE, {score=fn_score}) end 

-- Symbolic (categorical) column.
let SYM={}
Sym= fun(s,n)
  !l.new(SYM, {txt=s or "", at=n or 0, has={}, n=0}) end

-- Numeric column. Trailing "-" => minimize (heaven=0).
let NUM={}
Num= fun(s,n)
  let h= s and s:match"-$" and 0 or 1
  !l.new(NUM,
         {txt=s or "", at=n or 0,
          n=0, mu=0, m2=0, heaven=h}) end

-- Names list -> columns (Num/Sym; x/y/all).
let COLS={}
Cols= fun(ss_names)
  let xs,ys,all= {},{},{}
  for n,s in ipairs(ss_names) do
    let cls= s:match"^[A-Z]" and Num or Sym
    let col= l.push(all, cls(s,n))
    if (not s:match"X$")
      let bin= s:match"[%+%-!]$" and ys or xs
      l.push(bin, col) end end
  !l.new(COLS,
         {x=xs, y=ys, all=all, names=ss_names}) end

-- Data container: rows + summarized columns.
let DATA={}
Data= fun(src)
  let data= l.new(DATA, {rows={}, cols=nil, _mid=nil})
  if (type(src) == "string")
    for row in l.csv(src) do add(data, row) end
  else
    for _,row in ipairs(src or {}) do
      add(data, row) end end
  !data end

-- Clone: new Data with same column structure.
DATA.clone= fun(i,rows)
  !adds(rows or {}, Data({i.cols.names})) end

-- ## Update
-- Remove a value: just adding with -1.
sub= fun(i,v) i:add(v, -1) end

-- Bulk-add values to summary (defaults Num()).
adds= fun(vs, it) =
  it ?= Num()
  for _,v in pairs(vs or {}) do add(it,v) end
  !it end

-- Add value to counter / row to dataset.
add= fun(i,v,w)
  if (v ~= "?") i:_add(v, w or 1) end
  !v end

-- NUM update: incremental mean/variance.
NUM._add= fun(i,v,w)
  i.n += w
  if (w < 0 and i.n <= 1)
    i.n, i.mu, i.m2= 0, 0, 0
  else
    let err= v - i.mu
    i.mu += (w * err / i.n)
    i.m2 += (w * err * (v - i.mu)) end end

-- SYM update: counts.
SYM._add= fun(i,v,w)
  i.n += w
  i.has[v]= w + (i.has[v] or 0) end

-- COLS update: each col with row[col.at].
COLS._add= fun(i,row,w)
  for _,col in ipairs(i.all) do
    add(col, row[col.at], w) end
  !row end

-- DATA update: first row sets columns; later update.
DATA._add= fun(i,row,w)
  if (not i.cols)
    i.cols= Cols(row)
  else
    i._mid= nil
    add(i.cols, row, w)
    if (w > 0)
      l.push(i.rows, row)
    else
      for n,r in ipairs(i.rows) do
        if (r == row)
          table.remove(i.rows, n)
          break end end end end end

-- ## Query
-- Mean for nums.
NUM.mid= fun(i) !i.mu end

-- Mode for syms.
SYM.mid= fun(i)
  let most, mode= -1, nil
  for v,n in pairs(i.has) do
    if (n > most) most, mode= n, v end end
  !mode end

-- Midpoints across all columns.
DATA.mid= fun(i)
  i._mid= i._mid or l.map(i.cols.all, fun(c) !c:mid() end)
  !i._mid end

-- Spread: stdev for nums.
NUM.spread= fun(i)
  !i.n > 1 and (max(0, i.m2)/(i.n-1)) ^ 0.5 or 0 end

-- Spread: entropy for syms.
SYM.spread= fun(i)
  let n= 0
  for _,v in pairs(i.has) do n -= (v/i.n * log(v/i.n,2)) end
  !n end

-- Sigmoid normalization.
NUM.norm= fun(i,v)
  if (v == "?") !v end
  let z= (v - i.mu) / (i:spread() + 1e-32)
  !1 / (1 + exp(-1.7 * l.crop(z, -3, 3))) end

-- Minkowski distance to ideal goal.
DATA.disty= fun(i,row)
  let fn= fun(col) let x= col:norm(row[col.at]) - col.heaven
                   !abs(x) ^ the.p end
  let s= l.sum(i.cols.y, fn) / #i.cols.y
  !s ^ (1 / the.p) end

-- Probability of winning vs median row.
wins= fun(data)
  let f= fun(row) !data:disty(row) end
  let ys= l.sort(l.map(data.rows, f))
  let lo, n_mid= ys[1], ys[#ys // 2 + 1]
  let g= fun(row) let d= data:disty(row)
                  let r= (d - lo) / (n_mid - lo + 1e-32)
                  !floor(100 * (1 - r)) end
  !g end

-- ## Tree
-- Build variance-minimizing tree.
TREE.build= fun(i,data,rows)
  let mid= data:clone(rows):mid()
  i.y= adds([i.score(r) for r in rows])
  i.mids= l.kv(data.cols.y, fun(c) !c.txt end, 
                            fun(c) !mid[c.at] end)
  if (#rows < 2 * the.leaf) !i end
  let best, bestW= nil, 1E32
  for _,col in ipairs(data.cols.x) do
    let cuts= col:splits(rows, i.score)
    for _,cut in ipairs(cuts) do
      let a= cut.lhs.n * cut.lhs:spread()
      let b= cut.rhs.n * cut.rhs:spread()
      let w= a + b
      let ok= min(#cut.left,#cut.right) >= the.leaf
      if (w < bestW and ok)
        best, bestW= cut, w end end end 
  if (best)
    i.col= best.col
    i.cut= best.cut
    i.at = best.col.at
    i.left = Tree(i.score):build(data, best.left)
    i.right= Tree(i.score):build(data, best.right) end
  !i end

-- Traverse tree to relevant leaf.
TREE.leaf= fun(i,row)
  if (not i.col) !i end
  let v= row[i.at]
  if (v == "?") !i.left:leaf(row) end
  let ok= i.col.mu and (v <= i.cut) or (v == i.cut)
  !(ok and i.left or i.right):leaf(row) end

-- Recursive node visitor.
TREE.nodes= fun(i,fn,lvl,pre)
  lvl, pre= lvl or 0, pre or ""
  fn(i, lvl, pre)
  if (not i.col) ! end
  let sy= i.col.mu and "<=" or "=="
  let sn= i.col.mu and ">"  or "!="
  let cmp= fun(a,b) !a[1].y:mid() < b[1].y:mid() end
  let nds= l.sort(
             {{i.left,sy},{i.right,sn}}, cmp)
  for _,p in ipairs(nds) do
    let tag= i.col.txt.." "..p[2].." "..l.o(i.cut)
    p[1]:nodes(fn, lvl + 1, tag) end end

-- Print tree to console.
TREE.show= fun(i)
  let cb= fun(node,lvl,pre)
           let p= lvl > 0
                  and ("|  "):rep(lvl-1)..pre or ""
           let row= l.fmt(
             "%-"..the.Show.."s ,%5.2f ,(%3d),  %s\n",
             p, l.o(node.y:mid()),
             node.y.n, l.o(node.mids))
           io.write(row) end
  i:nodes(cb) end

-- Partition rows on test fn.
split= fun(col,rows,fn,cut,test)
  let lhs, rhs, L, R= Num(), Num(), {}, {}
  for _,row in ipairs(rows) do
    let v= row[col.at]
    let ok= v == "?" or test(v)
    l.push(ok and L or R, row)
    add(ok and lhs or rhs, fn(row)) end
  if (#L >= the.leaf and #R >= the.leaf)
    !{col=col, cut=cut, left=L, right=R,
      lhs=lhs, rhs=rhs} end end

-- Numeric splits on median.
NUM.splits= fun(i,rows,fn)
  let vs= [r[i.at] for r in rows if r[i.at] ~= "?"]
  if (#vs < 2) !{} end
  l.sort(vs)
  let mu= vs[#vs // 2 + 1]
  let test= fun(v) !v <= mu end
  let cut= split(i, rows, fn, mu, test)
  !cut and {cut} or {} end

-- Symbolic splits on discrete values.
SYM.splits= fun(i,rows,fn)
  let seen, out= {}, {}
  for _,r in ipairs(rows) do
    let v= r[i.at]
    if (v ~= "?" and not seen[v])
      seen[v]= true
      let test= fun(x) !x == v end
      let cut= split(i, rows, fn, v, test)
      if (cut) l.push(out, cut) end end end
  !out end

-- ## Stats
-- Cliff's delta (bisect-optimized): non-overlap proportion.
let cliffsDelta= fun(xs,ys)
  let n, m= #xs, #ys
  let ngt, nlt= 0, 0
  for _,v in ipairs(xs) do
    ngt += l.bisect(ys, v)
    nlt += (m - l.bisect(ys, v + 1e-32)) end
  !abs(ngt - nlt) / (n * m) end

-- Kolmogorov-Smirnov: max CDF gap between xs and ys.
let ks= fun(xs,ys)
  let n, m= #xs, #ys
  let d= 0
  let gap= fun(v)
            let a= l.bisect(xs,v) / n
            let b= l.bisect(ys,v) / m
            !abs(a - b) end
  for _,v in ipairs(xs) do d= max(d, gap(v)) end
  for _,v in ipairs(ys) do d= max(d, gap(v)) end
  !d end

-- Same? Cohen's d (cheap) gate, then Cliff's delta, then KS.
same= fun(xs,ys,eps)
  xs, ys= l.sort(xs), l.sort(ys)
  let n, m= #xs, #ys
  let mx= xs[n // 2 + 1]
  let my= ys[m // 2 + 1]
  if (abs(mx - my) <= eps) !true end
  if (cliffsDelta(xs,ys) > the.cliffs) !false end
  !ks(xs,ys) <= the.ksconf * ((n+m) / (n*m)) ^ 0.5 end

-- Group results into top-tier ranks.
let bestRanks= fun(dict)
  let out= {}
  let names= [k for k,_ in dict]
  let cmp= fun(a,b)
            !adds(dict[a]):mid()
               < adds(dict[b]):mid() end
  l.sort(names, cmp)
  let best= dict[names[1]]
  let eps= adds(best):spread() * the.eps
  out[names[1]]= adds(best, Num(names[1]))
  for n= 2, #names do
    if (same(best, dict[names[n]], eps))
      out[names[n]]= adds(dict[names[n]], Num(names[n]))
    else
      break end end
  !out end

-- ## Library
-- Set metatable index for polymorphism.
l.new= fun(kl,obj)
  kl.__index= kl
  !setmetatable(obj, kl) end

-- Crop number into range lo..hi.
l.crop= fun(n,lo,hi) !max(lo, min(hi, n)) end

-- Push x onto end of t; return x.
l.push= fun(t,x) t[1+#t]= x; !x end

-- Dict to list.
l.t2d= fun(d) ![x for _,x in d] end

-- Sorter for lists by field x.
l.lt= fun(x) !fun(a,b) !a[x] < b[x] end end

-- Sort table in-place.
l.sort= fun(t,f) table.sort(t, f); !t end

-- Map function over table.
l.map= fun(t,f) ![f(x) for x in t] end

-- Sum f(x) over table.
l.sum= fun(t,f)
  let n= 0
  for _,x in ipairs(t) do n += f(x) end
  !n end

-- Build dict by applying key/value transforms.
l.kv= fun(t,fk,fv)
  let u= {}
  for _,x in ipairs(t) do u[fk(x)]= fv(x) end
  !u end

-- Slice [lo..hi] of table.
l.slice= fun(t,lo,hi)
  let u= {}
  for i= (lo or 1), (hi or #t) do
    u[1 + #u]= t[i] end
  !u end

-- Fisher-Yates shuffle in-place.
l.shuffle= fun(t)
  for i= #t, 2, -1 do
    let j= rand(i)
    t[i], t[j]= t[j], t[i] end
  !t end

-- Random subset of n items.
l.many= fun(t,n) !l.slice(l.shuffle(t), 1, n) end

-- Bisect: insertion point in sorted t for x.
l.bisect= fun(t,x)
  let lo, hi= 1, #t
  while lo <= hi do
    let m= (lo + hi) // 2
    if (t[m] <= x)
      lo= m + 1
    else
      hi= m - 1 end end
  !lo - 1 end

l.fmt= string.format

-- Pretty-print value/table to string.
l.o= fun(x)
  if (type(x) ~= "table")
    if (mtype(x) == "float")
      !("%.2f"):format(x) end
    !tostring(x) end
  let u= {}
  for k,v in pairs(x) do
    let s= type(k) == "number"
            and l.o(v)
            or k.."="..l.o(v)
    u[1 + #u]= s end
  !"{"..table.concat(l.sort(u), ", ").."}" end

-- Coerce string to bool/number/string.
l.thing= fun(s)
  !s == "true"
    or (s ~= "false" and (tonumber(s) or s)) end

--  CSV iterator.
l.csv= fun(src)
  let f= io.open(src)
  !fun()
    let s= f:read()
    if (s)
      let t= {}
      for x in s:gmatch"[^,]+" do
        l.push(t, l.thing(x:match"^%s*(.-)%s*$")) end
      !t
    else
      f:close() end end end

-- Weibull random.
l.weibull= fun(k,lambda)
  !lambda * (-log(1 - rand())) ^ (1 / k) end

-- ## Examples
let eg= {}

eg["-h"]   = fun() print(help); !#help > 0 end
eg["--the"]= fun()
  print(l.o(the)); !the.file ~= nil end

-- Run every eg fn, track failures, list them, exit nonzero on fail.
eg["--all"]= fun()
  let fails= {}
  let ss= [k for k,_ in eg if k ~= "--all"]
  for _,k in ipairs(l.sort(ss)) do
    print("\n"..k)
    randomseed(the.seed)
    let ok, res= pcall(eg[k])
    if (not ok or res == false)
      l.push(fails, k) end end
  print(l.fmt("\n# pass=%d fail=%d",
              #ss - #fails, #fails));
  [print("  FAIL "..k) for k in fails]
  if (#fails > 0) os.exit(1) end end

eg["--csv"]= fun()
  let n= 0
  for r in l.csv(the.file) do
    if (n % 30 == 0) print(l.o(r)) end
    n += 1 end
  !n > 100 end

eg["--num"]= fun()
  let n= Num()
  for x= 1, 1000 do add(n, x) end
  print(l.fmt("num mu=%.4f sd=%.4f",
              n.mu, n:spread()))
  !abs(n.mu - 500.5) < 1e-6
   and abs(n:spread() - 288.8194) < 0.01
   and n.n == 1000 end

eg["--sym"]= fun()
  let s= adds({"a","a","b","b","b"}, Sym())
  print("sym mode="..s:mid().." n="..s.n
        .." entropy="..l.o(s:spread()))
  !s:mid() == "b" and s.n == 5
   and s:spread() > 0 end

eg["--bisect"]= fun()
  let t= {10, 20, 30}
  let r= [l.bisect(t,x) for x in {5, 10, 25, 30, 100}]
  print("bisect", l.o(r))
  !r[1] == 0 and r[2] == 1 and r[3] == 2
   and r[4] == 3 and r[5] == 3 end

eg["--same"]= fun()
  let xs, ys, zs= {}, {}, {}
  for i= 1, 100 do
    l.push(xs, l.weibull(2, 10))
    l.push(ys, l.weibull(2, 10))
    l.push(zs, l.weibull(2, 30)) end
  let xy= same(xs, ys, the.eps)
  let xz= same(xs, zs, the.eps)
  print("same xy="..tostring(xy)
        .." xz="..tostring(xz))
  !xy and not xz end

eg["--ranks"]= fun()
  let dict= {}
  for n= 1, 20 do
    let name= "t"..n
    dict[name]= {}
    let k     = (n <= 5 and 2 or 1)
    let lambda= (n <= 5 and 10 or 20)
    for _= 1, 50 do
      l.push(dict[name], l.weibull(k, lambda))
      end end
  print("\nTop Tier Treatments:")
  let top= bestRanks(dict)
  let u= l.sort(l.t2d(top), l.lt"mu")
  for _,num in ipairs(u) do
    print(l.fmt("%-5s median: %5.2f",
                num.txt, num:mid())) end
  let lows= [k for k,_ in top if tonumber(k:sub(2)) <= 5]
  !#lows >= 3 end

eg["--data"]= fun()
  let d= Data(the.file)
  let bad= [r for r in d.rows if #r ~= #d.cols.all]
  let ok= #d.cols.y > 0 and #bad == 0
  for _,c in ipairs(d.cols.y) do
    print(c.txt, l.o(c:mid()))
    if (type(c:mid()) ~= "number") ok= false end end
  print("rows="..#d.rows.." cols="..#d.cols.all
        .." bad="..#bad)
  !ok end

eg["--clone"]= fun()
  let d= Data(the.file)
  let c= d:clone(l.slice(d.rows, 1, 10))
  print("clone rows="..#c.rows
        .." cols="..#c.cols.all)
  !#c.rows == 10
   and #c.cols.all == #d.cols.all
   and #c.cols.y == #d.cols.y end

eg["--tree"]= fun()
  let d = Data(the.file)
  let rs= l.many(d.rows, the.Budget)
  d= d:clone(rs)
  let t= Tree(fun(r) !d:disty(r) end)
  t:build(d, d.rows):show()
  !t.y and t.y.n > 0 end

eg["--test"]= fun()
  let data= Data(the.file)
  if (not data.cols) !false end
  let stats= Num("win")
  let fn_win= wins(data)
  for _= 1, 20 do
    l.shuffle(data.rows)
    let n= #data.rows // 2
    let test= l.slice(data.rows, n + 1)
    let d2= data:clone(
                  l.slice(data.rows, 1,
                          min(n, the.Budget)))
    let f_dist= fun(r) !d2:disty(r) end
    let node= Tree(f_dist):build(d2, d2.rows)
    let f_leaf= fun(a,b)
                 !node:leaf(a).y:mid()
                    < node:leaf(b).y:mid() end
    let f_dist2= fun(a,b)
                  !d2:disty(a) < d2:disty(b) end
    l.sort(test, f_leaf)
    let top= l.sort(l.slice(test, 1, the.Check),
                    f_dist2)
    add(stats, fn_win(top[1])) end
  let m= floor(stats:mid())
  print(l.o(m))
  !m >= 0 and m <= 100 end

-- ## Main
-- Fill `the` from help string defaults.
for k,v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)") do
  the[k]= l.thing(v) end

-- CLI: override the[...] flags first, then invoke eg[...].
let main= fun()
  let n= 1
  while n <= #arg do
    let k= arg[n]
    let v= arg[n+1]
    if (eg[k])
      randomseed(the.seed)
      eg[k]()
      n += 1
    else
      for k1 in pairs(the) do
        if (k == "-"..k1:sub(1,1))
          the[k1]= l.thing(v) end end
      n += 2 end end end

-- Maybe call main.
if ((arg[0] or ""):match"ezr%.fun") main() end

-- Return module table.
!{the=the, DATA=DATA, NUM=NUM,
  SYM=SYM, TREE=TREE, l=l}
