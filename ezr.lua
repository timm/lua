#!/usr/bin/env lua
local help = [[
ezr.lua: multi-goal trees, XAI, active learning, optimization.
(c) 2026 Tim Menzies <timm@ieee.org>, MIT license.

One file: the batteries, then the learners. A holdout score
rig, and the stats that police it. Demos live next door in
ezr-eg.lua. For LuaJIT, or any Lua from 5.1 up.

usage:
  ezr [-h] [--key=val ..] [--demo ..]

or, adding demos from your own script:
  local ezr = require"ezr-eg"
  ezr.eg["--myDemo"] = function() print(ezr.the.seed) end
  ezr.go(ezr.eg)

options:
  round=2          decimals printed by show
  seed=1234567891  every random stream starts here
  DATA=./          bare table names live here
  file=auto93.csv  default table
  budget=50        acquire: max labels
  cap=1024         holdout: max rows kept
  check=5          holdout: test rows labelled
  few=128          sample size for cheap guesses
  keepf=0.66       acquire: pool kept per cull
  leaf=3           tree: min rows in one leaf
  maxd=4           tree: max depth
  more=4           acquire: labels per round
  p=2              minkowski coefficient
  stop=32          min rows before a split halts]]

local abs,exp,log,sqrt = math.abs,math.exp,math.log,math.sqrt
local max,min,floor    = math.max,math.min,math.floor
local huge             = math.huge
local TINY             = 1e-32
local UP               = string.char(0xE2,0x96,0xB2) -- U+25B2
local DOWN             = string.char(0xE2,0x96,0xBC) -- U+25BC

-- THIS file's dir (not the caller's), where the csvs live
local SRC = debug.getinfo(1,"S").source:match"^@(.*/)" or "./"

local _ENV = setmetatable({}, {__index = _G})
if setfenv then setfenv(1, _ENV) end

NUM, SYM, COLS, TBL, NODE, TREE = {},{},{},{},{},{}

--## make and feed ---------------------------------------------

function new(kl,t) -- class table is also its metatable
  kl.__index=kl;kl.__tostring=show; return setmetatable(t,kl) end

function iter(src,    at) -- loop a list or a generator alike
  if type(src) == "function" then return src end
  at = 0; return function() at = at + 1; return src[at] end end

function thing(s) -- one cell of text -> number, bool, or string
  s = s:match"^%s*(.-)%s*$"
  return tonumber(s) or s=="True" or (s~="False" and s) end

function pathname(s,    d) -- a bare name hangs off the.DATA,
  s = s or the.file        -- and a relative the.DATA off SRC.
  if not s:find"/" then    -- $VARS expand; $MOOT has a default
    d = the.DATA
    s = (d:find"^[/$]" and "" or SRC) .. d .. s end
  return (s:gsub("%$(%w+)", function(k)
    return os.getenv(k) or k == "MOOT" and
           os.getenv"HOME" .. "/gits/moot" end)) end

function csv(file,    f) -- stream rows of cells; nil ends it
  f = io.lines(pathname(file))
  return function(    t,l)
    for line in f do
      l = line:gsub("\239\187\191","")   -- strip any BOM
              :gsub("%%.*",""):match"^%s*(.-)%s*$"
      if l ~= "" then
        t={}                        -- (.-), keeps empty cells
        for s in (l..","):gmatch"(.-)," do t[#t+1]=thing(s) end
        return t end end end end

--## settings --------------------------------------------------
-- One flat table of options, parsed out of the help that
-- documents them, so manual and defaults cannot drift apart.

Help = help -- the usage text; `cli` prints it for -h

function options(s,    t) -- the `k=v` words in s, only the ones
  t = {}                  -- after whitespace, so `--k=v` in the
  for k,v in (" "..s):gmatch"%s(%a%w*)=(%S+)" do -- usage stays
    t[k] = thing(v) end                          -- prose
  return t end

function also(t,s) -- merge another file's options; clashes crash
  Help = s.."\n"..(Help:match"[^\n]*[Oo]ptions:.*" or "")
  for k,v in pairs(options(s)) do
    assert(t[k] == nil, "duplicate setting: "..k)
    t[k] = v end
  return t end

--## list making -----------------------------------------------
-- `fun` is why these are short: any of them takes a function,
-- a method name, or a field index.

function push(t,v) t[1+#t] = v; return v end -- returns v, so
                                             -- pushes chain
function fun(f) -- a callable: f, or a method name, or an index
  if type(f)=="string" then
    return function(v,...) return v[f](v,...) end end
  if type(f)=="number" then return function(v) return v[f]end end
  return f end

function map(t,f,    u) -- f over a list, into a new list
  f = fun(f)
  u = {}; for _,v in ipairs(t) do u[1+#u]=f(v) end; return u end

function kap(t,f,    u) -- f(k,v) over all pairs, any order;
  u = {}                -- a nil result vanishes, so kap filters
  for k,v in pairs(t) do u[1+#u] = f(k,v) end; return u end

function slice(t,lo,hi,    u) -- copy t[lo..hi]; any bound
  u, hi = {}, min(hi or #t, #t)
  for j = max(lo or 1, 1), hi do u[1+#u] = t[j] end
  return u end

function copy(t) -- shallow copy of the list part
  return map(t, function(v) return v end) end

function sum(t,f,    n) -- add f(v) over the values
  n = 0; for _, v in pairs(t) do n = n + f(v) end; return n end

--## ordering --------------------------------------------------
-- Stable, so two runs on one seed print the same lines.

function sorted(t,f,    s) -- sorted copy; comparator optional
  s = copy(t); table.sort(s, f); return s end

function median(t,    s) -- the upper middle of unsorted t
  s = sorted(t); return s[floor(#s / 2) + 1] end

function keysort(t,f,    px,ix) -- sort by f(v); ties keep order
  px, ix = {}, {}
  for at, v in ipairs(t) do px[v], ix[v] = f(v), at end
  return sorted(t, function(u,v)
           if px[u] == px[v] then return ix[u] < ix[v] end
           return px[u] < px[v] end) end

function keys(t,    u) -- the keys, sorted
  u = kap(t, function(k) return k end)
  return keysort(u, tostring) end

function least(    lo) -- min-so-far: f{val,..} offers, f() reads
  return function(x)   -- the winner rides in the closure, so no
    if x and (lo == nil or x[1] < lo[1]) then lo = x end
    return lo end end  -- candidate list is ever built

--## randomness ------------------------------------------------
-- Own Park-Miller PRNG: one seed, one stream, any Lua. The
-- built-in math.random differs on 5.1, 5.4 and LuaJIT, so a
-- shared seed there would still fork the stream.

Seed = 1234567891 -- state of the one generator in this system

function srand(n) -- reseed with any int; lands in 1..2^31-2
  Seed = floor(n or 1234567891) % 2147483647
  if Seed <= 0 then Seed = Seed + 2147483646 end end

function rand(lo,hi,    x) -- no args: float in [0,1). n: int
  Seed = (16807 * Seed) % 2147483647     -- in 1..n. lo,hi: int
  x = Seed / 2147483647                  -- in lo..hi
  if not lo then return x end
  if not hi then lo, hi = 1, lo end
  return lo + floor(x * (hi - lo + 1)) end

function shuffle(lst,    t,j) -- Fisher-Yates; input survives
  t = copy(lst)
  for at = #t, 2, -1 do
    j = rand(at); t[at],t[j] = t[j],t[at] end
  return t end

function some(lst,k,    t) -- k at random, or all if k is too big
  t = shuffle(lst)
  for at = #t, min(k, #t) + 1, -1 do t[at] = nil end
  return t end

--## rendering -------------------------------------------------
-- One number format, one table format, so a transcript is a
-- test across Lua versions.

function round(v,n) -- to n (default the.round) places; 5.3+
  if v % 1 == 0 then return floor(v) end -- prints 15.0 as
  n = 10 ^ (n or the.round)               -- "15.0", 5.1 as "15"
  v = floor(v * n + 0.5) / n
  return v % 1 == 0 and floor(v) or v end

function show(t,    u) -- render anything; lists keyless, dicts
  if type(t) ~= "table" then            -- as sorted ":k v" pairs
    return tostring(type(t) == "number" and round(t) or t) end
  u = #t > 0 and map(t, show) or
      sorted(kap(t, function(k,v)
        return ":"..k.." "..show(v) end))
  return "{"..table.concat(u, " ").."}" end

--## start-up --------------------------------------------------
-- `go` is the only entry a file needs. It stays silent unless
-- that file is the script the user ran, so `require` never
-- fires a demo.

function cli(d,    v) -- --key=val updates; -h prints the help.
  for _, s in ipairs(arg) do    -- a new value keeps the old type
    if s == "-h" then print(Help) end
    for k in pairs(d) do
      v = s:match("^%-%-" .. k .. "=(.*)")
      if v then
        v = thing(v)
        assert(type(v) == type(d[k]),
               "bad "..s.." : want "..type(d[k]))
        d[k] = v end end end
  return d end

function run(funs,w,    ok,msg) -- one seeded demo; nil if no
  srand(the.seed)               -- such demo, else did it run?
  if funs[w] then
    ok, msg = xpcall(funs[w], debug.traceback)
    if not ok then print(msg) end
    return ok end end

function go(eg,    n) -- run the demos named on the command line
  if arg and arg[0] and      -- and exit with the failure count
     debug.getinfo(2,"S").source == "@"..arg[0] then
    cli(the)
    n = 0
    for _,w in ipairs(arg) do
      if run(eg, w) == false then n = n + 1 end end
    os.exit(n) end end

the = options(help)
srand(the.seed) -- default stream; runners may reseed later

--## columns ---------------------------------------------------
-- Every column is a NUM or a SYM, picked by the first letter
-- of its name, and both answer add, mid, div, norm, dist.
-- Nothing downstream asks which kind it is holding.

function Col(name,at) -- lowercase name makes a SYM, upper a NUM
  return (name:find"^%l" and Sym or Num)(name,at) end

function Num(name,at) -- numeric column; a trailing "-" in the
  name = name or ""   -- name means minimize it
  return new(NUM, {at=at or 1, name=name, n=0, mu=0, m2=0,
                   heaven = name:find"-$" and 0 or 1}) end

function Sym(name,at) -- symbolic column: just the counts
  return new(SYM, {at=at or 1, name=name or "", n=0, has={}}) end

function SYM.add(i,v,inc) -- update counts; inc=-1 forgets v
  if v == "?" then return v end
  inc = inc or 1
  i.n = i.n + inc
  i.has[v] = inc + (i.has[v] or 0)
  if i.has[v] <= 0 then i.has[v] = nil end
  return v end

function NUM.add(i,v,inc,    d) -- one-pass mu and m2, forwards
  if v == "?" then return v end -- (inc=1) or in reverse (inc=-1)
  inc  = inc or 1
  i.n  = i.n + inc
  d    = v - i.mu
  i.mu = i.mu + inc * d / i.n
  i.m2 = i.m2 + inc * d * (v - i.mu); return v end

function SYM.mid(i,    hi,out) -- center: the mode
  hi = -1
  for k, n in pairs(i.has) do
    if n > hi then hi, out = n, k end end
  return out end

function NUM.mid(i) return i.mu end -- center: the mean

function SYM.div(i) -- diversity: entropy. One-arg log only: the
  return sum(i.has, function(n,    p) -- two-arg form is LuaJIT
    p = n / i.n                       -- and 5.2+, and 5.1 drops
    return -p * log(p) / log(2) end) end -- the base

function NUM.div(i) -- diversity: standard deviation
  return i.n < 2 and 0 or sqrt(max(i.m2,0) / (i.n-1)) end

function SYM.norm(i,v) return v end -- syms have no cdf

function NUM.norm(i,v,    z) -- v's cdf, via a logistic; 0..1
  if v == "?" then return v end
  z = (v - i.mu) / (i:div() + TINY)
  return 1 / (1 + exp(-1.702 * max(-3, min(3, z)))) end

function SYM.holds(i,x,v) return x == "?" or x == v  end -- an
function NUM.holds(i,x,v) return x == "?" or x <= v  end -- "?"
                              -- says yes, so no row is ever lost
--## tables ----------------------------------------------------
-- A TBL is rows plus the column summaries those rows built.
-- Row 1 of any source is the header, and the header alone
-- decides each column's kind and role.

function Tbl(src) -- fold rows into fresh cols; row 1 is header
  src = iter(src)
  return adds(src, new(TBL, {rows={}, mid=nil,
                             cols=Cols(src())})) end

function Cols(names,    all,x,y,klass) -- header roles: "!" is
  all, x, y = {}, {}, {}       -- the class, "+"/"-" a goal, "X"
  for at, s in ipairs(names) do -- is ignored, the rest are x
    all[at] = Col(s, at)
    if s:find"!$" then klass = all[at]
    elseif s:find"[+-]$" then y[#y+1] = all[at]
    elseif s:sub(-1) ~= "X" then x[#x+1] = all[at] end end
  return new(COLS, {names=names,all=all,x=x,y=y,klass=klass}) end

function COLS.add(i,row,inc) -- fold a row into every column
  for _, c in ipairs(i.all) do c:add(row[c.at], inc) end
  return row end

function TBL.add(i,row) -- keep the row; update the summaries
  i.rows[#i.rows+1] = i.cols:add(row)
  i.mid = nil
  return row end

function TBL.clone(i,rows,    u) -- same header, fresh summaries;
  u = adds(rows, Tbl{i.cols.names})  -- clones of a live model
  u.model = i.model                  -- stay live, so labels
  return u end                       -- still arrive on demand

function TBL.mids(i) -- centroid: every column's middle, cached
  i.mid = i.mid or map(i.cols.all, "mid")
  return i.mid end

--## forgetting ------------------------------------------------
-- Summaries subtract as well as add, so one pass over sorted
-- data can score every split (see cuts) with no rebuilding.

function NUM.__sub(i,j,    n,d) -- tot - v: what is left
  n = i.n - j.n
  if n < 1 then return Num(i.name, i.at) end
  d = j.mu - i.mu
  return new(NUM, {name=i.name, at=i.at, heaven=i.heaven,
                   n=n, mu=(i.n*i.mu - j.n*j.mu) / n,
                   m2=max(0, i.m2 - j.m2
                             - d*d*i.n*j.n/n)}) end

function SYM.__sub(i,j,    out,n) -- tot - v: the counts left
  out = Sym(i.name, i.at)
  for k,v in pairs(i.has) do
    n = v - (j.has[k] or 0)
    if n > 0 then out.has[k] = n; out.n = out.n + n end end
  return out end

function NUM.reset(i) i.n, i.mu, i.m2 = 0, 0, 0 end -- to empty
function SYM.reset(i) i.n, i.has = 0, {} end        -- to empty

function TBL.sub(i,row) -- forget a row. All resets happen here,
  i.cols:add(row, -1)   -- so an emptied table ends up with
  i.mid = nil           -- genuinely fresh columns, not drifted
  for j,r in ipairs(i.rows) do
    if r == row then table.remove(i.rows, j); break end end
  if #i.rows == 0 then map(i.cols.all, "reset") end
  return row end

function adds(src,i) -- fold a list or iterator into a summary
  i = i or Num()
  for v in iter(src or {}) do i:add(v) end
  return i end

--## distance --------------------------------------------------
-- Gaps per column are 0..1, and minkowski folds them into one
-- 0..1 distance: distx over the x columns, disty from the
-- goals to heaven (0 = best). disty is also the seam where an
-- external model gets asked for a label.

function SYM.dist(i,a,b) -- gap between two symbols; 0..1
  if a == "?" and b == "?" then return 1 end
  return a ~= b and 1 or 0 end

function NUM.dist(i,a,b) -- gap between two numbers; 0..1. An
  if a == "?" and b == "?" then return 1 end -- unknown cell is
  a, b = i:norm(a), i:norm(b)   -- pushed to the further end
  if a == "?" then a = b > 0.5 and 0 or 1 end
  if b == "?" then b = a > 0.5 and 0 or 1 end
  return abs(a - b) end

function minkowski(cols,f,    d,n) -- p-norm mean of f(col)
  d, n = 0, TINY
  for _, c in ipairs(cols) do n, d = n+1, d + f(c) ^ the.p end
  return (d / n) ^ (1 / the.p) end

function TBL.distx(i,row1,row2) -- gap over the x columns; 0..1
  return minkowski(i.cols.x, function(c)
           return c:dist(row1[c.at], row2[c.at]) end) end

function TBL.label(i,row,    f) -- ask i.model for this row's
  f = i.model(map(i.cols.x,     -- goals, then fold them in
        function(c) return row[c.at] end), #i.cols.y)
  for j, y in ipairs(i.cols.y) do
    row[y.at] = y:add(f[j]) end
  return row end

function TBL.disty(i,row) -- gap to heaven; 0 = best. Rows born
  if i.model and row[i.cols.y[1].at] == "?" then -- "?" get
    i:label(row) end                   -- labelled on demand here
  return minkowski(i.cols.y, function(y)
           return abs(y:norm(row[y.at]) - y.heaven) end) end

function TBL.Y(i) -- disty as a key function, for keysort and map
  return function(r) return i:disty(r) end end

--## clusters --------------------------------------------------
-- Recursive halving on two far-apart poles. One projection
-- per split: cheap enough for an unlabelled pool.

function TBL.poles(i,rows,lo,hi,    far,c) -- two far poles, and
  far = function(r,    t)     -- the projector that ranks any row
          t = keysort(rows, function(z) return i:distx(z, r) end)
          return t[#t] end                 -- between them, best
  lo = lo or far(rows[rand(#rows)])        -- pole first
  hi = hi or far(lo)
  if i:disty(lo) > i:disty(hi) then lo, hi = hi, lo end
  c = i:distx(lo, hi) + TINY
  return function(r) return (i:distx(lo,r)^2 + c*c
                              - i:distx(hi,r)^2) / (2*c) end,
         lo, hi end

function TBL.halve(i,rows,    fun,a,b,n) -- split on the poles,
  rows = rows or i.rows                  -- best half first
  fun, a, b = i:poles(some(rows, the.few))
  rows = keysort(rows, fun)
  n = floor(#rows / 2)
  return a, b, slice(rows, 1, n), slice(rows, n + 1) end

function Node(tbl,rows,    recurse) -- tree of halves, halving
  function recurse(rows,    node,a,b,lo,hi) -- until a node is
    node = new(NODE, {here=tbl:clone(rows), -- too small to split
                      a=nil, b=nil, lo=nil, hi=nil})
    if #rows >= 2 * the.stop then
      a, b, lo, hi = tbl:halve(rows)
      node.a, node.b = a, b
      if #lo > 0 and #hi > 0 then
        node.lo, node.hi = recurse(lo), recurse(hi) end end
    return node
  end -- recurse
  return recurse(rows or tbl.rows) end

function NODE.leaf(i,row,    t) -- walk a row down to its leaf,
  while i.lo do                 -- to the nearer pole each level
    t = i.here
    i = t:distx(row, i.a) <= t:distx(row, i.b)
        and i.lo or i.hi end
  return i end

--## acquire ---------------------------------------------------
-- Label few rows, cull the pool toward the good pole, loop.
-- When a pool dries with budget left, acquirer reshuffles and
-- goes again, anchored at the best and worst labels so far.

function TBL.acquire(i,rows,cap,lab,lo,hi, -- one sweep: spend up
                     seen,more,new)   -- to the.more labels, then
  seen = {}                   -- keep the.keepf of the pool
  for _,r in ipairs(lab) do seen[r] = true end -- nearest the
  while #rows >= 2*the.leaf do                 -- good pole
    more, new = min(the.more, cap - #lab), {}
    for _,r in ipairs(rows) do -- new = labels in this pool
      if seen[r] then push(new, r)
      elseif more > 0 then
        more, seen[r] = more - 1, true
        push(new, push(lab, r)) end end
    if #lab >= cap then return lab end -- budget spent
    rows = slice(keysort(rows, (i:poles(new, lo, hi))),
               1, max(1, floor(the.keepf * #rows))) end
  return lab end

function TBL.acquirer(i,cap,    lab,lo,hi,t,b4) -- sweep until
  lab = {}                 -- the budget is spent or no sweep
  while true do            -- makes progress; best rows first
    b4  = #lab
    lab = i:acquire(shuffle(i.rows), cap, lab, lo, hi)
    if #lab >= cap or #lab >= #i.rows or
       #lab == b4 then break end -- full, or no progress
    t = keysort(lab, i:Y())
    lo, hi = t[1], t[#t] end -- best+worst seen
  return keysort(lab, i:Y()) end

--## discretize ------------------------------------------------
-- Find the cuts that most purify some y summary. All
-- candidates feed one `least` reducer; no cut lists are built.

function val(a,b) -- mean diversity of two summaries, by size
  return (a:div()*a.n + b:div()*b.n) / (a.n + b.n + TINY) end

function big(lo,n) -- both sides of a cut hold at least the.leaf
  return the.leaf <= lo and lo <= n - the.leaf end

function SYM.cuts(c,xy,tot,acc,best,    d,b) -- one cut per key
  d = {}
  for _,p in ipairs(xy) do
    b = d[p[1]] or acc()
    b:add(p[2]); d[p[1]] = b end
  if #keys(d) > 1 then
    for k,v in pairs(d) do
      if big(v.n, #xy) then
        best{val(v, tot - v), c.at, k} end end end end

function NUM.cuts(c,xy,tot,acc,best,    here) -- cuts between
  table.sort(xy, function(a,b) return a[1] < b[1] end) -- each
  here = acc()          -- distinct sorted x. One pass: the left
  for j,p in ipairs(xy) do  -- summary grows, the right is tot
    here:add(p[2])          -- minus it
    if j < #xy and p[1] ~= xy[j+1][1] and big(j, #xy) then
      best{val(here, tot - here),c.at,p[1]} end end end

function TBL.cuts(i,rows,c,Y,acc,best,    xy,tot) -- column c
  xy = {}                     -- feeds its splits to best,
  for _,r in ipairs(rows) do  -- skipping "?" cells
    if r[c.at] ~= "?" then push(xy, {r[c.at], Y(r)}) end end
  tot = adds(map(xy, 2), acc())
  c:cuts(xy, tot, acc, best) end

function TBL.bestcut(i,rows,Y,acc,best) -- champion cut over all
  for _,c in ipairs(i.cols.x) do        -- x cols, as {val,at,v}
    i:cuts(rows,c,Y,acc,best) end
  return best() end

function TBL.divide(i,rows,c,v,    yes,no) -- rows that hold
  yes, no = {}, {}                  -- c<=v (or c==v), and those
  for _,r in ipairs(rows) do        -- that do not
    push(c:holds(r[c.at], v) and yes or no, r) end
  return yes, no end

--## trees -----------------------------------------------------
-- Recursive best-cut trees over the discretizer above, plus
-- walk/sides: visit every pruning of a grown tree.

function Tree(tbl,rows,Y,acc,    recurse) -- grow to the.maxd on
  function recurse(rows,lvl,    ys,t,b,c,yes,no) -- the best cut
    ys = adds(map(rows, Y), acc())   -- each time. Each node has
    t  = new(TREE, {at=nil, v=nil, mu=ys:mid(), leafs=1, -- its
                    here = tbl:clone(rows),   -- rows, its loss,
                    loss = ys.has and ys:div() or ys:mid()})
    t.val = t.loss              -- and the best loss below it
    if #rows >= 2*the.leaf and lvl < the.maxd then
      b = tbl:bestcut(rows, Y, acc, least())
      if b then
        c = tbl.cols.all[b[2]]
        yes, no = tbl:divide(rows, c, b[3])
        if #yes > 0 and #no > 0 then
          t.at, t.v = b[2], b[3]
          t.yes   = recurse(yes, lvl+1)
          t.no    = recurse(no,  lvl+1)
          t.val   = min(t.yes.val, t.no.val)
          t.leafs = t.yes.leafs + t.no.leafs end end end
    return t
  end -- recurse
  Y   = Y or tbl:Y()
  acc = acc or Num
  return recurse(rows, 0) end

function TREE.leafed(x) -- x, collapsed to one leaf
  return new(TREE, {at=nil, mu=x.mu, loss=x.loss,
                    val=x.loss, leafs=1, here=x.here}) end

function TREE.walk(t,fun) -- fun on every pruning of tree t
  if t.at == nil then return fun(t) end
  t.yes:sides(function(yes)
    t.no:sides(function(no)
      fun(new(TREE, {at=t.at, v=t.v, here=t.here,
                     yes=yes, no=no,
                     val=min(yes.val, no.val),
                     leafs=yes.leafs + no.leafs})) end) end) end

function TREE.sides(t,fun) -- t as one leaf, then its prunings
  fun(t:leafed())
  if t.at ~= nil then t:walk(fun) end end

function TREE.leaf(t,tbl,row,    c) -- walk a row to its leaf;
  while t.at do                     -- the leaf's mean is the
    c = tbl.cols.all[t.at]          -- guess
    t = c:holds(row[t.at], t.v) and t.yes or t.no end
  return t.mu end

--## tree show -------------------------------------------------
-- One row per node: n, d2h, then each goal's mean under its
-- own header column; tree structure trails on the right.

function TREE.leaves(t,fun) -- fun on every leaf below t
  if t.at then t.yes:leaves(fun)
               t.no:leaves(fun)
  else fun(t) end end

function TREE.gstr(t) -- this node's goal means, aligned
  return table.concat(map(t.here.cols.y, function(g)
    return ("%9s"):format(show(g:mid())) end)) end

function TREE.show(t,tbl,    lo,hi,recurse) -- the whole tree.
  function recurse(t,pre,txt,    c,say,m,a,b) -- Best and worst
    m = (t.at == nil and t.mu == lo and UP) or -- leaves are
        (t.at == nil and t.mu == hi and DOWN) or " " -- marked;
    print(("%s%4d %5.2f%s  %s"):format(   -- siblings print lower
      m, #t.here.rows, t.mu, t:gstr(), pre .. txt)) -- mu first
    if t.at then                     -- structure right
      c   = tbl.cols.all[t.at]
      say = function(op)
              return c.name .. op .. show(t.v) end
      pre = pre .. (txt == "" and "" or "|  ")
      a = {t.yes, c.has and " == " or " <= "}
      b = {t.no,  c.has and " ~= " or " >  "}
      if b[1].mu < a[1].mu then a, b = b, a end -- best first
      recurse(a[1], pre, say(a[2]))
      recurse(b[1], pre, say(b[2]))
    end
  end -- recurse
  lo, hi = huge, -huge     -- leaf extremes,
  t:leaves(function(l)               -- then a header
    lo, hi = min(lo, l.mu), max(hi, l.mu) end)
  print((" %4s %5s"):format("n", "d2h") ..
    table.concat(map(t.here.cols.y, function(g)
      return ("%9s"):format(g.name) end)))
  recurse(t, "", "") end

--## score -----------------------------------------------------
-- How good was that answer, honestly? `wins` grades against
-- an oracle pass over the pool; `holdout` makes the method
-- earn its grade on rows it never saw.

function TBL.wins(i,rows,    ys,lo,b4) -- row -> percent of the
  ys = sorted(map(rows or i.rows, i:Y()))  -- gap to the pool
  lo, b4 = ys[1], ys[floor(#ys/2)+1]       -- best that closed.
  return function(r)                  -- 100 = the pool best,
    return max(-100, min(100,         -- 0 = the median row
      100*(1 - (i:disty(r)-lo) / (b4-lo+TINY)))) end end

function TBL.holdout(i,how,    rows,n,train,test,lab,t,top)
  how  = how or function(t2,cap) return t2:acquirer(cap) end
  rows = shuffle(i.rows)   -- label the train half via how, grow
  n    = floor(#rows/2)    -- a tree, rank the unseen test half,
  train= slice(rows, 1, n) -- then label the best the.check of
  test = slice(rows, n+1)  -- that ranking and return the winner
  lab  = how(i:clone(train), the.budget - the.check)
  assert(#lab + the.check <= the.budget) -- spend, counted
  t    = Tree(i, lab)
  top  = slice(keysort(test, function(r) return t:leaf(i, r) end),
           1, the.check)
  return keysort(top, i:Y())[1] end

--## statistics ------------------------------------------------
-- Is that gap real, or is it noise? Three cheap tests, each
-- asking a different question, and `same` only says yes when
-- all three agree.

function cohen(xs,ys,    x,y,n,m,sd) -- mean gap, in pooled sds
  x, y = adds(xs), adds(ys)
  n, m = x.n, y.n
  sd = sqrt(((n-1)*x:div()^2 + (m-1)*y:div()^2)/(n+m-2))
  return abs(x.mu - y.mu) / (sd + TINY) end

function ks(xs,ys,    nx,ny,d,p,q,v) -- max cdf gap, in critical
  nx, ny  = #xs, #ys          -- units. Walks both cdfs, one
  d, p, q = 0, 0, 0           -- distinct value at a time.
  while p < nx and q < ny do   -- Sorted lists in
    v = min(xs[p+1], ys[q+1])
    while p < nx and xs[p+1] == v do p = p + 1 end
    while q < ny and ys[q+1] == v do q = q + 1 end
    d = max(d, abs(p / nx - q / ny)) end
  return d / ((nx + ny) / (nx * ny)) ^ 0.5 end

function cliffs(xs,ys,    gt,lt,j,k) -- rank imbalance; 0..1. As
  gt, lt, j, k = 0, 0, 0, 0     -- x ascends, j and k (ys below
  for _, x in ipairs(xs) do     -- and at-or-below x) only ever
    while j < #ys and ys[j+1] <  x do j = j + 1; k = j end
    while k < #ys and ys[k+1] == x do k = k + 1 end
    gt = gt + j; lt = lt + #ys - k end          -- advance.
  return abs(gt - lt) / (#xs * #ys) end         -- Sorted in

function same(xsort,ysort) -- all three must agree. `and` is
  return cohen( xsort,ysort) <= 0.350  -- lazy, so the cheap
     and cliffs(xsort,ysort) <= 0.195  -- test runs first.
     and ks(    xsort,ysort) <= 1.360 end       -- Sorted in

function ranks(d,    dd,out,rank,best) -- name -> rank, by
  dd = {}                         -- median, best first. One that
  for k,v in pairs(d) do dd[k] = sorted(v) end -- is `same` as
  out, rank = {}, -1                     -- the rank above shares
  for _, k in ipairs(keysort(keys(dd),   -- that rank
                function(k) return median(dd[k]) end)) do
    if best == nil or not same(dd[best], dd[k]) then
      rank, best = rank + 1, k end
    out[k] = rank end
  return out end

function winners(r,    u) -- the rank-0 names of a rank table
  u = kap(r, function(k,v) if v == 0 then return k end end)
  return sorted(u) end

--## the end ---------------------------------------------------
return _ENV
