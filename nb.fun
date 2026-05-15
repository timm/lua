#!/usr/bin/env fun
-- vim: ft=fun
the, help := {}, [[
nb.fun: naive bayes classifier
(c) 2026, Tim Menzies, MIT license.

USAGE
   ./fun nb.fun [OPTIONS] [FILE]

DESCRIPTION
    Incremental bayes. Training and testing are interleaved: after
    burn-in, each row is classified then added to the training set.

OPTIONS
    -h          Show help.
    -k k=1      Bayes low frequency hack for symbolic attributes.
    -m m=2      Bayes low frequency hack for class priors.
    -w wait=5   Start classifying after seeing "some" rows.
    -f f=auto93.csv  default CSV input.

EXAMPLES
    --the       Print config settings.
    --sym       Test symbolic column.
    --num       Test numeric column.
    --col       Test column creation.
    --cols      Test column set creation.
    --data      Load data, print first y column.
    --like      Test likelihood calculations.
    --likes     Test row likelihood.
    --nb        Run naive bayes on CSV file.
    --all       Run every demo + asserts.
]]

-- Math + string shortcuts.
sqrt, exp, log, max, min, abs, pi, floor :=
  math.sqrt, math.exp, math.log, math.max, math.min, math.abs, math.pi, math.floor
fmt, mtype := string.format, math.type
BIG := 1E32

-- Type markers.
NUM, SYM, COLS, DATA := "Num", "Sym", "Cols", "Data"

-- Forward refs.
let push, csv, add, o

-- Snapshot global names before our code adds any.
b4 := {}
for k,_ in pairs(_ENV): b4[k] = true

-- ## Classes
-- Numeric column.
Num := fun(at, txt):
  !{is=NUM, at=at or 0, txt=txt or "",
    n=0, mu=0, m2=0, sd=0}

-- Symbolic (categorical) column.
Sym := fun(at, txt):
  !{is=SYM, at=at or 0, txt=txt or "",
    n=0, has={}}

-- Column factory: uppercase first letter → Num, else Sym.
Col := fun(at, txt):
  !(txt:find"^[A-Z]" and Num or Sym)(at, txt)

-- Names list -> column groups (x = independent, y = class).
Cols := fun(names):
  all := {}
  for at,txt in ipairs(names): push(all, Col(at, txt))
  xs, ys := {}, {}
  for _,c in ipairs(all):
    if (not c.txt:find"[!X]$"): push(xs, c)
    if (c.txt:find"!$"): push(ys, c)
  !{is=COLS, names=names, all=all, x=xs, y=ys}

-- Data container: rows + summarized columns.
Data := fun(txt, src):
  data := {is=DATA, txt=txt or "", rows={}, cols=nil}
  if (src):
    for row in src: add(data, row)
  !data

-- ## Library
-- Push.
push = fun(t, x): t[1+#t] = x; !x

-- Sort in-place; return it.
sort := fun(t, f): table.sort(t, f); !t

-- Percentage as rounded int.
pct := fun(x, y): !floor(100 * x / (y + 1e-32) + 0.5)

-- Slice t[lo..hi].
slice := fun(t, lo, hi):
  u := {}
  for i = (lo or 1), (hi or #t):
    u[1+#u] = t[i]
  !u

-- Fisher-Yates shuffle in-place.
shuffle := fun(t):
  for i = #t, 2, -1:
    j := math.random(i)
    t[i], t[j] = t[j], t[i]
  !t

-- Sum f(x) over table.
sum := fun(t, f):
  n := 0
  for _,x in ipairs(t): n += f(x)
  !n

-- Pretty-print.
o = fun(x):
  if (type(x) ~= "table"):
    if (mtype(x) == "float"): !("%.2f"):format(x) end
    !tostring(x)
  u := {}
  for k,v in pairs(x):
    s := type(k) == "number" and o(v) or k.."="..o(v)
    u[1+#u] = s
  !"{"..table.concat(sort(u), ", ").."}"

-- Coerce string to bool/number/string.
thing := fun(s):
  !s == "true" or (s ~= "false" and (tonumber(s) or s))

-- CSV iterator (returns coroutine-style function).
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

-- Find key whose fn(k, v) returns max value.
most := fun(t, f):
  best_k, best_v := nil, -BIG
  for k,v in pairs(t):
    score := f(k, v)
    if (score > best_v): best_k, best_v = k, score
  !best_k

-- Report rogue globals.
rogues := fun():
  for k,_ in pairs(_ENV):
    if (not b4[k] and k:match"^[a-z]"):
      print("rogue: "..k)

-- ## Update
_num := fun(num, v):
  if (v == "?"): !nil
  num.n += 1
  d := v - num.mu
  num.mu += d / num.n
  num.m2 += d * (v - num.mu)
  num.sd = num.n < 2 and 0 or sqrt(num.m2/(num.n - 1))

_sym := fun(sym, v):
  if (v == "?"): !nil
  sym.n += 1
  sym.has[v] = 1 + (sym.has[v] or 0)

_cols := fun(cols, row):
  for _,col in ipairs(cols.all): add(col, row[col.at])

_data := fun(data, row):
  if (not data.cols):
    data.cols = Cols(row)
  else:
    push(data.rows, row)
    _cols(data.cols, row)

add = fun(it, v):
  if (it.is == DATA): _data(it, v); !v
  if (it.is == COLS): _cols(it, v); !v
  if (it.is == SYM):  _sym(it, v);  !v
  _num(it, v)
  !v

-- Bulk add (default new Num).
adds := fun(items, num):
  num ?= Num()
  if (items):
    for _,v in ipairs(items): add(num, v)
  !num

-- Clone: empty Data with same column structure.
clone := fun(data, rows):
  d := Data(data.txt, nil)
  add(d, data.cols.names)
  if (rows):
    for _,r in ipairs(rows): add(d, r)
  !d

-- ### Bayes
-- Symbolic likelihood: (count + k*prior) / (n + k).
SYM_like := fun(sym, v, prior):
  n := (sym.has[v] or 0) + the.k * (prior or 0)
  !max(1/BIG, n / (sym.n + the.k + 1/BIG))

-- Numeric likelihood: Gaussian.
NUM_like := fun(num, v):
  z := 1/BIG
  var := num.sd^2 + z
  !(1 / sqrt(2 * pi * var)) * exp(-((v - num.mu)^2) / (2 * var))

-- Likelihood dispatch.
like := fun(col, v, prior):
  if (col.is == SYM): !SYM_like(col, v, prior)
  !NUM_like(col, v)

-- Log-likelihood of row given a class data table.
likes := fun(data, row, nall, nh):
  b := (#data.rows + the.m) / (nall + the.m * nh)
  s := sum(data.cols.x, fun(c):
             v := row[c.at]
             !v == "?" and 0 or log(like(c, v, b))
           end)
  !log(b) + s

-- Naive Bayes: online classify-then-train. Returns confusion matrix.
nb := fun(data):
  klasses, cm := {}, {}
  n, nk := 0, 0
  klassAt := data.cols.y[1].at
  for _,row in ipairs(data.rows):
    want := row[klassAt]
    if (not klasses[want]):
      nk += 1
      klasses[want] = clone(data)
      klasses[want].txt = want
      cm[want] = {}
    if (n > the.wait):
      got := most(klasses, fun(_,d): !likes(d, row, n, nk) end)
      if (got):
        cm[want][got] = 1 + (cm[want][got] or 0)
    n += 1
    add(klasses[want], row)
  !cm

-- ## Stats (Cliff's delta, KS, same; used by rankPrint)
-- Bisect: rightmost index where t[i] <= x.
bisect := fun(t, x):
  lo, hi := 1, #t
  while (lo <= hi):
    m := (lo + hi) // 2
    if (t[m] <= x):
      lo = m + 1
    else:
      hi = m - 1
  !lo - 1

cliffsDelta := fun(xs, ys):
  n, m := #xs, #ys
  ngt, nlt := 0, 0
  for _,v in ipairs(xs):
    ngt += bisect(ys, v)
    nlt += (m - bisect(ys, v + 1e-32))
  !abs(ngt - nlt) / (n * m)

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

same := fun(xs, ys, eps):
  xs, ys = sort(xs), sort(ys)
  n, m := #xs, #ys
  mx := xs[n // 2 + 1]
  my := ys[m // 2 + 1]
  if (abs(mx - my) <= eps): !true end
  if (cliffsDelta(xs, ys) > 0.195): !false end
  !ks(xs, ys) <= 1.36 * ((n + m) / (n * m)) ^ 0.5

-- Group treatments by statistical rank. dict[name] = list of scores.
-- rank 1 = best lead + treatments `same` as it (pooled-sd eps).
-- rank 2 = first treatment NOT same as rank-1 lead + same-as-IT.
-- Returns list of {name, num, rank} sorted by mu desc.
sames := fun(dict):
  names := [k for k,_ in pairs(dict)]
  nums  := {}
  for _,nm in ipairs(names): nums[nm] = adds(dict[nm], Num())
  sort(names, fun(a,b): !nums[a].mu > nums[b].mu end)
  out := {}
  rank := 1
  lead := names[1]
  for _,nm in ipairs(names):
    if (nm ~= lead):
      sdPool := sqrt((nums[lead].sd^2 + nums[nm].sd^2) / 2)
      eps    := max(sdPool * 0.35, 1)
      if (not same(dict[lead], dict[nm], eps)):
        rank += 1
        lead = nm
    push(out, {name=nm, num=nums[nm], rank=rank})
  !out

-- Build list of per-class stat rows from a confusion matrix.
-- Returns: [{class, n, tn, fn, fp, tp, pd, pf, prec, acc}, ...]
-- All percentages as rounded ints (0..100).
stats := fun(cm):
  n := 0
  for _, gs in pairs(cm):
    for _, c in pairs(gs): n += c
  rows := {}
  for pos,_ in pairs(cm):
    tp := (cm[pos] or {})[pos] or 0
    fp, fn := 0, 0
    for w, gs in pairs(cm):
      for g, c in pairs(gs):
        if w == pos and g ~= pos: fn += c end
        if w ~= pos and g == pos: fp += c end
    tn := n - tp - fp - fn
    -- G-score: harmonic mean of recall (pd) and specificity (1-pf).
    rec  := tp / (tp + fn + 1e-32)
    spec := tn / (tn + fp + 1e-32)
    g    := 2 * rec * spec / (rec + spec + 1e-32)
    row  := {class=tostring(pos), n=n,
             tn=tn, fn=fn, fp=fp, tp=tp,
             pd  =pct(tp,    tp+fn),
             pf  =pct(fp,    fp+tn),
             prec=pct(tp,    tp+fp),
             acc =pct(tp+tn, n),
             g   =floor(100*g + 0.5)}
    push(rows, row)
    rows[tostring(pos)] = row  -- also key by class for O(1) lookup
  !rows

-- Pretty-print stat rows.
HDR := "%4s, %4s, %4s, %4s, %4s,  %3s, %3s, %3s, %3s, %3s,  %s"
ROW := "%4d, %4d, %4d, %4d, %4d,  %3d, %3d, %3d, %3d, %3d,  %s"
printStats := fun(rows):
  print(fmt(HDR, "n","tn","fn","fp","tp","pd","pf","prec","acc","g","class"))
  for _,r in ipairs(rows):
    print(fmt(ROW, r.n, r.tn, r.fn, r.fp, r.tp,
              r.pd, r.pf, r.prec, r.acc, r.g, r.class))



-- ## Examples
_asserts := 0
eq := fun(a, b, msg):
  if (a == b):
    _asserts += 1
  else:
    error(msg.." want "..tostring(b).." got "..tostring(a))

eg := {}

eg["--testSym"]= fun():
  s := adds({"a","a","a","b","b","c"}, Sym())
  eq(s.n, 6, "Sym n")
  eq(s.has["a"], 3, "Sym a count")

eg["--testNum"]= fun():
  n := adds({1,2,3,4,5})
  eq(n.n, 5, "Num n")
  eq(n.mu, 3, "Num mu")

eg["--testLike"]= fun():
  s := adds({"a","a","a","b","c"}, Sym())
  p := SYM_like(s, "a", 0.5)
  eq(p > 0 and p <= 1, true, "SYM_like in (0,1]")

eg["-h"]   = fun(): print("\n"..help)
eg["--the"]= fun(): print(o(the))

eg["--sym"]= fun():
  s := adds({"a","a","a","b","c"}, Sym())
  print(o(s))

eg["--num"]= fun():
  n := adds({10,20,30,40})
  print(o(n))

eg["--col"]= fun():
  print(o(Col(1, "Age")), o(Col(2, "name")))

eg["--cols"]= fun():
  cs := Cols({"Name","Age","Weight-","Class!"})
  print(o(cs.y))

eg["--data"]= fun():
  d := Data("", csv(the.f))
  print(o(d.cols.y[1]))

eg["--like"]= fun():
  num := adds({10,20,30,40,50})
  sym := adds({"a","a","a","b","c"}, Sym())
  print(NUM_like(num, 30), SYM_like(sym, "a", 0.5))

eg["--likes"]= fun():
  d := Data("", csv(the.f))
  print(likes(d, d.rows[1], #d.rows, 2))

-- Print ranked treatments. Blank line between rank groups.
rankPrint := fun(dict):
  print(fmt("  %4s  %-12s  %6s  %6s", "rank", "treatment", "mu", "sd"))
  prev := 0
  for _,r in ipairs(sames(dict)):
    if (r.rank ~= prev and prev > 0): print("") end
    prev = r.rank
    print(fmt("  %4d  %-12s  %6.2f  %6.2f",
              r.rank, r.name, r.num.mu, r.num.sd))

eg["--experiment"]= fun():
  data := Data("", csv(the.f))
  N    := #data.rows
  -- Pick a "critical class" by filename. Fallback: first class seen.
  target := the.f:find"soybean"  and "phytophthora-rot"
         or the.f:find"diabetes" and "tested_positive"
         or nil
  dict := {}
  for _,n in ipairs({50, 100, 200, N}):
    for k = 0, 2:
      for m = 0, 2:
        nm := fmt("n=%3d,k=%d,m=%d", min(n,N), k, m)
        dict[nm] = {}
        for trial = 1, 20:
          the.k, the.m = k, m
          rs  := slice(shuffle(slice(data.rows)), 1, min(n,N))
          row := stats(nb(clone(data, rs)))[target]
          push(dict[nm], row and row.g or 0)
  print(fmt("\nG-score on '%s' (rank 1 = top tier):", tostring(target)))
  rankPrint(dict)

eg["--nb"]= fun():
  printStats(stats(nb(Data("", csv(the.f)))))

eg["--soybean"]= fun():
  printStats(stats(nb(Data("", csv("soybean.csv")))))

eg["--diabetes"]= fun():
  printStats(stats(nb(Data("", csv("diabetes.csv")))))

eg["--all"]= fun():
  skip := {["--all"]=1, ["--nb"]=1, ["--experiment"]=1}
  ss := [k for k,_ in pairs(eg) if not skip[k]]
  for _,k in ipairs(sort(ss)):
    print("\n"..k)
    eg[k]()
  print("\nasserts passed: ".._asserts)

-- ## Main
-- Fill `the` from help string defaults.
for k,v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)"): the[k]= thing(v) end

main := fun():
  n := 1
  while (n <= #arg):
    k := arg[n]
    v := arg[n+1]
    n += 1
    if (eg[k]):
      eg[k]()
    else:
      for k1 in pairs(the):
        if (k == "-"..k1:sub(1,1)):
          the[k1] = thing(v)
          n += 1

if ((arg[0] or ""):match"nb%.fun"): main() end

rogues()

!{the=the, Num=Num, Sym=Sym, Data=Data, Cols=Cols, Col=Col,
  add=add, adds=adds, clone=clone,
  like=like, likes=likes, nb=nb,
  o=o, push=push, sort=sort, sum=sum, csv=csv,
  NUM=NUM, SYM=SYM, COLS=COLS, DATA=DATA}
