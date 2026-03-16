#!/usr/bin/env python3 -B
"""
ez.py: explainable multi-objective optimization
(c) 2026 Tim Menzies timm@ieee.org, MIT license

Usage:

    ./ez.py [OPTIONS] [ARGS]

Options:

    -h                        show help
    --seed=1                  random number seed
    --p=2                     Minkowski coefficient (1 Manhattan, 2 Euclidean)
    --learn.Any=4             initial sample size
    --learn.Budget=50         training evaluation budget
    --learn.Check=5           testing evaluation budget
    --learn.Few=128           search space for new rows
    --learn.leaf=3            min rows per tree leaf
    --learn.bins=7            discretize into this many bins
    --bayes.k=1               low value frequency smoothing
    --bayes.m=2               low class frequency smoothing
    --num.Keep=256            reservoir size for Nums
    --stats.cliffs=0.195      Cliff's Delta threshold
    --stats.conf=1.36         KS test confidence
    --stats.eps=0.35          margin of error multiplier
    --show.Show=30            tree display width
    --show.decs=2             float decimal places
    --text.Norm=0             CNB weight normalization (0/1)
    --text.yes=20             positive samples for text mining
    --text.no=20              negative samples for text mining
    --text.Top=100            top TF-IDF features to keep
    --text.valid=20           repeats for statistical testing
    --see   file              see: show tree (rung 1)
    --act   file              act: test vs leaf (rung 2)
    --imagine file            imagine: what-if (rung 3)
    --test  file              run full train/predict/score pipeline
    --all   file              run all tests/examples using csv file

Input is CSV. Header (row 1) defines column roles as follows:

    [A-Z]* : Numeric        [a-z]* : Symbolic
    *+     : Maximize        *-     : Minimize
    *!     : Class label     *X     : Ignore
    ?      : Missing value

Analytics via Pearl's ladder of causation:

    |          | See            | Act            | Imagine          |
    |          | Rung 1:        | Rung 2:        | Rung 3:          |
    |          | association    | intervention   | counterfactual   |
    |----------|----------------|----------------|------------------|
    | Find     | Trends         | Alerts         | Forecasting      |
    | Explain  | Summarize      | Compare        | Root cause       |
    | Compare  | Model          | Benchmark      | Simulate         |
    |----------|----------------|----------------|------------------|
    | Source   | training set   | test set       | perturbed test   |
    | Code     | build(d, rs)   | leaf(t, r)     | whatif(t,r,at,v) |
    | Example  | see eg_see     | see eg_act     | see eg_imagine   |
"""
import random, sys, re
from math import log, exp, sqrt, pi
from random import random as r, choice
from bisect import insort, bisect_left, bisect_right
from typing import Iterable
from types import SimpleNamespace as o
from pathlib import Path

BIG = 1E32
Qty = int | float
Val = Qty | bool | str
Row = list[Val]
Col = "Num | Sym"

# --- Sym --------------------------------------------------------
class Sym(dict):
  def add(i, v):
    if v != "?": i[v] = i.get(v,0) + 1
    return v
  def sub(i, v):
    if v != "?": i[v] = i.get(v,0) - 1
    return v
  def mid(i):    return max(i, key=i.get)
  def spread(i):
    n = sum(i.values())
    return -sum(p*log(p,2) for k in i if (p:=i[k]/n) > 0)
  def norm(i, v):    return v
  def distx(i, u, v): return int(u != v)
  def pick(i, _=None): return wpick(i)
  def like(i, v, prior=0):
    n = sum(i.values())
    return max(1/BIG, (i.get(v,0) + the.bayes.k*prior) / (n + the.bayes.k))

# --- Num --------------------------------------------------------
class Num(list):
  __repr__ = lambda i: str([say(v) for v in i])
  def __init__(i, mx=None):
    super().__init__(); i.mx = mx or the.num.Keep; i.seen = 0
  def add(i, v):
    if v != "?":
      i.seen += 1
      if   len(i) < i.mx: insort(i, v)
      elif r() < i.mx/i.seen: i.pop(int(r()*len(i))); insort(i, v)
    return v
  def sub(i, v):
    if v != "?":
      i.seen -= 1
      if (p := bisect_left(i,v)) < len(i) and i[p]==v: i.pop(p)
    return v
  def mid(i):    return i[len(i)//2] if i else 0
  def spread(i):
    if len(i) < 2: return 0
    n = max(1, len(i)//10)
    return (i[min(9*n, len(i)-1)] - i[min(n, len(i)-1)]) / 2.56
  def norm(i, v):
    if v == "?" or len(i) < 2: return v
    a, b = i[int(.05*len(i))], i[int(.95*len(i))]
    return 0 if a == b else max(0, min(1, (v-a)/(b-a)))
  def pick(i, v=None):
    result = (i.mid() if v is None or v == "?" else v) + choice(i) - choice(i)
    lo, hi = i[0], i[-1]
    return lo + ((result - lo) % (hi - lo + 1e-32))
  def distx(i, u, v):
    if u == v == "?": return 1
    u, v = i.norm(u), i.norm(v)
    u = u if u != "?" else (0 if v > 0.5 else 1)
    v = v if v != "?" else (0 if u > 0.5 else 1)
    return abs(u - v)
  def like(i, v, prior=0):
    s = i.spread() + 1/BIG
    return (1/sqrt(2*pi*s*s)) * exp(-((v - i.mid())**2) / (2*s*s))

# --- Cols -------------------------------------------------------
def col(s): return (Num if s[0].isupper() else Sym)()

class Cols:
  __repr__ = lambda i: str(i.names)
  def __init__(i, names):
    i.names = names
    i.all   = {at: col(s) for at,s in enumerate(names)}
    i.w     = {at: s[-1]!="-" for at,s in enumerate(names) if s[-1] in "-+!"}
    i.x     = {at:c for at,c in i.all.items() if at not in i.w and names[at][-1]!="X"}
    i.y     = {at: i.all[at] for at in i.w}
    i.klass = next((at for at,s in enumerate(names) if s[-1]=="!"), None)

# --- Data -------------------------------------------------------
class Data:
  def __init__(i, items):
    i.rows = []; i._mid = None
    i.cols = Cols(next(items := iter(items)))
    [i.add(row) for row in items]
  def add(i, row):
    i._mid = None
    for at,c in i.cols.all.items(): c.add(row[at])
    i.rows.append(row); return row
  def sub(i, row):
    i._mid = None
    for at,c in i.cols.all.items(): c.sub(row[at])
    i.rows.remove(row); return row
  def mid(i):
    i._mid = i._mid or [c.mid() for c in i.cols.all.values()]
    return i._mid
  def like(i, row, n_all, n_h):
    prior = (len(i.rows)+the.bayes.m) / (n_all+the.bayes.m*n_h)
    ls = [c.like(v,prior) for at,c in i.cols.x.items() if (v:=row[at])!="?"]
    return log(prior) + sum(log(v) for v in ls if v > 0)
  def distx(i, r1, r2):
    return minkowski(c.distx(r1[at],r2[at]) for at,c in i.cols.x.items())
  def disty(i, r):
    return minkowski(abs(c.norm(r[at]) - i.cols.w[at]) for at,c in i.cols.y.items())
  def sorty(i):
    i.rows.sort(key=lambda row: i.disty(row)); return i
  def sortx(i, r, rows):   return sorted(rows, key=lambda r2: i.distx(r,r2))
  def nearest(i, r, rows): return i.sortx(r,rows)[0]
  def pick(i, row=None, n=1):
    if not row: return [c.pick() for c in i.cols.all.values()]
    s, k = row[:], n if n > 0 else len(i.cols.x)
    for at,c in random.sample(list(i.cols.x.items()), min(k, len(i.cols.x))):
      s[at] = c.pick(s[at])
    return s

# --- Lib --------------------------------------------------------
def say(x, w=None):
  if type(x)==float: x = int(x) if int(x)==x else f"{x:.{the.show.decs}f}"
  elif isinstance(x,dict): x = {k: say(x[k]) for k in x}
  return f"{x:>{w}}" if w else x

def says(lst, w=None): print(*[say(x,w) for x in lst])

def adds(items, col=None):
  col = col or Num()
  [col.add(v) for v in items]; return col

def minkowski(items):
  n = d = 0
  for x in items: n, d = n+1, d + x**the.p
  return 0 if n == 0 else (d/n)**(1/the.p)

def wpick(d):
  n = sum(d.values()) * r()
  for k,v in d.items():
    if (n := n-v) <= 0: return k

def shuffle(lst): random.shuffle(lst); return lst

def cast(s):
  for f in [int, float, lambda s: {"true":1,"false":0}.get(s.lower(),s)]:
    try: return f(s)
    except ValueError: pass

def csv(f, clean=lambda s: s.partition("#")[0].split(",")):
  with open(f, encoding="utf-8") as file:
    for s in file:
      row = clean(s)
      if any(x.strip() for x in row):
        yield [cast(x.strip()) for x in row]

def align(m):
  m  = [[str(say(x)) for x in row] for row in m]
  ws = [max(len(x) for x in column) for column in zip(*m)]
  for row in m: print(", ".join(f"{v:>{w}}" for v,w in zip(row,ws)))

def clone(d, rs=None): return Data([d.cols.names] + (rs or []))

def goals(d):
  return "{"+", ".join(f"{d.cols.names[at]}={say(c.mid())}"
         for at,c in d.cols.y.items())+"}"

def wins(d):
  ds = [d.disty(r) for r in d.rows]
  lo, med = min(ds), sorted(ds)[len(ds)//2]
  return lambda r: int(100*(1 - ((d.disty(r)-lo) / (med-lo+1e-32))))

def scoresy(d, rs): return adds((d.disty(r) for r in rs), Num(BIG))

def ready(src):
  """Shuffle, split train/test, build tree. Accepts filename or Data."""
  d = src if isinstance(src, Data) else Data(csv(src))
  shuffle(d.rows)
  n = len(d.rows) // 2
  train = d.rows[:n][:the.learn.Budget]
  d2 = clone(d, train)
  return d, d2, build(d2, d2.rows), d.rows[n:]

def posint(s): assert (v:=int(s)) >= 0, f"{s} not a posint"; return v

def filename(s): assert Path(s).is_file(), f"unknown file {s}"; return s

def set_dot(t, k, v):
  """Set value in nested namespace via dot notation."""
  for x in (ks := k.split("."))[:-1]:
    t = t.__dict__.setdefault(x, o())
  setattr(t, ks[-1], v)

def setup(s):
  out = o()
  for k, v in re.findall(r"([\w.]+)=(\S+)", s): set_dot(out, k, cast(v))
  return out

def cli(fns):
  """Execute functions or update config via CLI arguments."""
  args = sys.argv[1:]
  while args:
    random.seed(the.seed)
    k = re.sub(r"^-+", "", args.pop(0))
    if fn := fns.get(f"eg_{k}"):
      fn(*[make(args.pop(0)) for make in fn.__annotations__.values()])
    else:
      set_dot(the, k, cast(args.pop(0)))

# --- Stats ------------------------------------------------------
def same(xs, ys, eps):
  """Effect size (Cliff's delta) + KS test."""
  xs, ys = sorted(xs), sorted(ys)
  n, m = len(xs), len(ys)
  if abs(xs[n//2] - ys[m//2]) <= eps: return True
  gt = lt = 0
  for a in xs:
    gt += bisect_left(ys, a)
    lt += m - bisect_right(ys, a)
  if abs(gt - lt) / (n * m) > the.stats.cliffs: return False
  ks = lambda v: abs(bisect_right(xs,v)/n - bisect_right(ys,v)/m)
  return max(max(map(ks,xs)), max(map(ks,ys))) \
          <= the.stats.conf * ((n+m)/(n*m))**0.5

def bestRanks(d):
  """Sort treatments, find best statistical tier."""
  items = sorted(d.items(), key=lambda kv: sorted(kv[1])[len(kv[1])//2])
  k0, lst0 = items[0]
  n0 = adds(lst0, Num(BIG))
  best = {k0: n0}
  for k, lst in items[1:]:
    if same(lst0, lst, n0.spread() * the.stats.eps):
      best[k] = adds(lst, Num(BIG))
    else: break
  return best

class Confuse(dict): pass

def confuse(cf, actual, predicted):
  """Add one observation to a confusion matrix."""
  for k in [actual, predicted]:
    cf.setdefault(k, o(tp=0, fp=0, fn=0, tn=0))
  for k in cf:
    hit, got = k == actual, k == predicted
    if   hit and got:     cf[k].tp += 1
    elif hit and not got: cf[k].fn += 1
    elif not hit and got: cf[k].fp += 1
    else:                 cf[k].tn += 1

def confused(cf):
  """Per-class metrics from a confusion matrix."""
  out = []
  for k, v in cf.items():
    tp, fn, fp, tn = v.tp, v.fn, v.fp, v.tn
    out.append(o(label=k, tp=tp, fn=fn,
      pd=round(tp/(tp+fn+1e-32),2), pf=round(fp/(fp+tn+1e-32),2),
      prec=round(tp/(tp+fp+1e-32),2), acc=round((tp+tn)/(tp+fn+fp+tn+1e-32),2)))
  return out

# --- Tree -------------------------------------------------------
class Tree:
  def __init__(i, d, rs):
    i.d = clone(d, rs)
    i.y = scoresy(d, rs)
    i.at = i.txt = i.cut = i.L = i.R = None

def splits(at, c, rs, d):
  """Yield column cuts with left/right splits and weighted spread."""
  vs = [r[at] for r in rs if r[at] != "?"]
  if not vs: return
  cuts = set(vs) if isinstance(c, Sym) else [sorted(vs)[len(vs)//2]]
  for cut in cuts:
    lhs, rhs, L, R = Num(BIG), Num(BIG), [], []
    for r in rs:
      v = r[at]
      go = v == "?" or (v == cut if isinstance(c, Sym) else v <= cut)
      (L if go else R).append(r)
      (lhs if go else rhs).add(d.disty(r))
    yield cut, L, R, len(lhs)*lhs.spread() + len(rhs)*rhs.spread()

def build(d, rs):
  """Recursively build a decision tree by finding best splits."""
  t = Tree(d, rs)
  if len(rs) >= 2 * the.learn.leaf:
    bestW, best = BIG, None
    for at, c in t.d.cols.x.items():
      for cut, L, R, w in splits(at, c, rs, d):
        if min(len(L), len(R)) >= the.learn.leaf and w < bestW:
          bestW, best = w, (at, d.cols.names[at], cut, L, R)
    if best:
      t.at, t.txt, t.cut, L, R = best
      t.L, t.R = build(d, L), build(d, R)
  return t

def leaf(t, r):
  """Drop a row down the tree to find its matching leaf."""
  if not t.L: return t
  v = r[t.at]
  c = t.d.cols.all[t.at]
  go = v != "?" and (v <= t.cut if isinstance(c, Num) else v == t.cut)
  return leaf(t.L if go else t.R, r)

def whatif(t, r, at, val):
  """Counterfactual: clone row, force feature, re-route."""
  r2 = r[:]; r2[at] = val
  return leaf(t, r2)

def nodes(t, l=0, txt=None, op="", cut=None):
  """Yield tree nodes for traversal (sorted best to worst)."""
  yield t, l, txt, op, cut
  if t.at is not None:
    c = t.d.cols.all[t.at]
    ops = ("<=", ">") if isinstance(c, Num) else ("==", "!=")
    kids = [(k, op_s) for k, op_s in zip([t.L, t.R], ops) if k]
    for k, op_s in sorted(kids, key=lambda x: x[0].y.mid()):
      yield from nodes(k, l+1, t.txt, op_s, t.cut)

def showTree(t):
  """Print the decision tree to console."""
  for n, l, txt, op, cut in nodes(t):
    p = f"{txt} {op} {say(cut)}" if txt else ""
    print(f"{'|   '*(l-1)+p if l>0 else '':<{the.show.Show}}"
          f",{say(n.y.mid()):>4}"
          f" ,({len(n.y):3}), {goals(n.d)}")

# --- Cluster ----------------------------------------------------
def kmeans(d, rows=None, k=10, n=10, cents=None):
  """Vanilla k-means. Yields (error, clusters) per iteration."""
  rows  = rows or d.rows
  cents = cents or random.choices(rows, k=k)
  for _ in range(n):
    kids = [Data([d.cols.names]) for _ in cents]
    err  = 0
    for r in rows:
      j = min(range(len(cents)), key=lambda j: d.distx(cents[j], r))
      err += d.distx(cents[j], r)
      kids[j].add(r)
    yield err/len(rows), kids
    cents = [choice(c.rows) for c in kids if c.rows]

def kpp(d, rows=None, k=10, few=256):
  """K-means++ seeding: pick diverse centroids."""
  rows = rows or d.rows
  out  = [choice(rows)]
  while len(out) < k:
    tmp  = random.sample(rows, min(few, len(rows)))
    out += [tmp[wpick({i: min(d.distx(r,c)**2 for c in out)
                       for i,r in enumerate(tmp)})]]
  return out

def fastmeans(d, rows=None, min_leaf=None):
  """Recursive projection-based bisection clustering."""
  rows = rows or d.rows
  min_leaf = min_leaf or the.learn.leaf
  if len(rows) < 2 * min_leaf:
    yield rows
  else:
    pairs = [(choice(rows), choice(rows)) for _ in range(20)]
    a, b  = max(pairs, key=lambda ab: d.distx(ab[0], ab[1]))
    c     = d.distx(a, b) + 1e-32
    proj  = lambda r: (d.distx(a,r)**2 + c**2 - d.distx(b,r)**2) / (2*c)
    ps    = sorted(rows, key=proj)
    mid   = len(ps) // 2
    yield from fastmeans(d, ps[:mid], min_leaf)
    yield from fastmeans(d, ps[mid:], min_leaf)

# --- Search -----------------------------------------------------
def nn_surrogate(d):
  """Default surrogate: nearest-neighbor in training data."""
  def fn(r):
    near = d.nearest(r, d.rows)
    for at in d.cols.y: r[at] = near[at]
    return d.disty(r)
  return fn

def oneplus1(d, mutator, accept, b=1000, restarts=0, surrogate=None):
  """(1+1) evolutionary search with pluggable surrogate."""
  score = surrogate or nn_surrogate(d)
  h, best, best_e = 0, None, BIG
  s, e, last_imp = choice(d.rows)[:], BIG, 0
  while True:
    if h >= b: return
    for sn in mutator(s):
      h += 1
      en = score(sn)
      if accept(e, en, h, b): s, e = sn, en
      if en < best_e:
        best, best_e = sn[:], en
        last_imp = h
        yield h, best_e, best
      if restarts and h - last_imp > restarts:
        s, e, last_imp = choice(d.rows)[:], BIG, h
        break

def sa(d, restarts=0, m=0.5, b=1000, **kw):
  """Simulated annealing (thin wrapper around oneplus1)."""
  def accept(e, en, h, b): return en < e or r() < exp((e-en)/(1-h/b+1e-32))
  def mutate(s): yield d.pick(s, n=max(1, int(m*len(d.cols.x))))
  return oneplus1(d, mutate, accept, b, restarts, **kw)

def ls(d, restarts=100, p=0.5, n=20, b=1000, **kw):
  """Local search (thin wrapper around oneplus1)."""
  def accept(e, en, *_): return en < e
  def mutate(s):
    at, c = choice(list(d.cols.x.items()))
    for _ in range(n if r() < p else 1):
      s = s[:]; s[at] = c.pick(s[at]); yield s
  return oneplus1(d, mutate, accept, b, restarts, **kw)

# --- Acquire ----------------------------------------------------
def nearer(seen, best, rest, r):
  return seen.distx(best.mid(), r) - seen.distx(rest.mid(), r)

def likelier(seen, best, rest, r):
  return rest.like(r, len(seen.rows), 2) - best.like(r, len(seen.rows), 2)

def acquire(seen, best, rest, unseen, scorer=nearer, eager=True):
  """Pick next row to label from unseen pool."""
  if eager:
    return min(unseen.rows, key=lambda r: scorer(seen, best, rest, r))
  for _ in range(len(unseen.rows)):
    row = choice(unseen.rows)
    if scorer(seen, best, rest, row) < 0: break
  return row

def guess(d, rows, Any=None, Budget=None, scorer=nearer,
          eager=True, label=lambda r:r):
  """Active learning loop: seed, then iteratively acquire."""
  Any    = Any or the.learn.Any
  Budget = Budget or the.learn.Budget
  rows   = shuffle(rows[:])
  unseen = clone(d, rows[Any:][:the.learn.Few])
  seen   = clone(d, rows[:Any]).sorty()
  n      = round(sqrt(Any))
  best   = clone(d, seen.rows[:n])
  rest   = clone(d, seen.rows[n:])
  while len(unseen.rows) > 2 and len(seen.rows) < Budget:
    seen.add(best.add(label(unseen.sub(
      acquire(seen, best, rest, unseen, scorer=scorer, eager=eager)))))
    if len(best.rows) > sqrt(len(seen.rows)):
      rest.add(best.sub(best.sorty().rows[-1]))
  return seen.sorty().rows

def random_trainer(d, rows): return rows[:the.learn.Budget]

def evaluate(d, trainer, repeats=20):
  """Score a trainer over many shuffled runs."""
  win = wins(d)
  out = Num(BIG)
  for _ in range(repeats):
    rs = shuffle(d.rows[:])
    trained = trainer(d, rs)
    top = min(trained[:the.learn.Check], key=lambda r: d.disty(r))
    out.add(win(top))
  print(f"  {say(out.mid()):>5}  {trainer.__name__}")

# --- Bayes ------------------------------------------------------
def nbayes(src, warmup=10):
  """Incremental naive Bayes classifier. Returns a Confuse matrix."""
  rows = iter(src)
  d    = Data([next(rows)])
  every, ks, cf = Data([d.cols.names]), {}, Confuse()
  def best(k): return ks[k].like(row, len(every.rows), len(ks))
  for row in rows:
    k = row[d.cols.klass]
    if k not in ks: ks[k] = Data([d.cols.names])
    if len(every.rows) >= warmup:
      confuse(cf, str(k), str(max(ks, key=best)))
    ks[k].add(every.add(row))
  return cf

# --- Examples: help + unit tests --------------------------------
def eg_h():
  "show help"
  print(__doc__)
  for k,fun in globals().items():
    if k.startswith("eg_") and k not in ["eg_h"]:
      args = " ".join(fun.__annotations__)
      if fun.__doc__:
        print(f"  --{(k[3:]+' '+args).strip():<20} {fun.__doc__}")

def eg_the():
  "show config"
  def show(x, prefix=""):
    for k,v in x.__dict__.items():
      if isinstance(v, o): show(v, prefix+k+".")
      else: print(f"  {prefix}{k}={v}")
  show(the)

def eg_csv(f:filename):
  "demo csv reader"
  align(list(csv(f))[::30])

def eg_data(f:filename):
  "demo data storage"
  d = Data(csv(f))
  align([d.mid()] + [d.cols.names] + d.rows[::30])

def eg_disty(f:filename):
  "demo row distance to heaven"
  d = Data(csv(f))
  align([d.cols.names] + sorted(d.rows, key=lambda r: d.disty(r))[::30])

def eg_like(f:filename):
  "demo naive bayes likelihood"
  d = Data(csv(f))
  d.rows.sort(key=lambda r: d.like(r, len(d.rows), 2))
  for row in d.rows[::30]:
    print(row, say(d.like(row, len(d.rows), 2)))

def eg_same():
  "test statistical tests"
  assert same([1,2,3], [1,2,3], 0.1)
  assert not same([1,2,3], [10,20,30], 0.1)

def eg_ranks():
  "sort treatments, find best statistical tier"
  d = {f"t{j}":
       [(10 if j<=5 else 20)*(-log(1-r()))**
        (1/(2 if j<=5 else 1)) for _ in range(50)]
       for j in range(1, 21)}
  for k, n in bestRanks(d).items():
    print(f"  {k:<5} median: {say(n.mid())}")

# --- Examples: causal ladder ------------------------------------
def eg_see(f:filename):
  "see: trends + summarize + model (sorted best to worst)"
  _, _, t, _ = ready(f)
  showTree(t)

def eg_act(f:filename):
  "act: alerts + compare + benchmark (test vs leaf)"
  d, d2, t, test = ready(f)
  for r in sorted(test, key=lambda r: d2.disty(r))[:10]:
    lf = leaf(t, r)
    gap = d2.disty(r) - lf.y.mid()
    flag = " !" if abs(gap) > lf.y.spread() else "  "
    print(f"{flag} actual={say(d2.disty(r)):>5}"
          f"  leaf={say(lf.y.mid()):>5}"
          f"  gap={say(gap):>6}  n={len(lf.y)}")

def eg_imagine(f:filename):
  "imagine: forecast + root cause + simulate (what-if on worst)"
  d, d2, t, test = ready(f)
  r = max(test, key=lambda r: d2.disty(r))
  now = leaf(t, r).y.mid()
  plans = [(whatif(t,r,at,c.mid()).y.mid(), d2.cols.names[at], c.mid())
           for at, c in d2.cols.x.items()]
  print(f"  now={say(now)}")
  for s, name, val in sorted(plans):
    print(f"  {say(s):>5} if {name}={say(val)}"
          f"{'  <-- improves' if s < now else ''}")

def eg_test(f:filename):
  "run full train/predict/score pipeline"
  d0 = Data(csv(f))
  outs, win = Num(BIG), wins(d0)
  for _ in range(20):
    d, d2, t, test = ready(d0)
    best = sorted(test, key=lambda r: leaf(t, r).y.mid())
    top = min(best[:the.learn.Check], key=lambda r: d2.disty(r))
    outs.add(win(top))
  print(int(outs.mid()))

# --- Examples: algorithms ---------------------------------------
def eg_bayes(f:filename):
  "incremental naive Bayes (needs class column ending with !)"
  d = Data(csv(f))
  if d.cols.klass is None: print("  (skipped: no class column)"); return
  rows = [["label","n","pd","pf","prec","acc"]]
  for c in confused(nbayes(csv(f))):
    rows.append([c.label, c.fn+c.tp, c.pd, c.pf, c.prec, c.acc])
  align(rows)

def eg_kmeans(f:filename):
  "vanilla k-means"
  d = Data(csv(f)); last = BIG
  for err, kids in kmeans(d):
    print(f"err={err:.3f}")
    if abs(last - err) <= 0.01: break
    last = err
  align([k.mid() for k in kids])

def eg_cluster(f:filename):
  "compare vanilla kmeans vs kmeans++ seeding"
  d0 = Data(csv(f))
  seen = {False: [], True: []}
  for _ in range(20):
    d1 = Data([d0.cols.names] + shuffle(d0.rows)[:50])
    for use_kpp in seen:
      cents = kpp(d1, k=10) if use_kpp else None
      last = BIG
      for err, _ in kmeans(d1, cents=cents):
        if abs(last - err) <= 0.01: break
        last = err
      seen[use_kpp] += [int(100*err)]
  for use_kpp, errs in seen.items():
    name = "kpp" if use_kpp else "kmeans"
    says(sorted(errs) + [sum(errs)//len(errs), name], w=3)

def eg_fast(f:filename):
  "fastmeans recursive projection clustering"
  d = Data(csv(f))
  for cluster in fastmeans(d, min_leaf=10):
    c = clone(d, cluster)
    print(f"  n={len(cluster):3}  {goals(c)}")

def eg_sa(f:filename):
  "simulated annealing demo"
  d0 = Data(csv(f))
  d1 = Data([d0.cols.names] + shuffle(d0.rows)[:50])
  says(["Evals","Energy"] + d1.cols.names, 8)
  for h, e, row in sa(d1):
    says([h, e] + row, 8)

def eg_search(f:filename):
  "compare ls, sa, ls(no restarts), sa(with restarts)"
  def lsR(d, **kw): return ls(d, restarts=0, **kw)
  def saR(d, **kw): return sa(d, restarts=100, **kw)
  d0 = Data(csv(f))
  seen = {sa: [], ls: [], lsR: [], saR: []}
  for _ in range(20):
    d1 = Data([d0.cols.names] + shuffle(d0.rows)[:50])
    for algo in seen:
      for h, e, row in algo(d1): pass
      seen[algo] += [int(100*e)]
  for algo, errs in seen.items():
    says(sorted(errs) + [sum(errs)//len(errs), algo.__name__], w=3)

def eg_compare(f:filename):
  "compare trainers: random + 4 guess strategies"
  def lazy_nearer(d,rs):    return guess(d,rs,scorer=nearer,eager=False)
  def lazy_likelier(d,rs):  return guess(d,rs,scorer=likelier,eager=False)
  def eager_nearer(d,rs):   return guess(d,rs,scorer=nearer,eager=True)
  def eager_likelier(d,rs): return guess(d,rs,scorer=likelier,eager=True)
  d = Data(csv(f))
  for trainer in [random_trainer, lazy_nearer, lazy_likelier,
                  eager_nearer, eager_likelier]:
    evaluate(d, trainer)

def eg_all(f:filename):
  "run all tests, let exceptions crash naturally"
  egs = {k: v for k, v in globals().items()
         if k[:3] == "eg_" and k not in ["eg_all", "eg_h"]}
  for k, fn in egs.items():
    print(f"\n--- {k} ---")
    if fn.__doc__: print(fn.__doc__)
    random.seed(the.seed)
    fn(f) if "f" in fn.__annotations__ else fn()

# --- Start up ---------------------------------------------------
the = setup(__doc__)
random.seed(the.seed)

if __name__ == "__main__": cli(globals())
