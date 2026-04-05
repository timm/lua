#!/usr/bin/env lua
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

local l = require"lib"
local new,push,sort = l.new,l.push,l.sort
local map,rat = l.map,l.rat

local floor,max,min = math.floor,math.max,math.min
local abs,log,exp = math.abs,math.log,math.exp
local rand,BIG = math.random, 1E32

local NUM, SYM, COLS, DATA, TREE = {}, {}, {}, {}, {}
local Num, Sym, Data, Tree, Cols

-- ## structs ---------------------------------------------------------
function Tree(fn_score)
  return new(TREE, {score=fn_score}) end

function Sym(s, n)
  return new(SYM, {txt=s or "", at=n or 0, has={}, n=0}) end

function Num(s, n)
  return new(NUM, {txt=s or "", at=n or 0, n=0, mu=0, m2=0,
                   goal=s and s:match"-$" and 0 or 1}) end

function Cols(ss_names,    xs,ys,all,col)
  xs, ys, all = {}, {}, {}
  for n, s in ipairs(ss_names) do
    col = push(all, (s:match"^[A-Z]" and Num or Sym)(s, n))
    if not s:match"X$" then
      push(s:match"[%+%-!]$" and ys or xs, col) end end
  return new(COLS, {x=xs, y=ys, all=all, names=ss_names}) end

function Data(src,    data)
  data = new(DATA, {rows={}, cols=nil, _mid=nil})
  if type(src)=="string" then for row in l.things(src) do add(data,row) end
  else for _, row in ipairs(src or {}) do add(data,row) end end
  return data end

function DATA.clone(i,rows)
  return adds(rows or {}, Data({i.cols.names})) end

-- ## update ----------------------------------------------------------
function add(i,v,w) if v~="?" then i:add(v,w or 1) end; return v end
function sub(i,v) return i:add(v,-1) end

function NUM.add(i,v,w,    err)
  i.n = i.n + w
  if w < 0 and i.n <= 2 then i.n, i.mu, i.m2 = 0, 0, 0
  elseif i.n > 0 then
    err=v-i.mu; i.mu=i.mu+w*err/i.n; i.m2=i.m2+w*err*(v-i.mu) end end

function SYM.add(i,v,w)
  i.n = i.n + w; i.has[v] = (i.has[v] or 0) + w end

function COLS.add(i,row,w)
  for _, col in ipairs(i.all) do add(col,row[col.at],w) end; return row end

function DATA.add(i,row,w)
  if not i.cols then i.cols=Cols(row) else
    i._mid=nil; i.cols:add(row,w)
    if w>0 then push(i.rows,row) else
      for n, r in ipairs(i.rows) do
        if r==row then table.remove(i.rows,n); break end end end end end

-- ## query -----------------------------------------------------------
function NUM.mid(i) return i.mu end
function SYM.mid(i,    most,mode)
  most = -1
  for v, n in pairs(i.has) do if n>most then most,mode=n,v end end
  return mode end
function DATA.mid(i)
  i._mid = i._mid or map(i.cols.all, function(col) return col:mid() end)
  return i._mid end

function NUM.spread(i)
  return i.n > 1 and (max(0,i.m2)/(i.n - 1))^0.5 or 0 end
function SYM.spread(i)
  return -l.sum(i.has, function(_, v) return (v/i.n) * log(v/i.n, 2) end) end

function NUM.norm(i,v,    sd)
  if v=="?" then return v end
  sd = i:spread() + 1e-32; return 1/(1 + exp(-1.7*(v - i.mu)/sd)) end

local function adds(vs,    num)
  num=num or Num(); for _, v in ipairs(vs or {}) do add(num,v) end; return num end

local function mink(vs,    err,n)
  err, n = 0, 0
  for _, x in ipairs(vs) do n=n+1; err=err+abs(x)^the.p end
  return n==0 and 0 or (err/n)^(1/the.p) end

function DATA.disty(i,row,    fn)
  fn = function(col) return abs(col:norm(row[col.at]) - col.goal) end
  return mink(map(i.cols.y, fn)) end

local function wins(data,    vs_errs,lo,n_mid)
  vs_errs = sort(map(data.rows, function(row) return data:disty(row) end))
  lo, n_mid = vs_errs[1], vs_errs[floor(#vs_errs/2)+1]
  return function(row)
    return floor(100*(1 - ((data:disty(row)-lo) / (n_mid-lo+1e-32)))) end end

-- ## tree ------------------------------------------------------------
function TREE.build(i,data,rows,    mid,best,bestW,w)
  mid, i.y = data:clone(rows):mid(), adds(map(rows, function(row) return i.score(row) end))
  i.mids = l.kv(data.cols.y, function(col) return col.txt end,
                             function(col) return mid[col.at] end)
  if #rows < 2*the.leaf then return i end; best, bestW = nil, BIG
  for _, col in ipairs(data.cols.x) do
    for _, cut in ipairs(col:splits(rows, i.score)) do
      w = cut.lhs.n * cut.lhs:spread() + cut.rhs.n * cut.rhs:spread()
      if w < bestW and min(#cut.left,#cut.right) >= the.leaf then
        best, bestW = cut, w end end end
  if best then
    i.col, i.cut, i.at = best.col, best.cut, best.col.at
    i.left, i.right = Tree(i.score):build(data, best.left), Tree(i.score):build(data, best.right)
  end; return i end

function NUM.leaf(i,cut,v) return v<=cut end
function SYM.leaf(i,cut,v) return v==cut end

function TREE.leaf(i,row,    v)
  if not i.col then return i end; v=row[i.at]
  if v=="?" then return i.left:leaf(row) end
  return (i.col:leaf(i.cut,v) and i.left or i.right):leaf(row) end

function TREE.nodes(i,fn,n_lvl,s_pre)
  n_lvl, s_pre = n_lvl or 0, s_pre or ""; fn(i, n_lvl, s_pre)
  if not i.col then return end; local s_yes, s_no = i.col:op()
  local nodes = sort({{i.left, s_yes}, {i.right, s_no}},
                    function(a, b) return a[1].y:mid() < b[1].y:mid() end)
  for _, p in ipairs(nodes) do
    p[1]:nodes(fn, n_lvl+1, i.col.txt.." "..p[2].." "..rat(i.cut)) end end

function SYM.op(i) return "==", "!=" end
function NUM.op(i) return "<=", ">"  end

function TREE.show(i)
  i:nodes(function(node, n_lvl, s_pre)
    local s = n_lvl > 0 and string.rep("|   ", n_lvl-1)..s_pre or ""
    io.write(string.format("%-"..the.Show.."s ,%4s ,(%3d),  %s\n",
      s, rat(node.y:mid()), node.y.n, rat(node.mids))) end) end

-- ## splits ----------------------------------------------------------
local function split(col,rows,fn_score,cut,fn_test,    lhs,rhs,L,R,ok)
  lhs, rhs, L, R = Num(), Num(), {}, {}
  for _, row in ipairs(rows) do
    ok = row[col.at]=="?" or fn_test(row[col.at])
    push(ok and L or R, row); add(ok and lhs or rhs, fn_score(row)) end
  if #L>=the.leaf and #R>=the.leaf then
    return {col=col,cut=cut,left=L,right=R,lhs=lhs,rhs=rhs} end end

function NUM.splits(i,rows,fn_score,    vs,n_med,cut)
  vs = {}
  for _, row in ipairs(rows) do if row[i.at]~="?" then push(vs,row[i.at]) end end
  if #vs<2 then return {} end
  sort(vs); n_med=vs[floor(#vs/2)+1]
  cut = split(i,rows,fn_score,n_med, function(v) return v<=n_med end)
  return cut and {cut} or {} end

function SYM.splits(i,rows,fn_score,    seen,outs,cut)
  seen, outs = {}, {}
  for _, row in ipairs(rows) do
    local v = row[i.at]
    if v~="?" and not seen[v] then
      seen[v], cut = true, split(i,rows,fn_score,v, function(x) return x==v end)
      if cut then push(outs, cut) end end end; return outs end

-- ## stats -----------------------------------------------------------
local function same(xs,ys,eps,    n,m,n_gt,n_lt,ks,fn)
  xs, ys = sort(xs), sort(ys); n, m = #xs, #ys
  if abs(xs[n//2+1] - ys[m//2+1]) <= eps then return true end
  n_gt, n_lt = 0, 0
  for _, v in ipairs(xs) do
    n_gt = n_gt + l.bisect(ys, v); n_lt = n_lt + (m - l.bisect(ys, v + 1e-32)) end
  if abs(n_gt - n_lt) / (n * m) > the.cliffs then return false end
  ks, fn = 0, function(v) return abs(l.bisect(xs,v)/n - l.bisect(ys,v)/m) end
  for _, v in ipairs(xs) do ks = max(ks, fn(v)) end
  for _, v in ipairs(ys) do ks = max(ks, fn(v)) end
  return ks <= the.ksconf * ((n+m)/(n*m))^0.5 end

function bestRanks(dict,    items,k0,vs0,best)
  items = {}
  for name, vs in pairs(dict) do
    sort(vs); push(items, {name, vs, vs[floor(#vs/2)+1]}) end
  sort(items, function(a,b) return a[3] < b[3] end)
  k0, vs0 = items[1][1], items[1][2]
  best = {}; best[k0] = adds(vs0, Num(k0))
  for n = 2, #items do
    local k, vs = items[n][1], items[n][2]
    if same(vs0, vs, best[k0]:spread() * the.eps) then best[k] = adds(vs, Num(k))
    else break end end
  return best end

-- ## eg --------------------------------------------------------------
local eg = {}
eg["-h"] = function (_) print(help) end
eg["--the"] = function (_) l.oo(the) end

eg["--all"] = function (arg,    ss)
  ss={}; for k in pairs(eg) do if k ~= "--all" then ss[#ss+1]=k end end
  for _, k in pairs(sort(ss)) do 
    print("\n"..k); math.randomseed(the.seed); eg[k](arg) end end 

eg["--csv"] = function (f,    n)
  n=0; for row in l.things(f) do
    if n%30==0 then print(l.cat(map(row,rat))) end; n=n+1 end end

eg["--data"] = function (f,    data)
  data = Data(f)
  for _, col in ipairs(data.cols.y) do
    print(string.format("%s: n=%d mid=%s spread=%s",
          col.txt, col.n, rat(col:mid()), rat(col:spread()))) end end

eg["--tree"] = function (f,    data,rows_sub)
  data = Data(f); rows_sub = l.many(data.rows, the.Budget); data = data:clone(rows_sub)
  Tree(function(row) return data:disty(row) end):build(data, data.rows):show() end

eg["--ranks"] = function (    dict,name,k,len)
  dict = {}
  for n = 1, 20 do
    name = "t" .. n; dict[name] = {}
    k, len = (n <= 5 and 2 or 1), (n <= 5 and 10 or 20)
    for _ = 1, 50 do push(dict[name], l.weibull(k, len)) end end
  print("\nTop Tier Treatments:")
  for k, num in pairs(bestRanks(dict)) do
    print(string.format("  %-5s median: %s", k, rat(num:mid()))) end end

eg["--test"] = function (f,    data,num_outs,fn_win,n,rows_test,data2,node,rows_top)
  data = Data(f); num_outs = Num("win"); fn_win = wins(data)
  for _ = 1, 20 do
    l.shuffle(data.rows); n = #data.rows // 2
    rows_test = l.slice(data.rows, n+1)
    data2 = data:clone(l.slice(data.rows, 1, min(n, the.Budget)))
    node = Tree(function(row) return data2:disty(row) end):build(data2, data2.rows)
    sort(rows_test, function(a,b) return node:leaf(a).y:mid() < node:leaf(b).y:mid() end)
    rows_top = sort(l.slice(rows_test, 1, the.Check),
                    function(a,b) return data2:disty(a) < data2:disty(b) end)
    add(num_outs, fn_win(rows_top[1])) end
  print(rat(floor(num_outs:mid()))) end

-- ## main ------------------------------------------------------------
local function main(    k,v,n)
  n=1
  while n <= #arg do
    k, v = arg[n], arg[n+1]; n = n + 1
    if eg[k] then math.randomseed(the.seed); eg[k](v and l.thing(v) or nil)
      if v and not eg[v] then n=n+1 end
    else 
      for k1 in pairs(the) do if k == "-"..k1:sub(1,1) then the[k1] = l.thing(v); n=n+1 end end
    end end end 

for k,v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)") do the[k] = l.thing(v) end
math.randomseed(the.seed)
if (arg[0] or ""):match("ezr.*%.lua$") then main() end
