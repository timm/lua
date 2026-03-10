#!/usr/bin/env lua
-- tree.lua: decision tree for multi-objective optimization
-- (c) 2026 Tim Menzies timm@ieee.org, MIT license
-- vim: set et sw=2 tw=90 :

the = {
  leaf   = 3, 
  Budget = 50, 
  Check  = 5, 
  Show   = 30, 
  seed   = 1, 
  p      = 2,
  -- Cliff's Delta: small=0.147, medium=0.33, large=0.474 (mid=0.24)
  cliffs = 0.195, 
  -- K-S Confidence: 90%=1.22, 95%=1.36, 99%=1.63
  conf   = 1.36,  
  -- Small Effect (Cohen's d): small=0.2, medium=0.5, large=0.8
  eps    = 0.35   
}

local floor,max,min,abs,log = math.floor,math.max,math.min,math.abs,math.log
local rand,BIG = math.random, 1E32

local NUM, SYM, COLS, DATA, TREE = {}, {}, {}, {}, {}
local Num, Sym, Data, Tree, Cols

local new,push,sort,map,sum,median,trim,cat,rat,thing,things,shuffle,adds,mink,bisect

-- structs ------------------------------------------------------------------------------
function Tree(score) return new(TREE, {score=score}) end
function Sym(s, at)  return new(SYM, {txt=s or "", at=at or 0, has={}, most=0, n=0}) end
function Num(s, at)  return new(NUM, {txt=s or "", at=at or 0, has={}, _ok=false, n=0,
                                     goal=s and s:match"-$" and 0 or 1}) end

function Cols(names,    x, y, all, col)
  x, y, all = {}, {}, {}
  for at, s in ipairs(names) do
    col = push(all, (s:match"^[A-Z]" and Num or Sym)(s, at))
    if not s:match"X$" then push(s:match"[%+%-!]$" and y or x, col) end end
  return new(COLS, {x=x, y=y, all=all, names=names}) end

function Data(src,     d) 
  d = new(DATA, {rows={}, cols=nil}) 
  if type(src)=="string" then for row in things(src) do d:add(row) end 
  else for _, row in ipairs(src or {}) do d:add(row) end end
  return d end 

function DATA.clone(i,rows) return adds(rows or {}, Data({i.cols.names})) end

-- update ------------------------------------------------------------------------------
function NUM.add(i,v) 
  if v~="?" then i.n=i.n+1; push(i.has,v); i._ok=false end; return v end
function SYM.add(i,v)
  if v~="?" then i.n=i.n+1; i.has[v]=(i.has[v] or 0)+1
    if i.has[v]>i.most then i.most,i.mode=i.has[v],v end end; return v end
function COLS.add(i,row) 
  for _,c in ipairs(i.all) do c:add(row[c.at]) end; return row end
function DATA.add(i,row)
  if i.cols then i.cols:add(push(i.rows,row)) else i.cols=Cols(row) end end

-- query ------------------------------------------------------------------------------
function NUM.ok(i)   if not i._ok then sort(i.has) end; i._ok=true; return i end
function NUM.mid(i)  return median(i:ok().has) end
function SYM.mid(i)  return i.mode end
function DATA.mid(i) return map(i.cols.all, function(c) return c:mid() end) end

function NUM.spread(i,     t, n)
  t, n = i:ok().has, #i.has; if n < 2 then return 0 end
  return (t[max(1, floor(.9*n))] - t[max(1, floor(.1*n))]) / 2.56 end
function SYM.spread(i)
  return -sum(i.has, function(_, v) return (v/i.n) * log(v/i.n, 2) end) end

function NUM.norm(i,v)
  if v=="?" then return v end; if #i:ok().has<2 then return 0 end
  return max(0, min(1, (v-i.has[1]) / (i.has[#i.has]-i.has[1]))) end

function DATA.disty(i,r,     fn)
  fn = function(c) return abs(c:norm(r[c.at]) - c.goal) end
  return mink(map(i.cols.y, fn)) end

-- tree ---------------------------------------------------------------------------------
function TREE.build(i, d, rows,     mid, best, bestW, w)
  mid = d:clone(rows):mid(); i.mids = {}
  i.y = adds(map(rows, function(r) return i.score(r) end))
  for _, c in ipairs(d.cols.y) do i.mids[c.txt] = mid[c.at] end
  if #rows < 2*the.leaf then return i end; best, bestW = nil, BIG
  for _, col in ipairs(d.cols.x) do
    for _, sp in ipairs(col:splits(rows)) do
      w = sum({sp.left, sp.right}, function(_, s)
            return adds(map(s, function(r) return i.score(r) end)):spread() * #s end)
      if w < bestW then best = {col=col, cut=sp.cut, left=sp.left, 
                                right=sp.right}; bestW = w end end end
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

-- splits -------------------------------------------------------------------------------
local function step(rows, at, fn,     left, right)
  left, right = {}, {}
  for _, r in ipairs(rows) do
    if r[at]~="?" then push(fn(r[at]) and left or right, r) end end
  if #left>=the.leaf and #right>=the.leaf then return left, right end end

function NUM.splits(i, rows,     vals, med, l, r)
  vals = {}; for _, r in ipairs(rows) do if r[i.at]~="?" then push(vals, r[i.at]) end end
  if #vals < 2 then return {} end; sort(vals); med = vals[floor(#vals/2)+1]
  l, r = step(rows, i.at, function(v) return v <= med end)
  return l and {{cut=med, left=l, right=r}} or {} end

function SYM.splits(i, rows,     seen, out, l, r)
  seen, out = {}, {}
  for _, row in ipairs(rows) do
    local v = row[i.at]
    if v~="?" and not seen[v] then seen[v]=true
      l, r = step(rows, i.at, function(x) return x == v end)
      if l then push(out, {cut=v, left=l, right=r}) end end end; return out end

-- lib ----------------------------------------------------------------------------------
function new(kl,obj)     kl.__index=kl; return setmetatable(obj,kl) end
function push(t,x)       t[#t+1]=x; return x end
function sort(t,fn)      table.sort(t,fn); return t end
function map(t,f,     u) u={}; for i,x in ipairs(t) do u[i]=f(x) end; return u end
function sum(t,f,     n) n=0; for k,v in pairs(t) do n=n+f(k,v) end; return n end
function median(t)       return t[floor(#t/2)+1] or 0 end
function trim(s)         return s:match"^%s*(.-)%s*$" end
function cat(t)          return "{"..table.concat(t,", ").."}" end

function rat(x,     u)
  if math.type(x)=="float" then return string.format("%.2f",x) end
  if type(x)~="table"      then return tostring(x) end
  if #x>0                  then return cat(map(x,rat)) end
  u={}; for k,v in pairs(x) do u[#u+1]=k.."="..rat(v) end
  return cat(sort(u)) end

function thing(s)
  return s=="true" or (s~="false" and (math.tointeger(s) or tonumber(s) or s)) end

function things(file,     src)
  src=assert(io.open(file))
  return function(     s,t)
    s=src:read(); if s then
      t={}; for x in s:gmatch("[^,]+") do push(t,thing(trim(x))) end; return t end end end

function shuffle(t,     j)
  for i=#t,2,-1 do j=rand(i); t[i],t[j]=t[j],t[i] end; return t end

function adds(lst,     c) 
  c=c or Num(); for _,v in ipairs(lst or {}) do c:add(v) end; return c end

function mink(lst,     d,n)
  d,n=0,0; for _,x in ipairs(lst) do n=n+1; d=d+abs(x)^the.p end
  return n==0 and 0 or (d/n)^(1/the.p) end

function bisect(t, x,    lo, hi, mid)
  lo, hi = 1, #t
  while lo <= hi do
    mid = (lo + hi) // 2
    if t[mid] <= x then lo = mid + 1 else hi = mid - 1 end end
  return lo - 1 end

local function weibull(k, lambda)
  return lambda * (-log(1 - rand()))^(1/k) end

-- stats --------------------------------------------------------------------------------
local function same(x, y, eps,    n, m, xs, ys, _cliffs, _ks)
  x:ok(); y:ok(); xs, ys = x.has, y.has; n, m = #xs, #ys
  -- Fast-fail: if medians are closer than eps * overall_spread
  if abs(xs[n//2+1] - ys[m//2+1]) <= eps then return true end
  _cliffs = function(    gt, lt)
    gt, lt = 0, 0
    for _, a in ipairs(xs) do
      gt, lt = gt + bisect(ys, a - 1e-9), lt + (m - bisect(ys, a)) end
    return abs(gt - lt) / (n * m) end
  _ks = function(    d, f)
    d, f = 0, function(v) return abs(bisect(xs,v)/n - bisect(ys,v)/m) end
    for _, v in ipairs(xs) do d = max(d, f(v)) end
    for _, v in ipairs(ys) do d = max(d, f(v)) end
    return d end
  return _cliffs() <= the.cliffs and _ks() <= the.conf * ((n+m)/(n*m))^0.5 end

function bestRanks(dict,    all, num_all, best)
  all, num_all = {}, Num("overall")
  for name, lst in pairs(dict) do
    adds(adds(lst, push(all, Num(name))).has, num_all) end
  sort(all, function(a, b) return a:mid() < b:mid() end)
  best = {all[1]}
  for j = 2, #all do
    if same(all[1], all[j], num_all:spread() * the.eps) then push(best, all[j])
    else break end end
  return best end

-- eg -----------------------------------------------------------------------------------
eg = {}
function eg.data(f,     d, rows, sub)
  d = Data(); for row in things(f) do d:add(row) end
  rows = shuffle(d.rows); sub = {}
  for i=1, min(the.Budget, #rows) do push(sub, rows[i]) end; d = d:clone(sub)
  Tree(function(r) return d:disty(r) end):build(d, d.rows):show() end

function eg.ranks(    dict)
  dict = {}
  for i = 1, 20 do
    local name = "t" .. i; dict[name] = {}
    -- Treatment 1-5 are "best" (k=2, lambda=10)
    -- Treatment 6-20 are "worse" (k=1, lambda=20)
    local k, l = (i <= 5 and 2 or 1), (i <= 5 and 10 or 20)
    for _ = 1, 50 do push(dict[name], weibull(k, l)) end end
  
  local winners = bestRanks(dict)
  print("\nTop Tier Treatments:")
  for _, num in ipairs(winners) do
    print(string.format("  %-5s median: %s", num.txt, rat(num:mid()))) end end

-- main ---------------------------------------------------------------------------------
local function main(     k, i)
  i = 1; while i <= #arg do
    k = arg[i]:match"^%-%-?(.+)"; i = i + 1
    if k then
      math.randomseed(the.seed) 
      if eg[k] then eg[k](arg[i]); i = i + 1
      elseif the[k]~=nil then the[k] = thing(arg[i]); i = i + 1 end end end end

math.randomseed(the.seed) 
if arg[0]:match("tree%.lua$") then main() end
