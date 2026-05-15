#!/usr/bin/env fun
-- vim: ft=fun
the, help := {}, [[
ezr.fun : explainable multi-objective optimization
(c) 2026, Tim Menzies <timm@ieee.org>, MIT license
  -b bins=4        num numeric split candidates
  -B Budget=50     initial building budget
  -C Check=5       final check budget
  -c cliffs=0.195  Cliff's delta threshold
  -e eps=0.35      Cohen's threshold
  -f f=auto93.csv  input csv path
  -k ksconf=1.36   KS test threshold
  -l leaf=3        min rows per tree leaf
  -p p=2           distance coefficient
  -s seed=1        random number seed
  -S Show=30       width LHS tree display
  -h               show help
]]

-- Math + string shortcuts.
abs, min, max, log, exp :=
  math.abs, math.min, math.max, math.log, math.exp
floor, rand, randomseed :=
  math.floor, math.random, math.randomseed
fmt, mtype := string.format, math.type

-- Type markers (strings; cheap compare + pretty-print).
NUM, SYM, COLS, DATA, TREE := "Num","Sym","Cols","Data","Tree"

-- Per-column-type behavior (Num vs Sym splits).
TEST := {
  [NUM]= fun(cut): !fun(x): !x <= cut end end,
  [SYM]= fun(cut): !fun(x): !x == cut end end}
YES := {[NUM]="<=", [SYM]="=="}
NO  := {[NUM]=">",  [SYM]="!="}

-- Forward refs: defined below.
let push, csv, add, o, build, leaf, nodes

-- Snapshot global names before our code adds any.
b4 := {}
for k,_ in pairs(_ENV): b4[k] = true

-- ## Classes
-- Numeric column. Trailing "-" => minimize (heaven=0).
Num := fun(txt, at):
  h := txt and txt:match"-$" and 0 or 1
  !{is=NUM, txt=txt or "", at=at or 0,
    n=0, mu=0, m2=0, heaven=h}

-- Symbolic (categorical) column.
Sym := fun(txt, at):
  !{is=SYM, txt=txt or "", at=at or 0,
    has={}, n=0}

-- Names list -> column groups (Num/Sym; x/y/all).
Cols := fun(names):
  xs, ys, all := {}, {}, {}
  for at,txt in ipairs(names):
    cls := txt:match"^[A-Z]" and Num or Sym
    col := push(all, cls(txt, at))
    if (not txt:match"X$"):
      bin := txt:match"[%+%-!]$" and ys or xs
      push(bin, col)
  !{is=COLS, x=xs, y=ys, all=all, names=names}

-- Tree node with scoring fn.
Tree := fun(score): !{is=TREE, score=score}

-- Data container.
Data := fun(src):
  data := {is=DATA, rows={}, cols=nil, _mid=nil}
  if (type(src) == "string"):
    for row in csv(src): add(data, row)
  else:
    for _,row in ipairs(src or {}):
      add(data, row)
  !data

-- ## Library
-- Push x onto end of t; return x.
push = fun(t,x): t[1+#t]= x; !x

-- Sort table in-place; return it.
sort := fun(t,f): table.sort(t, f); !t

-- Sum f(x) over table.
sum := fun(t,f):
  n := 0
  for _,x in ipairs(t): n = n + f(x)
  !n

-- Python-style slice: t[lo..hi:step].
slice := fun(t,lo,hi,step):
  u := {}
  for i= (lo or 1), (hi or #t), (step or 1) do
    u[1+#u]= t[i]
  !u

-- Fisher-Yates shuffle in-place.
shuffle := fun(t):
  for i= #t, 2, -1 do
    j := rand(i)
    t[i], t[j]= t[j], t[i]
  !t

-- Bisect: rightmost index where t[i] <= x.
bisect := fun(t,x):
  lo, hi := 1, #t
  while (lo <= hi):
    m := (lo + hi) // 2
    if (t[m] <= x):
      lo = m + 1
    else:
      hi = m - 1
  !lo - 1

-- Pretty-print scalar/table.
o = fun(x):
  if (type(x) ~= "table"):
    if (mtype(x) == "float"): !("%.2f"):format(x) end
    !tostring(x)
  u := {}
  for k,v in pairs(x):
    s := type(k) == "number" and o(v) or k.."="..o(v)
    u[1+#u]= s
  !"{"..table.concat(sort(u), ", ").."}"

-- Coerce string to bool/number/string.
thing := fun(s):
  !s == "true" or (s ~= "false" and (tonumber(s) or s))

-- CSV iterator.
csv = fun(src):
  f := io.open(src)
  !fun():
    s := f:read()
    if (s):
      t := {}
      for x in s:gmatch"[^,]+":
        push(t, thing(x:match"^%s*(.-)%s*$"))
      !t
    else:
      f:close()

-- Weibull random.
weibull := fun(k,lambda):
  !lambda * (-log(1 - rand())) ^ (1 / k)

-- Report rogue (unintentional) lower-case globals.
rogues := fun():
  for k,_ in pairs(_ENV):
    if (not b4[k] and k:match"^[a-z]"):
      print("rogue: "..k)

-- ## Update
-- Per-class update helpers, then a dispatching `add`.

_num := fun(num, v, w):
  num.n = num.n + w
  if (w < 0 and num.n <= 1):
    num.n, num.mu, num.m2 = 0, 0, 0
  else:
    err := v - num.mu
    num.mu = num.mu + w * err / num.n
    num.m2 = num.m2 + w * err * (v - num.mu)

_sym := fun(sym, v, w):
  sym.n = sym.n + w
  sym.has[v] = w + (sym.has[v] or 0)

_cols := fun(cols, row, w):
  for _,col in ipairs(cols.all):
    add(col, row[col.at], w)

_data := fun(data, row, w):
  if (not data.cols):
    data.cols = Cols(row)
  else:
    data._mid = nil
    add(data.cols, row, w)
    if (w > 0):
      push(data.rows, row)
    else:
      for n,r in ipairs(data.rows):
        if (r == row):
          table.remove(data.rows, n)
          break

add = fun(it, v, w):
  w = w or 1
  if (it.is == DATA): _data(it, v, w); !v
  if (it.is == COLS): _cols(it, v, w); !v
  if (v == "?"): !v
  if (it.is == SYM): _sym(it, v, w); !v
  _num(it, v, w)
  !v

-- Bulk add to summary (default new Num).
adds := fun(values, num):
  num = num or Num()
  for _,v in pairs(values or {}): add(num, v)
  !num

-- Clone: new Data with same column structure.
clone := fun(data, rows):
  !adds(rows or {}, Data({data.cols.names}))

-- ## Query
-- Central tendency (mean or mode).
mid := fun(col):
  if (col.is == NUM): !col.mu end
  most, mode := -1, nil
  for v,n in pairs(col.has):
    if (n > most): most, mode = n, v end
  !mode

-- Variability (stdev or entropy).
spread := fun(col):
  if (col.is == NUM):
    !col.n <= 1 and 0 or (max(0, col.m2)/(col.n-1)) ^ 0.5
  n := 0
  for _,v in pairs(col.has):
    n = n - v/col.n * log(v/col.n, 2)
  !n

-- Centroid: mid of all columns.
mids := fun(data):
  data._mid = data._mid or
              [mid(c) for _,c in ipairs(data.cols.all)]
  !data._mid

-- Sigmoid normalization.
norm := fun(col, v):
  if (v == "?"): !v end
  z := (v - col.mu) / (spread(col) + 1e-32)
  !1 / (1 + exp(-1.7 * max(-3, min(3, z))))

-- Minkowski distance to ideal goal (Y vars).
disty := fun(data, row):
  fn := fun(col):
          x := norm(col, row[col.at]) - col.heaven
          !abs(x) ^ the.p
  s := sum(data.cols.y, fn) / #data.cols.y
  !s ^ (1 / the.p)

-- Probability of winning vs median row.
wins := fun(data):
  ys := sort([disty(data, r) for _,r in ipairs(data.rows)])
  lo, n_mid := ys[1], ys[#ys // 2 + 1]
  !fun(row):
     d := disty(data, row)
     r := (d - lo) / (n_mid - lo + 1e-32)
     !floor(100 * (1 - r))

-- ## Tree
-- Partition rows on test fn.
split := fun(col, rows, fn, cut, test):
  lhs, rhs, L, R := Num(), Num(), {}, {}
  for _,row in ipairs(rows):
    v := row[col.at]
    ok := v == "?" or test(v)
    push(ok and L or R, row)
    add(ok and lhs or rhs, fn(row))
  if (#L >= the.leaf and #R >= the.leaf):
    !{col=col, cut=cut, left=L, right=R, lhs=lhs, rhs=rhs}

-- Candidate cut values for a column.
treeCuts := fun(col, rows):
  if (col.is == SYM): ![k for k,_ in pairs(col.has)] end
  vs := sort([r[col.at] for _,r in ipairs(rows) if r[col.at] ~= "?"])
  step := max(1, #vs // the.bins)
  !slice(vs, step, #vs - step, step)

-- Build variance-minimizing tree.
build = fun(tree, data, rows):
  centroid := mids(clone(data, rows))
  tree.y = adds([tree.score(r) for _,r in ipairs(rows)])
  tree.mids = {}
  for _,c in ipairs(data.cols.y): tree.mids[c.txt]= centroid[c.at]
  if (#rows < 2 * the.leaf): !tree end
  best, bestW := nil, 1E32
  for _,col in ipairs(data.cols.x):
    mkTest := TEST[col.is]
    for _,v in ipairs(treeCuts(col, rows)):
      cut := split(col, rows, tree.score, v, mkTest(v))
      if (cut):
        a := cut.lhs.n * spread(cut.lhs)
        b := cut.rhs.n * spread(cut.rhs)
        w := a + b
        ok := min(#cut.left,#cut.right) >= the.leaf
        if (w < bestW and ok):
          best, bestW = cut, w
  if (best):
    tree.col = best.col
    tree.cut = best.cut
    tree.at  = best.col.at
    tree.left  = build(Tree(tree.score), data, best.left)
    tree.right = build(Tree(tree.score), data, best.right)
  !tree

-- Traverse tree to relevant leaf.
leaf = fun(tree, row):
  if (not tree.col): !tree end
  v := row[tree.at]
  if (v == "?"): !leaf(tree.left, row) end
  ok := TEST[tree.col.is](tree.cut)(v)
  !leaf(ok and tree.left or tree.right, row)

-- Recursive node visitor.
nodes = fun(tree, fn, lvl, pre):
  lvl, pre = lvl or 0, pre or ""
  fn(tree, lvl, pre)
  if (not tree.col): ! end
  kids := sort({{tree.left,  YES[tree.col.is]},
                {tree.right, NO [tree.col.is]}},
               fun(a,b): !mid(a[1].y) < mid(b[1].y) end)
  for _,p in ipairs(kids):
    tag := tree.col.txt.." "..p[2].." "..o(tree.cut)
    nodes(p[1], fn, lvl + 1, tag)

-- Print tree to console.
show := fun(tree):
  fn := fun(node, lvl, pre):
    p := lvl == 0 and "" or ("|   "):rep(lvl-1)..pre
    io.write(fmt(
      "%-"..the.Show.."s ,%5.2f ,(%3d),  %s\n",
      p, o(mid(node.y)),
      node.y.n, o(node.mids)))
  nodes(tree, fn)

-- ## Stats
-- Cliff's delta (bisect-optimized).
cliffsDelta := fun(xs, ys):
  n, m := #xs, #ys
  ngt, nlt := 0, 0
  for _,v in ipairs(xs):
    ngt = ngt + bisect(ys, v)
    nlt = nlt + (m - bisect(ys, v + 1e-32))
  !abs(ngt - nlt) / (n * m)

-- Kolmogorov-Smirnov: max CDF gap.
ks := fun(xs, ys):
  n, m := #xs, #ys
  d := 0
  gap := fun(v):
           a := bisect(xs, v) / n
           b := bisect(ys, v) / m
           !abs(a - b)
  for _,v in ipairs(xs): d = max(d, gap(v))
  for _,v in ipairs(ys): d = max(d, gap(v))
  !d

-- Same? Cohen's d gate, then Cliff, then KS.
same := fun(xs, ys, eps):
  xs, ys = sort(xs), sort(ys)
  n, m := #xs, #ys
  mx := xs[n // 2 + 1]
  my := ys[m // 2 + 1]
  if (abs(mx - my) <= eps): !true end
  if (cliffsDelta(xs, ys) > the.cliffs): !false end
  !ks(xs, ys) <= the.ksconf * ((n+m) / (n*m)) ^ 0.5

-- Group results into top-tier ranks.
bestRanks := fun(dict):
  out := {}
  names := [k for k,_ in pairs(dict)]
  cmp := fun(a,b): !mid(adds(dict[a])) < mid(adds(dict[b]))
  sort(names, cmp)
  eps := spread(adds(dict[names[1]])) * the.eps
  rows := dict[names[1]]
  out[names[1]] = adds(rows, Num(names[1]))
  for n= 2, #names do
    if (same(rows, dict[names[n]], eps)):
      out[names[n]] = adds(rows, Num(names[n]))
    else:
      break
  !out

-- ## Examples
_asserts := 0
eq := fun(a, b, msg):
  if (a == b):
    _asserts = _asserts + 1
  else:
    error(msg.." want "..tostring(b).." got "..tostring(a))

eg := {}

eg["-h"]   = fun(): print(help)
eg["--the"]= fun(): print(o(the))

eg["--all"]= fun():
  ss := [k for k,_ in pairs(eg) if k ~= "--all"]
  for _,k in ipairs(sort(ss)):
    print("\n"..k)
    randomseed(the.seed)
    eg[k]()
  print("\nasserts passed: ".._asserts)

eg["--csv"]= fun():
  n := 0
  for r in csv(the.f):
    if (n % 30 == 0): print(o(r)) end
    n = n + 1

eg["--ranks"]= fun():
  dict := {}
  for n= 1, 20 do
    name := "t"..n
    dict[name] = {}
    k      := (n <= 5 and 2 or 1)
    lambda := (n <= 5 and 10 or 20)
    for _= 1, 50 do push(dict[name], weibull(k, lambda)) end
  print("\nTop Tier Treatments:")
  u := sort([x for _,x in pairs(bestRanks(dict))],
            fun(a,b): !a.mu < b.mu end)
  for _,num in ipairs(u):
    print(fmt("%-5s median: %5.2f", num.txt, mid(num)))

eg["--data"]= fun():
  data := Data(the.f)
  for _,col in ipairs(data.cols.y):
    print(col.txt, o(mid(col)))

eg["--tree"]= fun():
  data := Data(the.f)
  rs := slice(shuffle(data.rows), 1, the.Budget)
  data = clone(data, rs)
  show(build(Tree(fun(r): !disty(data, r) end),
             data, data.rows))

eg["--test"]= fun():
  data := Data(the.f)
  stats := Num("win")
  if (not data.cols): return end
  fn_win := wins(data)
  for _= 1, 20 do
    shuffle(data.rows)
    n := #data.rows // 2
    test := slice(data.rows, n + 1)
    d2 := clone(data, slice(data.rows, 1, min(n, the.Budget)))
    tree := build(Tree(fun(r): !disty(d2, r) end), d2, d2.rows)
    f_leaf  := fun(a,b): !mid(leaf(tree,a).y) < mid(leaf(tree,b).y)
    f_dist2 := fun(a,b): !disty(d2,a) < disty(d2,b)
    sort(test, f_leaf)
    top := sort(slice(test, 1, the.Check), f_dist2)
    add(stats, fn_win(top[1]))
  print(o(floor(mid(stats))))

eg["--testNum"]= fun():
  num := adds({1,2,3,4,5})
  eq(mid(num), 3, "Num mid")
  eq(floor(spread(num)*100), 158, "Num spread")

eg["--testSym"]= fun():
  sym := Sym()
  for _,v in pairs{"a","a","a","b","b","c"}: add(sym,v)
  eq(mid(sym), "a", "Sym mode")
  eq(sym.has["a"], 3, "Sym count a")

eg["--testTree"]= fun():
  data := Data(the.f)
  tree := build(Tree(fun(r): !disty(data, r) end),
                data, slice(data.rows, 1, 50))
  eq(type(tree.col), "table", "tree root has split col")

eg["--testStat"]= fun():
  randomseed(the.seed)
  mk := fun(k,lambda):
          xs := {}
          for _=1,50 do push(xs, weibull(k,lambda)) end
          !xs
  a, b, c := mk(2,10), mk(2,10), mk(1,20)
  eps := spread(adds(a)) * the.eps
  eq(same(a, b, eps), true,  "same dist -> same=true")
  eq(same(a, c, eps), false, "diff dist -> same=false")

-- ## Main
for k,v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)"): the[k]= thing(v) end

main := fun():
  n := 1
  while (n <= #arg):
    k := arg[n]
    v := arg[n+1]
    n = n + 1
    if (eg[k]):
      randomseed(the.seed)
      eg[k]()
    else:
      for k1 in pairs(the):
        if (k == "-"..k1:sub(1,1)):
          the[k1] = thing(v)
          n = n + 1

if ((arg[0] or ""):match"ezr%.fun"): main() end

rogues()

!{the=the, Num=Num, Sym=Sym, Data=Data, Tree=Tree,
  add=add, adds=adds, clone=clone,
  mid=mid, spread=spread, norm=norm, mids=mids,
  disty=disty, wins=wins,
  build=build, leaf=leaf, nodes=nodes, show=show,
  split=split, treeCuts=treeCuts,
  same=same, ks=ks, cliffsDelta=cliffsDelta,
  bestRanks=bestRanks,
  push=push, sort=sort, slice=slice, sum=sum,
  csv=csv, shuffle=shuffle, bisect=bisect,
  o=o, thing=thing, weibull=weibull,
  NUM=NUM, SYM=SYM, COLS=COLS, DATA=DATA, TREE=TREE}
