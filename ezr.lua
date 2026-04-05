#!/usr/bin/env lua
-- <!-- vim: set et sw=2 tw=90 : -->
local the,help = {}, [[
ezr.lua : explainable multi-objective optimiization
(c) 2026, Tim Menzies <timm@ieee.org>, MIT license

  -B Budget=50     initial building budget
  -C Check=5       final check budget
  -c cliffs=0.195  Cliff's delta threshold
  -e eps=0.35      Cohen's threshold
  -k ksconf=1.36   KS test threshold
  -l leaf=3        min rows per tree leaf
  -p p=2           distance coeffecient
  -s seed=1        random number seed
  -S Show=30       width LHS tree displau
  -h               show help
]]

local lib = require"lib"
local new,push,sort        = lib.new,lib.push,lib.sort
local map,sum,kv           = lib.map,lib.sum,lib.kv
local slice,many,shuffle   = lib.slice,lib.many,lib.shuffle
local cat,trim,rat         = lib.cat,lib.trim,lib.rat
local thing,things,bisect  = lib.thing,lib.things,lib.bisect
local weibull              = lib.weibull

local floor,max,min = math.floor,math.max,math.min
local abs,log,exp   = math.abs,math.log,math.exp
local rand,BIG      = math.random, 1E32

local NUM, SYM, COLS, DATA, TREE = {}, {}, {}, {}, {}
local Num, Sym, Data, Tree, Cols

-- structs ------------------------------------------------------------
function Tree(score)
  return new(TREE, {score=score}) end

function Sym(s, at)
  return new(SYM, {txt=s or "", at=at or 0, has={}, n=0}) end

function Num(s, at)
  return new(NUM, {txt=s or "", at=at or 0, n=0, mu=0, m2=0,
                   goal=s and s:match"-$" and 0 or 1}) end

function Cols(names,    x, y, all, col)
  x, y, all = {}, {}, {}
  for at, s in ipairs(names) do
    col = push(all, (s:match"^[A-Z]" and Num or Sym)(s, at))
    if not s:match"X$" then
      push(s:match"[%+%-!]$" and y or x, col) end end
  return new(COLS, {x=x, y=y, all=all, names=names}) end

function Data(src,     d)
  d = new(DATA, {rows={}, cols=nil, _mid=nil})
  if type(src)=="string" then for row in things(src) do add(d,row) end
  else for _, row in ipairs(src or {}) do add(d,row) end end
  return d end

function DATA.clone(i,rows)
  return adds(rows or {}, Data({i.cols.names})) end

-- update -------------------------------------------------------------
function add(i,v,w) if v~="?" then i:add(v,w or 1) end; return v end
function sub(i,v)   return i:add(v,-1) end

function NUM.add(i,v,w,    d)
  i.n = i.n + w
  if w < 0 and i.n <= 2 then i.n=0; i.mu=0; i.m2=0
  elseif i.n > 0 then
    d=v-i.mu; i.mu=i.mu+w*d/i.n; i.m2=i.m2+w*d*(v-i.mu) end end

function SYM.add(i,v,w)
  i.n = i.n + w; i.has[v] = (i.has[v] or 0) + w end

function COLS.add(i,row,w)
  for _,c in ipairs(i.all) do add(c,row[c.at],w) end; return row end

function DATA.add(i,row,w)
  if not i.cols then i.cols=Cols(row) else
    i._mid=nil; i.cols:add(row,w)
    if w>0 then push(i.rows,row) else
      for j,r in ipairs(i.rows) do
        if r==row then table.remove(i.rows,j); break end end end end end

-- query --------------------------------------------------------------
function NUM.mid(i)    return i.mu end
function SYM.mid(i,     most,mode)
  most = -1
  for v,n in pairs(i.has) do if n>most then most,mode=n,v end end
  return mode end
function DATA.mid(i)
  i._mid = i._mid or map(i.cols.all, function(c) return c:mid() end)
  return i._mid end

function NUM.spread(i)
  return i.n > 1 and (max(0,i.m2)/(i.n - 1))^0.5 or 0 end
function SYM.spread(i)
  return -sum(i.has,
              function(_, v) return (v/i.n) * log(v/i.n, 2) end) end

function NUM.norm(i,v,     sd)
  if v=="?" then return v end
  sd = i:spread() + 1e-32
  return 1/(1 + exp(-1.7*(v - i.mu)/sd)) end

function adds(lst,     c)
  c=c or Num(); for _,v in ipairs(lst or {}) do add(c,v) end; return c end

function mink(lst,     d,n)
  d,n=0,0; for _,x in ipairs(lst) do n=n+1; d=d+abs(x)^the.p end
  return n==0 and 0 or (d/n)^(1/the.p) end

function DATA.disty(i,r,     fn)
  fn = function(c) return abs(c:norm(r[c.at]) - c.goal) end
  return mink(map(i.cols.y, fn)) end

function wins(d,     ds, lo, med)
  ds = sort(map(d.rows, function(r) return d:disty(r) end))
  lo, med = ds[1], ds[floor(#ds/2)+1]
  return function(r)
    return floor(100*(1 - ((d:disty(r)-lo) / (med-lo+1e-32)))) end end

-- tree ---------------------------------------------------------------
function TREE.build(i, d, rows,     mid, best, bestW, w)
  mid = d:clone(rows):mid()
  i.y = adds(map(rows, function(r) return i.score(r) end))
  i.mids = kv(d.cols.y, function(c) return c.txt end,
                         function(c) return mid[c.at] end)
  if #rows < 2*the.leaf then return i end; best, bestW = nil, BIG
  for _, col in ipairs(d.cols.x) do
    for _, sp in ipairs(col:splits(rows, i.score)) do
      w = sp.lhs.n * sp.lhs:spread() + sp.rhs.n * sp.rhs:spread()
      if w < bestW and min(#sp.left,#sp.right) >= the.leaf then
        best = sp; bestW = w end end end
  if best then
    i.col, i.cut, i.at = best.col, best.cut, best.col.at
    i.left  = Tree(i.score):build(d, best.left)
    i.right = Tree(i.score):build(d, best.right)
  end; return i end

function NUM.leaf(i,cut,v) return v<=cut end

function SYM.leaf(i,cut,v) return v==cut end

function TREE.leaf(i,row,     v)
  if not i.col then return i end; v=row[i.at]
  if v=="?" then return i.left:leaf(row) end
  return (i.col:leaf(i.cut,v) and i.left or i.right):leaf(row) end

function TREE.nodes(i, fn, lvl, pre)
  lvl, pre = lvl or 0, pre or ""; fn(i, lvl, pre)
  if not i.col then return end; local yes, no = i.col:op()
  local kids = sort({{i.left, yes}, {i.right, no}},
                    function(a, b) return a[1].y:mid() < b[1].y:mid() end)
  for _, p in ipairs(kids) do
    p[1]:nodes(fn, lvl+1, i.col.txt.." "..p[2].." "..rat(i.cut)) end end

function SYM.op(i) return "==", "!=" end

function NUM.op(i) return "<=", ">"  end

function TREE.show(i)
  i:nodes(function(n, lvl, pre)
    local s = lvl > 0 and string.rep("|   ", lvl-1)..pre or ""
    io.write(string.format("%-"..the.Show.."s ,%4s ,(%3d),  %s\n",
      s, rat(n.y:mid()), n.y.n, rat(n.mids))) end) end

-- splits -------------------------------------------------------------
local function split(col, rows, score, cut, test,
                     lhs, rhs, L, R, go)
  lhs, rhs, L, R = Num(), Num(), {}, {}
  for _, r in ipairs(rows) do
    go = r[col.at]=="?" or test(r[col.at])
    push(go and L or R, r); add(go and lhs or rhs, score(r))
  end
  if #L>=the.leaf and #R>=the.leaf then
    return {col=col,cut=cut,left=L,right=R,lhs=lhs,rhs=rhs} end end

function NUM.splits(i, rows, score,     vals, med, sp)
  vals = {}
  for _,r in ipairs(rows) do
    if r[i.at]~="?" then push(vals,r[i.at]) end end
  if #vals<2 then return {} end
  sort(vals); med=vals[floor(#vals/2)+1]
  sp = split(i,rows,score,med, function(v) return v<=med end)
  return sp and {sp} or {} end

function SYM.splits(i, rows, score,     seen, out, sp)
  seen, out = {}, {}
  for _, row in ipairs(rows) do
    local v = row[i.at]
    if v~="?" and not seen[v] then seen[v]=true
      sp = split(i,rows,score,v, function(x) return x==v end)
      if sp then push(out, sp) end
    end end; return out end

-- stats --------------------------------------------------------------
local function same(xs, ys, eps,    n, m, gt, lt, ks, f)
  xs, ys = sort(xs), sort(ys); n, m = #xs, #ys
  if abs(xs[n//2+1] - ys[m//2+1]) <= eps then return true end
  gt, lt = 0, 0
  for _, a in ipairs(xs) do
    gt = gt + bisect(ys, a); lt = lt + (m - bisect(ys, a + 1e-32)) end
  if abs(gt - lt) / (n * m) > the.cliffs then return false end
  ks, f = 0, function(v) return abs(bisect(xs,v)/n - bisect(ys,v)/m) end
  for _, v in ipairs(xs) do ks = max(ks, f(v)) end
  for _, v in ipairs(ys) do ks = max(ks, f(v)) end
  return ks <= the.ksconf * ((n+m)/(n*m))^0.5 end

function bestRanks(dict,    items, k0, lst0, best)
  items = {}
  for name, lst in pairs(dict) do
    sort(lst); push(items, {name, lst, lst[floor(#lst/2)+1]}) end
  sort(items, function(a,b) return a[3] < b[3] end)
  k0, lst0 = items[1][1], items[1][2]
  best = {}; best[k0] = adds(lst0, Num(k0))
  for j = 2, #items do
    local k, lst = items[j][1], items[j][2]
    if same(lst0, lst, best[k0]:spread() * the.eps) then
      best[k] = adds(lst, Num(k))
    else break end end
  return best end

-- eg -----------------------------------------------------------------
local eg = {}

eg["-h"]= function (_) print(help) end

eg["--the"]= function (_) lib.oo(the) end

eg["--all"] = function (arg,     a)
  a={}; for k in pairs(eg) do if k ~= "--all" then a[1+#a]=k end end
  for _,k in pairs(sort(a)) do 
    print("\n"..k)
    math.randomseed(the.seed)
    eg[k](arg) end end 

eg["--csv"] = function (f,     n)
  n=0; for row in things(f) do
    if n%30==0 then print(cat(map(row,rat))) end; n=n+1 end end

eg["--data"] = function (f,     d)
  d = Data(f)
  for _, c in ipairs(d.cols.y) do
    print(string.format("%s: n=%d mid=%s spread=%s",
          c.txt, c.n, rat(c:mid()), rat(c:spread()))) end end

eg["--tree"] = function (f,     d, sub)
  d = Data(f); sub = many(d.rows, the.Budget); d = d:clone(sub)
  Tree(function(r) return d:disty(r) end):build(d, d.rows):show() end

eg["--ranks"] = function (    dict)
  dict = {}
  for i = 1, 20 do
    local name = "t" .. i; dict[name] = {}
    local k, l = (i <= 5 and 2 or 1), (i <= 5 and 10 or 20)
    for _ = 1, 50 do push(dict[name], weibull(k, l)) end end
  print("\nTop Tier Treatments:")
  for k, num in pairs(bestRanks(dict)) do
    print(string.format("  %-5s median: %s", k, rat(num:mid()))) end end

eg["--test"] = function (f)
  local d, outs, win, n, test, d2, t, top
  d = Data(f); outs = Num("win"); win = wins(d)
  for _ = 1, 20 do
    shuffle(d.rows); n = #d.rows // 2
    test = slice(d.rows, n+1)
    d2 = d:clone(slice(d.rows, 1, min(n, the.Budget)))
    t = Tree(function(r) return d2:disty(r) end):build(d2, d2.rows)
    sort(test, function(a,b)
                  return t:leaf(a).y:mid() < t:leaf(b).y:mid() end)
    top = sort(slice(test, 1, the.Check),
               function(a,b) return d2:disty(a) < d2:disty(b) end)
    add(outs, win(top[1]))
  end
  print(rat(floor(outs:mid()))) end

-- main ---------------------------------------------------------------

local function main(     k,i,v)
  i=1
  while i <= #arg do
    k,v = arg[i], arg[i+1]
    i = i + 1
    if eg[k] then
      math.randomseed(the.seed)
      eg[k](v and thing(v) or nil)
      if not eg[v] then i=i+1 end
    else 
      for k1 in pairs(the) do
        if k == "-"..k1:sub(1,1) then
          the[k1] = thing(v) end end end end end 

for k,v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)") do the[k] = thing(v) end
math.randomseed(the.seed)
if arg[0]:match("ezr%.lua$") then main() end
