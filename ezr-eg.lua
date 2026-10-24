#!/usr/bin/env lua
local help = [[
ezr-eg.lua: skills built on the ezr substrate, one short
function per book chapter. Residents: knn prediction (Fortune
Teller), anomaly (Bouncer), naive bayes (ER Nurse),
kmeans/kpp (Curator), ga/de/sa/ls/race (Drag Race: the ch22
shootout). Demos at the bottom; run with --all.

options:
  k=5         knn: neighbours polled per guess
  kluster=8   kmeans, kpp: clusters wanted
  iter=10     kmeans: assign/recentre passes
  L=1         nb: Laplace smoothing on syms
  m=2         nb: m-estimate prior weight
  wait=10     nb: rows seen before scoring starts
  np=20       ga/de: population size
  gens=10     ga/de: generations
  muts=2      mutants: x cells re-picked per kid
  F=0.5       de: extrapolation scale
  cr=0.9      de: crossover rate, per dim
  budget1=200 sa/ls: evals per run
  repeats=5   race: runs per optimizer]]

local abs,exp,log,pi = math.abs, math.exp, math.log, math.pi
local min,max,floor  = math.min, math.max, math.floor

-- require searches package.path, which holds ./?.lua (the
-- cwd) but not this file's dir: so ezr.lua goes on the front
package.path = (debug.getinfo(1,"S").source:match"^@(.*/)" or "")
               .. "?.lua;" .. package.path
local _ENV = setmetatable({}, {__index = require"ezr"})
if setfenv then setfenv(1, _ENV) end

the = also(the, help)

--## predict (the Fortune Teller) ------------------------------
-- Guess a row's goals from the rows it looks like. No model
-- is fitted; the neighbours are the model.

function TBL.around(i,row,rows) -- the rows, nearest first
  return keysort(rows or i.rows,
           function(r) return i:distx(row, r) end) end

function TBL.knn(i,row,k,    t) -- row's disty, from its k
  t = i:around(row)             -- nearest neighbours
  return adds(map(slice(t, 1, k or the.k), i:Y())).mu end

--## anomaly (the Bouncer) -------------------------------------
-- Who does not belong? Loneliness is the whole test.

function TBL.anomaly(i,    dn,gap) -- score rows 0..1; 1 = the
  gap = function(r,    lo,d)       -- loneliest. The gap scored
    lo = 1e32                      -- is the distance to the
    for _,z in ipairs(i.rows) do   -- nearest other row
      if z ~= r then
        d = i:distx(r, z); if d < lo then lo = d end end end
    return lo end
  dn = Num()
  for _,r in ipairs(i.rows) do dn:add(gap(r)) end
  return function(r) return dn:norm(gap(r)) end end

--## bayes (the ER Nurse) --------------------------------------
-- Sort arrivals into classes, fast, one row at a time. Test
-- then train: every row is guessed before it is learned, so
-- the accuracy needs no held-out split.

function like(col,v,prior,    z) -- P(v|col): an m-estimate for
  if not col.mu then             -- syms, a gaussian for nums
    return ((col.has[v] or 0) + the.L*prior)
           / (col.n + the.L) end
  z = 2 * col:div()^2 + 1e-32
  return exp(-(v - col.mu)^2 / z) / (pi * z)^0.5 end

function TBL.likes(h,row,nrows,nh,    prior,out,v) -- log
  prior = (#h.rows + the.m) / (nrows + the.m*nh) -- likelihood of
  out   = log(prior)              -- row under this klass-table
  for _,c in ipairs(h.cols.x) do
    v = row[c.at]
    if v ~= "?" then
      v = like(c, v, prior)
      if v > 0 then out = out + log(v) end end end
  return out end

function mostlikes(h,row,nrows,nh,    best,bs,s) -- which
  bs = -1e32                  -- klass-table likes this row most?
  for k,hk in pairs(h) do
    s = hk:likes(row, nrows, nh)
    if s > bs then bs, best = s, k end end
  return best end

function TBL.classify(i,wait,    at,h,seen,nh,want) -- test,
  wait, at = wait or the.wait, i.cols.klass.at -- then train: one
  h, seen, nh = {}, {}, 0      -- pass, no held-out split.
  for j,row in ipairs(i.rows) do -- Scoring starts once `wait`
    want = row[at]               -- rows have been seen. Returns
    if j >= wait and nh > 0 then -- a list of {got, want} pairs
      push(seen, {mostlikes(h, row, #i.rows, nh), want}) end
    if not h[want] then h[want] = i:clone(); nh = nh + 1 end
    h[want]:add(row) end
  return seen end

function acc(seen,    n) -- fraction of {got,want} that agree
  n = 0
  for _,p in ipairs(seen) do
    if p[1] == p[2] then n = n + 1 end end
  return n / (#seen + 1e-32) end

--## cluster (the Curator) -------------------------------------
-- Group the rows without labelling any. kmeans finds the
-- groups; kpp picks start centroids far apart, so kmeans does
-- not start in a corner.

local function nearest(i,cents,r,    lo,d,at) -- index of r's
  lo = 1e32                                   -- closest centroid
  for j,c in ipairs(cents) do
    d = i:distx(c, r)
    if d < lo then lo, at = d, j end end
  return at end

local function assign(i,cents,    out) -- each row into its
  out = map(cents, function() return i:clone() end) -- centroid's
  for _,r in ipairs(i.rows) do                      -- clone
    out[nearest(i, cents, r)]:add(r) end
  return out end

local function recentre(clusters,    cents) -- middles of the
  cents = {}                                -- non-empty clusters
  for _,c in ipairs(clusters) do
    if #c.rows > 0 then push(cents, c:mids()) end end
  return cents end

function TBL.kmeans(i,k,iter,    cents) -- k clusters: iter
  cents = some(i.rows, k or the.kluster) -- rounds of assign,
  for _ = 1, iter or the.iter do         -- then recentre
    cents = recentre(assign(i, cents)) end
  return assign(i, cents) end

local function d2(i,cents,r,    lo,d) -- squared distance from r
  lo = 1e32                           -- to its nearest centroid
  for _,c in ipairs(cents) do
    d = i:distx(r, c); lo = min(lo, d*d) end
  return lo end

local function wpick(ws,    all,r,c) -- index j, with chance
  all = sum(ws, function(w) return w end)    -- ws[j]/sum(ws)
  r, c = rand() * all, 0
  for j,w in ipairs(ws) do
    c = c + w
    if r <= c then return j end end
  return #ws end

function TBL.kpp(i,k,    cents,pool,ws) -- k centroids, far
  cents = {some(i.rows, 1)[1]}     -- apart: d^2-weighted picks
  while #cents < (k or the.kluster) do  -- from random pools
    pool = some(i.rows, min(the.few, #i.rows))
    ws   = map(pool, function(r) return d2(i, cents, r) end)
    push(cents, pool[wpick(ws)]) end
  return cents end

--## optimize (the Drag Race) ----------------------------------
-- Classic optimizers, racing. Mutants invent x values, so
-- their y cells are unknown: snap grades a mutant by its
-- nearest real row, and guess is that neighbour's disty.

function TBL.dominates(i,r1,r2,    d1,d2,better,worse) -- r1 no
  if i.model then i:disty(r1); i:disty(r2) end  -- worse on all
  better, worse = false, false   -- goals, better on one. Goals
  for _,y in ipairs(i.cols.y) do -- that do not exist yet get
    d1 = abs(y:norm(r1[y.at]) - y.heaven)  -- bought here, so
    d2 = abs(y:norm(r2[y.at]) - y.heaven)  -- model-backed pools
    if d1 < d2 then better = true end      -- work too
    if d1 > d2 then worse  = true end end
  return better and not worse end

function TBL.snap(i,row,    lo,d,out) -- nearest real row to a
  lo = 1e32                           -- made-up one
  for _,r in ipairs(i.rows) do
    d = i:distx(row, r)
    if d < lo then lo, out = d, r end end
  return out end

function TBL.guess(i,row) -- a mutant's worth: its neighbour's
  return i:disty(i:snap(row)) end                      -- disty

local function gauss(    g) -- unit normal, the cheap way
  g = -6; for _ = 1, 12 do g = g + rand() end; return g end

local function wkey(d,    all,r,c) -- a key, with a chance
  all = sum(d, function(n) return n end)  -- weighted by its count
  r, c = rand() * all, 0
  for _,k in ipairs(keys(d)) do
    c = c + d[k]
    if r <= c then return k end end end

function pick(col,v,    sd) -- a new cell near v: syms by
  if col.has then return wkey(col.has) end -- frequency, nums by
  v  = v ~= "?" and v or col.mu    -- a gaussian step, clamped
  sd = col:div()                   -- to +-3sd
  return max(col.mu - 3*sd,
             min(col.mu + 3*sd, v + sd * gauss())) end

function TBL.mutate(i,row,n,    out,xs) -- copy row, re-pick n
  out, xs = copy(row), shuffle(i.cols.x) -- random x cells
  for j = 1, min(n or the.muts, #xs) do
    out[xs[j].at] = pick(xs[j], out[xs[j].at]) end
  return out end

function TBL.extrapolate(i,a,b,c,    out,keep,va,vb,vc,v,lo,s)
  out  = copy(a)             -- a de kid: a + F*(b - c) per dim,
  keep = i.cols.x[rand(#i.cols.x)]  -- with probability cr.
  for _,col in ipairs(i.cols.x) do  -- Numbers wrap inside +-4sd
    if col ~= keep and rand() < the.cr then
      va, vb, vc = a[col.at], b[col.at], c[col.at]
      if va == "?" then out[col.at] = "?"
      elseif col.has then
        out[col.at] = rand() < the.F and vb or va
      elseif vb == "?" or vc == "?" then out[col.at] = va
      else
        v  = va + the.F * (vb - vc)
        lo = col.mu - 4*col:div()
        s  = 8*col:div() + 1e-32
        out[col.at] = lo + (v - lo) % s end end end
  return out end

local function tourn(i,pop,    a,b) -- 2-way select: keep the
  a, b = pop[rand(#pop)], pop[rand(#pop)]            -- dominator
  return i:dominates(i:snap(b), i:snap(a)) and b or a end

local function cross(i,mum,dad,    kid,cut) -- one-point
  kid, cut = copy(mum), rand(#i.cols.x)             -- crossover
  for j,c in ipairs(i.cols.x) do
    if j > cut then kid[c.at] = dad[c.at] end end
  return kid end

function TBL.ga(i,    pop,kids) -- evolve np rows, gens times:
  pop = slice(shuffle(i.rows), 1, the.np) -- domination
  for _ = 1, the.gens do                  -- tournament, cross,
    kids = {}                             -- mutate
    for _ = 1, the.np do
      push(kids, i:mutate(cross(i, tourn(i, pop),
                                    tourn(i, pop)))) end
    pop = kids end
  return i:snap(keysort(pop, function(r)
                          return i:guess(r) end)[1]) end

function TBL.de(i,    pop,es,t,kid,d,at) -- de/rand/1: a kid
  pop = slice(shuffle(i.rows), 1, the.np) -- replaces its parent,
  es  = map(pop, function(r) return i:guess(r) end) -- but only
  for _ = 1, the.gens do                  -- when it is better
    for j = 1, #pop do
      t   = some(pop, 3)
      kid = i:extrapolate(t[1], t[2], t[3])
      d   = i:guess(kid)
      if d < es[j] then pop[j], es[j] = kid, d end end end
  at = 1
  for j = 2, #es do if es[j] < es[at] then at = j end end
  return i:snap(pop[at]) end

local function climb(i,accept,    s,e,b,eb,kid,d) -- the (1+1)
  s = i.rows[rand(#i.rows)]   -- loop: mutate s, maybe accept the
  e = i:guess(s)              -- mutant, keep the best ever seen
  b, eb = s, e
  for h = 1, the.budget1 do
    kid = i:mutate(s)
    d   = i:guess(kid)
    if d < eb then b, eb = kid, d end
    if accept(e, d, h) then s, e = kid, d end end
  return i:snap(b) end

function TBL.ls(i) -- greedy local search: better, or bust
  return climb(i, function(e,d) return d < e end) end

function TBL.sa(i) -- annealing: metropolis says yes to some bad
  return climb(i, function(e,d,h) -- moves, more rarely as the
    return d < e or rand() < exp((e - d) / -- budget cools
      (1 - h/the.budget1 + 1e-32)) end) end

function TBL.race(i,repeats,    d) -- all four optimizers, plus
  d = {ga={}, de={}, sa={}, ls={}, any={}} -- best-of-np random
  for _ = 1, repeats or the.repeats do     -- rows, by same/ranks
    push(d.ga,  i:disty(i:ga()))
    push(d.de,  i:disty(i:de()))
    push(d.sa,  i:disty(i:sa()))
    push(d.ls,  i:disty(i:ls()))
    push(d.any, i:disty(
      keysort(some(i.rows, the.np), i:Y())[1])) end
  return d, ranks(d) end

--## demos -----------------------------------------------------
-- Every demo reseeds, prints a line a tutor can point at,
-- then asserts. No crash means pass.
eg = {}

eg["--all"] = function(    bad) -- all the demos; fail if any do
  bad = 0
  for _,k in ipairs(keys(eg)) do
    if k ~= "--all" and run(eg, k) == false then
      bad = bad + 1 end end
  print("failures: " .. bad)
  assert(bad == 0) end

eg["--knn"] = function(    t,y,mu,e1,e2,r) -- neighbours beat the
  t  = Tbl(csv())                     -- global mean as a guess
  y  = t:Y()
  mu = adds(map(t.rows, y)).mu
  e1, e2 = 0, 0
  for _ = 1, 32 do
    r  = t.rows[rand(#t.rows)]
    e1 = e1 + abs(t:knn(r) - y(r))
    e2 = e2 + abs(mu       - y(r)) end
  print(("knn err %.3f  vs mean-guess err %.3f")
        :format(e1/32, e2/32))
  assert(e1 < e2) end

eg["--detect"] = function(    t,det,ss) -- someone in here is
  t   = Tbl(csv())                                     -- lonely
  det = t:anomaly()
  ss  = sorted(map(t.rows, det))
  print(show{lo=ss[1], mid=median(ss), hi=ss[#ss]})
  assert(0 <= ss[1] and ss[#ss] <= 1)
  assert(ss[#ss] > 0.5) end

eg["--nb"] = function(    t,seen,a) -- test-then-train bayes, on
  t    = Tbl(csv"diabetes.csv")                      -- diabetes
  seen = t:classify()
  a    = acc(seen)
  print(("diabetes: acc %.2f over %s guesses"):format(
    a, #seen))
  assert(a > 0.65) end

eg["--kmeans"] = function(    t,cs,n) -- clustering conserves
  t  = Tbl(csv())                                        -- rows
  cs = t:kmeans()
  n  = 0
  for _,c in ipairs(cs) do n = n + #c.rows end
  print("cluster sizes " ..
    show(sorted(map(cs, function(c) return #c.rows end))))
  assert(n == #t.rows and #cs <= the.kluster) end

eg["--kpp"] = function(    t,cents,d) -- the seeds come out
  t     = Tbl(csv())                                -- spread out
  cents = t:kpp()
  d = 1e32
  for j = 1, #cents do
    for k = j+1, #cents do
      d = min(d, t:distx(cents[j], cents[k])) end end
  print(("%s kpp seeds, min gap %.3f"):format(#cents, d))
  assert(#cents == the.kluster and d > 0) end

eg["--dominate"] = function(    t,y,n,tie,a,b,w) -- if a
  t, y = Tbl(csv()), nil      -- dominates b then a's d2h is
  y = t:Y()                   -- less; and often, nobody wins
  n, tie = 0, 0
  for _ = 1, 64 do
    a = t.rows[rand(#t.rows)]
    b = t.rows[rand(#t.rows)]
    if     t:dominates(a, b) then w = y(a) < y(b)
    elseif t:dominates(b, a) then w = y(b) < y(a)
    else w, tie = true, tie + 1 end
    if w then n = n + 1 end end
  print(("dominate agrees with d2h %s/64; "..
         "indecisive on %s pairs"):format(n, tie))
  assert(n == 64 and tie > 0) end

eg["--ga"] = function(    t,mid) -- the evolved best beats the
  t   = Tbl(csv())                            -- median row
  mid = median(map(t.rows, t:Y()))
  print("ga best d2h " .. show(t:disty(t:ga())))
  assert(t:disty(t:ga()) < mid) end

eg["--de"] = function(    t,mid) -- same test, de
  t   = Tbl(csv())
  mid = median(map(t.rows, t:Y()))
  print("de best d2h " .. show(t:disty(t:de())))
  assert(t:disty(t:de()) < mid) end

eg["--sa"] = function(    t,mid) -- same test, annealing
  t   = Tbl(csv())
  mid = median(map(t.rows, t:Y()))
  print("sa best d2h " .. show(t:disty(t:sa())))
  assert(t:disty(t:sa()) < mid) end

eg["--ls"] = function(    t,mid) -- same test, local search
  t   = Tbl(csv())
  mid = median(map(t.rows, t:Y()))
  print("ls best d2h " .. show(t:disty(t:ls())))
  assert(t:disty(t:ls()) < mid) end

eg["--race"] = function(    t,d,r,mid,mids) -- the ch22 dragrace:
  t    = Tbl(csv())            -- 5 repeats each, by same/ranks
  d, r = t:race()
  mid  = median(map(t.rows, t:Y()))
  mids = kap(d, function(k,v)
    return k .. "=" .. show(median(v)) end)
  print("median best d2h: " ..
        table.concat(sorted(mids), " "))
  print("rank 0: " .. show(winners(r)))
  assert(#winners(r) >= 1)
  for _,v in pairs(d) do assert(median(v) < mid) end end

--## start-up --------------------------------------------------
-- Fires only when this file is the script the user ran.
go(eg)

return _ENV
