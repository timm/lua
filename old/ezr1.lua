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
local new, push, sort, map, rat = l.new, l.push, l.sort, l.map, l.rat

local floor, max, min = math.floor, math.max, math.min
local abs, log, exp   = math.abs, math.log, math.exp
local rand, BIG      = math.random, 1E32

local NUM, SYM, COLS, DATA, TREE = {}, {}, {}, {}, {}
local Num, Sym, Data, Tree, Cols

-- structs ------------------------------------------------------------
function Tree(score)
  return new(TREE, {score=score}) end

function Sym(s, n)
  return new(SYM, {txt=s or "", at=n or 0, has={}, n=0}) end

function Num(s, n)
  return new(NUM, {txt=s or "", at=n or 0, n=0, mu=0, m2=0,
                   goal=s and s:match"-$" and 0 or 1}) end

function Cols(names,    x, y, all, col)
  x, y, all = {}, {}, {}
  for n, s in ipairs(names) do
    col = push(all, (s:match"^[A-Z]" and Num or Sym)(s, n))
    if not s:match"X$" then
      push(s:match"[%+%-!]$" and y or x, col) end end
  return new(COLS, {x=x, y=y, all=all, names=names}) end

function Data(src,     d)
  d = new(DATA, {rows={}, cols=nil, _mid=nil})
  if type(src)=="string" then for row in l.things(src) do add(d,row) end
  else for _, row in ipairs(src or {}) do add(d,row) end end
  return d end

function DATA.clone(self, rows)
  return adds(rows or {}, Data({self.cols.names})) end

-- update -------------------------------------------------------------
function add(self, v, w) if v~="?" then self:add(v, w or 1) end; return v end
function sub(self, v)   return self:add(v, -1) end

function NUM.add(self, v, w,    d)
  self.n = self.n + w
  if w < 0 and self.n <= 2 then self.n=0; self.mu=0; self.m2=0
  elseif self.n > 0 then
    d=v-self.mu; self.mu=self.mu+w*d/self.n; self.m2=self.m2+w*d*(v-self.mu) end end

function SYM.add(self, v, w)
  self.n = self.n + w; self.has[v] = (self.has[v] or 0) + w end

function COLS.add(self, row, w)
  for _, c in ipairs(self.all) do add(c, row[c.at], w) end; return row end

function DATA.add(self, row, w)
  if not self.cols then self.cols=Cols(row) else
    self._mid=nil; self.cols:add(row, w)
    if w>0 then push(self.rows, row) else
      for n, r in ipairs(self.rows) do
        if r==row then table.remove(self.rows, n); break end end end end end

-- query --------------------------------------------------------------
function NUM.mid(self)    return self.mu end
function SYM.mid(self,     most, mode)
  most = -1
  for v, n in pairs(self.has) do if n>most then most, mode=n, v end end
  return mode end
function DATA.mid(self)
  self._mid = self._mid or map(self.cols.all, function(c) return c:mid() end)
  return self._mid end

function NUM.spread(self)
  return self.n > 1 and (max(0, self.m2)/(self.n - 1))^0.5 or 0 end
function SYM.spread(self)
  return -l.sum(self.has,
              function(_, v) return (v/self.n) * log(v/self.n, 2) end) end

function NUM.norm(self, v,     sd)
  if v=="?" then return v end
  sd = self:spread() + 1e-32
  return 1/(1 + exp(-1.7*(v - self.mu)/sd)) end

function adds(lst,     c)
  c=c or Num(); for _, v in ipairs(lst or {}) do add(c, v) end; return c end

function mink(lst,     d, n)
  d, n=0, 0; for _, x in ipairs(lst) do n=n+1; d=d+abs(x)^the.p end
  return n==0 and 0 or (d/n)^(1/the.p) end

function DATA.disty(self, r,     fn)
  fn = function(c) return abs(c:norm(r[c.at]) - c.goal) end
  return mink(map(self.cols.y, fn)) end

function wins(d,     ds, lo, n_mid)
  ds = sort(map(d.rows, function(r) return d:disty(r) end))
  lo, n_mid = ds[1], ds[floor(#ds/2)+1]
  return function(r)
    return floor(100*(1 - ((d:disty(r)-lo) / (n_mid-lo+1e-32)))) end end

-- tree ---------------------------------------------------------------
function TREE.build(self, d, rows,     mid, best, bestW, w)
  mid = d:clone(rows):mid()
  self.y = adds(map(rows, function(r) return self.score(r) end))
  self.mids = l.kv(d.cols.y, function(c) return c.txt end,
                         function(c) return mid[c.at] end)
  if #rows < 2*the.leaf then return self end; best, bestW = nil, BIG
  for _, col in ipairs(d.cols.x) do
    for _, sp in ipairs(col:splits(rows, self.score)) do
      w = sp.lhs.n * sp.lhs:spread() + sp.rhs.n * sp.rhs:spread()
      if w < bestW and min(#sp.left, #sp.right) >= the.leaf then
        best = sp; bestW = w end end end
  if best then
    self.col, self.cut, self.at = best.col, best.cut, best.col.at
    self.left  = Tree(self.score):build(d, best.left)
    self.right = Tree(self.score):build(d, best.right)
  end; return self end

function NUM.leaf(self, cut, v) return v<=cut end

function SYM.leaf(self, cut, v) return v==cut end

function TREE.leaf(self, row,     v)
  if not self.col then return self end; v=row[self.at]
  if v=="?" then return self.left:leaf(row) end
  return (self.col:leaf(self.cut, v) and self.left or self.right):leaf(row) end

function TREE.nodes(self, fn, lvl, pre)
  lvl, pre = lvl or 0, pre or ""; fn(self, lvl, pre)
  if not self.col then return end; local yes, no = self.col:op()
  local kids = sort({{self.left, yes}, {self.right, no}},
                    function(a, b) return a[1].y:mid() < b[1].y:mid() end)
  for _, p in ipairs(kids) do
    p[1]:nodes(fn, lvl+1, self.col.txt.." "..p[2].." "..rat(self.cut)) end end

function SYM.op(self) return "==", "!=" end

function NUM.op(self) return "<=", ">"  end

function TREE.show(self)
  self:nodes(function(n, lvl, pre)
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
    return {col=col, cut=cut, left=L, right=R, lhs=lhs, rhs=rhs} end end

function NUM.splits(self, rows, score,     vals, n_med, sp)
  vals = {}
  for _, r in ipairs(rows) do
    if r[self.at]~="?" then push(vals, r[self.at]) end end
  if #vals<2 then return {} end
  sort(vals); n_med=vals[floor(#vals/2)+1]
  sp = split(self, rows, score, n_med, function(v) return v<=n_med end)
  return sp and {sp} or {} end

function SYM.splits(self, rows, score,     seen, out, sp)
  seen, out = {}, {}
  for _, row in ipairs(rows) do
    local v = row[self.at]
    if v~="?" and not seen[v] then seen[v]=true
      sp = split(self, rows, score, v, function(x) return x==v end)
      if sp then push(out, sp) end
    end end; return out end

-- stats --------------------------------------------------------------
local function same(xs, ys, eps,    n, m, gt, lt, ks, f)
  xs, ys = sort(xs), sort(ys); n, m = #xs, #ys
  if abs(xs[floor(n/2)+1] - ys[floor(m/2)+1]) <= eps then return true end
  gt, lt = 0, 0
  for _, a in ipairs(xs) do
    gt = gt + l.bisect(ys, a); lt = lt + (m - l.bisect(ys, a + 1e-32)) end
  if abs(gt - lt) / (n * m) > the.cliffs then return false end
  ks, f = 0, function(v) return abs(l.bisect(xs, v)/n - l.bisect(ys, v)/m) end
  for _, v in ipairs(xs) do ks = max(ks, f(v)) end
  for _, v in ipairs(ys) do ks = max(ks, f(v)) end
  return ks <= the.ksconf * ((n+m)/(n*m))^0.5 end

function bestRanks(dict,    items, k0, lst0, best)
  items = {}
  for name, lst in pairs(dict) do
    sort(lst); push(items, {name, lst, lst[floor(#lst/2)+1]}) end
  sort(items, function(a, b) return a[3] < b[3] end)
  k0, lst0 = items[1][1], items[1][2]
  best = {}; best[k0] = adds(lst0, Num(k0))
  for n = 2, #items do
    local k, lst = items[n][1], items[n][2]
    if same(lst0, lst, best[k0]:spread() * the.eps) then
      best[k] = adds(lst, Num(k))
    else break end end
  return best end

-- eg -----------------------------------------------------------------
local eg = {}

eg["-h"]= function (_) print(help) end

eg["--the"]= function (_) l.oo(the) end

eg["--all"] = function (arg,     a)
  a={}; for k in pairs(eg) do if k ~= "--all" then a[1+#a]=k end end
  for _, k in pairs(sort(a)) do 
    print("\n"..k)
    math.randomseed(the.seed)
    eg[k](arg) end end 

eg["--csv"] = function (f,     n)
  n=0; for row in l.things(f) do
    if n%30==0 then print(l.cat(map(row, rat))) end; n=n+1 end end

eg["--data"] = function (f,     d)
  d = Data(f)
  for _, c in ipairs(d.cols.y) do
    print(string.format("%s: n=%d mid=%s spread=%s",
          c.txt, c.n, rat(c:mid()), rat(c:spread()))) end end

eg["--tree"] = function (f,     d, sub)
  d = Data(f); sub = l.many(d.rows, the.Budget); d = d:clone(sub)
  Tree(function(r) return d:disty(r) end):build(d, d.rows):show() end

eg["--ranks"] = function (    dict)
  dict = {}
  for n = 1, 20 do
    local name = "t" .. n; dict[name] = {}
    local k, n_len = (n <= 5 and 2 or 1), (n <= 5 and 10 or 20)
    for _ = 1, 50 do push(dict[name], l.weibull(k, n_len)) end end
  print("\nTop Tier Treatments:")
  for k, num in pairs(bestRanks(dict)) do
    print(string.format("  %-5s median: %s", k, rat(num:mid()))) end end

eg["--test"] = function (f)
  local d, outs, win, n, test, d2, t, top
  d = Data(f); outs = Num("win"); win = wins(d)
  for _ = 1, 20 do
    l.shuffle(d.rows); n = #d.rows // 2
    test = l.slice(d.rows, n+1)
    d2 = d:clone(l.slice(d.rows, 1, min(n, the.Budget)))
    t = Tree(function(r) return d2:disty(r) end):build(d2, d2.rows)
    sort(test, function(a, b)
                  return t:leaf(a).y:mid() < t:leaf(b).y:mid() end)
    top = sort(l.slice(test, 1, the.Check),
               function(a, b) return d2:disty(a) < d2:disty(b) end)
    add(outs, win(top[1]))
  end
  print(rat(floor(outs:mid()))) end

-- main ---------------------------------------------------------------

local function main(     k, n, v)
  n = 1
  while n <= #arg do
    k, v = arg[n], arg[n+1]
    n = n + 1
    if eg[k] then
      math.randomseed(the.seed)
      eg[k](v and l.thing(v) or nil)
      if not eg[v] then n = n + 1 end
    else 
      for k1 in pairs(the) do
        if k == "-"..k1:sub(1, 1) then
          the[k1] = l.thing(v) end end end end end 

for k, v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)") do the[k] = l.thing(v) end
math.randomseed(the.seed)
if arg[0]:match("ezr1%.lua$") then main() end
