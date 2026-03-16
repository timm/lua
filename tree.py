#!/usr/bin/env python3 -B
"""
tree.py: explainable multi-objective optimization   
(c) 2026 Tim Menzies, timm@ieee.org, MIT license   
  
Usage: 

    ./tree.py [OPTIONS] [ARGS]   

Options:

    -h                    show help on command line options     
    --seed=1              set random number seed      
    --p=2                 set distance type (1 is Manhattan, 2 is Euclidean)      
    --learn.leaf=3        set examples per leaves in a tree      
    --learn.Budget=50     set number of rows to evaluate      
    --learn.Check=5       set number of guesses to check      
    --stats.cliffs=0.195  set threshold for Cliff's Delta      
    --stats.conf=1.36     set confidence coefficient for KS test      
    --stats.eps=0.35      set margin of error multiplier      
    --show.Show=30        set display width/padding for trees      
    --show.Decimals=2     set number of decimals for float formatting      
    --see   file          see: show tree (rung 1)   
    --act   file          act: test vs leaf (rung 2)   
    --imagine file        imagine: what-if (rung 3)   
    --test  file          run full train/predict/score pipeline   
    --all   file          run all tests/examples using  csv file   
   
Input is CSV. Header (row 1) defines column roles as follows:   

    [A-Z]* : Numeric (e.g. "Age").     [a-z]* : Symbolic (e.g. "job").      
    *+     : Maximize (e.g. "Pay+").   *-     : Minimize (e.g. "Cost-").      
    *X     : Ignored (e.g. "idX").     ?      : Missing value (not in header)      


To install and test, download http://githib.com/timm/lua/tree.py. Then:   
   
    chmod +x tree.py      
    mkdir -p $HOME/gits   # download sample data       
    git clone http://github.com/timm/moot $HOME/gits/moot      
    ./tree.py --see ~/gits/moot/optimize/misc/auto93.csv      

Run all tests:

    ./tree.py --all ~/gits/moot/optimize/misc/auto93.csv   

"""
from time import perf_counter_ns as now
import re, random, sys, bisect
from math import log,log2,exp
from typing import Any, Iterable
from types import SimpleNamespace as S
    
type Qty  = int | float
type Atom = str | bool | Qty
type X    = list[Atom]              # independent inputs
type Y    = list[Qty]               # dependent output goals
type Row  = (X,Y)                   # example of inputs --> goals
type Rows = list[Row]               # many 'Row's
type Col  = Num | Sym               # 'Col's summarizes Nums,Syms
type Cols = list[Col]               # many 'Col's
type Data = (Rows, Cols)            # Rows, summarized in Cols
type Tree = Data | (Data,Tree,Tree) # binary tree of Data

# --- Create ----
class Tree:
  """A binary decision tree node. Supports 0, 1, or 2 children."""
  def __init__(i, d:Data, rs:Rows):
    i.d = clone(d, rs)
    i.col,i.cut,i.L,i.R = None,0,None,None

class Num:
  """Summarizes continuous numbers (keeps a running mean and variance)."""
  def __init__(i, s="", a=0):
    i.txt,i.at,i.n,i.mu,i.m2,i.goal = s,a,0,0,0,s[-1:]!="-"

class Sym:
  """Summarizes categorical data (keeps a frequency count)."""
  def __init__(i, s="", a=0): i.txt,i.at,i.n,i.has = s,a,0,{}

class Data:
  """Holds tabular rows and separates X (independent) from Y (dependent) cols."""
  def __init__(i,src=None):
    src = iter(src or {})
    i.rows, i.cols, i._mid = [], Cols(next(src)), None
    adds(src,i)

class Cols:
  """Parses column headers to assign types (Num/Sym) and roles (X/Y)."""
  def __init__(i, n: list[str]):
    i.names, i.x, i.y, i.all = n, [], [], []
    for j,s in enumerate(n):
      i.all += [(Num if s[0].isupper() else Sym)(s, j)] 
      if not s.endswith("X"):
        (i.y if s[-1] in "+-!" else i.x).append(i.all[-1])

def clone(d: Data, rs: list=None) -> Data:
  """Creates an empty Data object with the same columns as the original."""
  return adds(rs or [], Data([d.cols.names]))

# --- Update ----
def adds(src: Iterable, it=None) -> Data | Col:
  """Sequentially adds items to a Data object or Column."""
  it = it or Num(); [add(it, v) for v in (src or [])]; return it

def sub(x, v:Any): 
  """Removes an item from a summary (decrements counts)."""
  return add(x,v,-1)

def add(x, v:Any, w:int=1) -> Any:
  """Updates Column summaries (Welford's algorithm) or adds rows to Data."""
  if v == "?": return v
  if  type(x) == Cols: [add(c, v[c.at],w) for c in x.all]
  elif type(x) == Data:
    x._mid = None
    if not x.cols: x.cols = Cols(v)
    else: 
      add(x.cols, v,w)
      (x.rows.append if w>0 else x.rows.remove)(v)
  else:
    x.n += w
    if type(x) == Num:
      if w < 0 and x.n <= 2: x.n = x.mu = x.m2 = 0
      elif x.n>0: 
        d = v - x.mu; x.mu += w*d/x.n; x.m2 += w*d*(v - x.mu)
    else: x.has[v] = w + x.has.get(v, 0)
  return v

# --- Query ----
def mid(x:Col) -> Atom | Row:
  """Returns the central tendency (mean for Num, mode for Sym)."""
  if type(x)==Num: return x.mu
  if type(x)==Sym: return max(x.has, key=x.has.get)
  x._mid = x._mid or [mid(c) for c in x.cols.all]
  return x._mid

def spread(x:Col) -> Qty:
  """Returns the variation (standard deviation for Num, entropy for Sym)."""
  if type(x) == Sym:
    return -sum(v/x.n*log2(v/x.n) for v in x.has.values())
  return (max(0,x.m2)/(x.n - 1))**.5 if x.n > 1 else 0

def norm(n: Num, v:Qty) -> float:
  """Squashes a number to a 0..1 scale based on its column distribution."""
  sd = spread(n) + 1e-32
  return v if v=="?" else 1/(1 + exp(-1.7 * (v - n.mu)/sd))

def mink(items:Iterable[Qty]):
  """Calculates Minkowski distance for a list of items."""
  d,n = 0, 1e-32
  for item in items: d,n = d+item**the.p, n+1
  return (d/n) ** (1/the.p)

def disty(d: Data, r: Row) -> float:
  """Measures how far a row is from the theoretical 'perfect' row."""
  return mink(abs(norm(c, r[c.at]) - c.goal) for c in d.cols.y)

def scoresy(d, rs:Rows=None): 
  """Calculates distances for a set of rows."""
  return adds(disty(d, r) for r in (rs or d.rows))

def goals(d: Data) -> dict: 
  """Returns the midpoints (mean/mode) for all Y columns."""
  return {c.txt: mid(c) for c in d.cols.y}

# --- Tree ---
def splits(c: Col, rs: Rows, d: Data):
  """Yields proposed column cuts, returning the left/right splits and their spread."""
  if vs := [r[c.at] for r in rs if r[c.at] != "?"]:
    cuts = set(vs) if type(c)==Sym else [sorted(vs)[len(vs)//2]]
    for cut in cuts:
      lhs, rhs, L, R = Num(), Num(), [], []
      for r in rs:
        v = r[c.at]
        go = v=="?" or (v==cut if type(c)==Sym else v<=cut)
        (L if go else R).append(r)
        add(lhs if go else rhs, disty(d, r))
      yield cut, L, R, lhs.n*spread(lhs)+rhs.n*spread(rhs)

def build(d: Data, rs: Rows):
  """Recursively builds a decision tree by finding the best splits."""
  t = Tree(d, rs)
  t.y, t.mids = scoresy(d, rs), goals(t.d)
  if len(rs) >= 2 * the.learn.leaf:
    bestW, best = 1e32, None
    for c in t.d.cols.x:
      for cut, L, R, w in splits(c, rs, d):
        if min(len(L), len(R)) >= the.learn.leaf and w < bestW:
          bestW, best = w, (c, cut, L, R)
    if best:
      t.col, t.cut, L, R = best
      t.L, t.R = build(d, L), build(d, R)
  return t
 
def leaf(t: Tree, r: Row) -> Tree:
  """Drops a row down the tree to find its matching leaf node."""
  if not t.L: return t
  v = r[t.col.at]
  go = (v != "?" and (v<=t.cut if type(t.col)==Num else v==t.cut))
  return leaf(t.L if go else t.R, r)

def nodes(t: Tree, l=0, col=None, op="", cut=None):
  """Yields nodes of the tree for traversal."""
  yield t, l, col, op, cut
  if t.col:
    ops = ("<=",">") if type(t.col)==Num else ("==","!=")
    kids = [(k, op_s) for k, op_s in zip([t.L, t.R], ops) if k]
    for k, op_s in sorted(kids, key=lambda x: mid(x[0].y)):
      yield from nodes(k, l+1, t.col, op_s, t.cut)

def showTree(t: Tree):
  """Visually prints the decision tree to the console."""
  for n, l, col, op, cut in nodes(t):
    p = f"{col.txt} {op} {o(cut)}" if col else ""
    print(f"{'|   '*(l-1)+p if l>0 else '':<{the.show.Show}}"
          f",{o(mid(n.y)):>4} "
          f",({n.y.n:3}), {o(n.mids)}")

# --- Stats ---
def same(xs: list, ys: list, eps: float) -> bool:
  """Checks if distributions are similar via pragmatic, effect size, and stat tests."""
  xs, ys = sorted(xs), sorted(ys)
  n, m = len(xs), len(ys)
  if abs(xs[n//2] - ys[m//2]) <= eps: return True
  gt = lt = 0
  for a in xs:
    gt += bisect.bisect_left(ys, a)
    lt += m - bisect.bisect_right(ys, a)
  if abs(gt - lt) / (n * m) > the.stats.cliffs: return False
  ks = lambda v: abs(bisect.bisect_right(xs,v)/n
                    - bisect.bisect_right(ys,v)/m)
  return max(max(map(ks,xs)), max(map(ks,ys))) \
          <= the.stats.conf * ((n+m)/(n*m))**0.5

def bestRanks(d: dict[str|list[Qty]]) -> dict:
  """Sorts and groups multiple treatments into top-tier statistical ranks."""
  items = sorted(d.items(),
                 key=lambda kv: sorted(kv[1])[len(kv[1])//2])
  k0, lst0 = items[0]
  best = {k0: adds(lst0, Num(k0))}
  for k, lst in items[1:]:
    if same(lst0, lst, spread(best[k0])*the.stats.eps):
      best[k] = adds(lst, Num(k))
    else: break
  return best

# --- Misc ---
def thing(s: str) -> Atom:
  """Safely coerces strings into numbers or booleans."""
  for f in [int,float,lambda s:{"true":1,"false":0}.get(s.lower(),s)]:
    try: return f(s)
    except ValueError: pass

def o(x:Any):
  """Recursively formats objects for neat printing."""
  of=type(x)
  if of==float: return f"{x:.{the.show.Decimals}f}"
  if of==dict: return "{"+", ".join(f"{k}={o(x[k])}" for k in x)+"}"
  if of==list: return "{"+", ".join(map(o, x))+"}"
  if of==S:  return "S"+o(x.__dict__)
  return str(x)

def csv(f, clean=lambda s: s.partition("#")[0].split(",")):
  """Yields rows from a CSV file, skipping comments and empty whitespace."""
  with open(f, encoding="utf-8") as file:
    for s in file:
      r = clean(s)
      if any(x.strip() for x in r): 
        yield [thing(x.strip()) for x in r]

def wins(d: Data):
  """Returns a function that normalizes a row's distance into a 0-100 score."""
  ds = [disty(d, r) for r in d.rows]
  lo, med = min(ds), sorted(ds)[len(ds)//2]
  return lambda r: int(100*(1-((disty(d,r)-lo) / (med-lo+1e-32))))

def set_dot(t, k, v):
  """Sets a value in a nested namespace using dot notation (e.g., 'a.b.c')."""
  for x in (ks := k.split("."))[:-1]:
    t=t.__dict__.setdefault(x, S())
  setattr(t, ks[-1], v)

def cli(fns, the):
  """Executes functions or updates the configuration object via CLI arguments."""
  args = sys.argv[1:]
  while args:
    random.seed(the.seed)
    k = re.sub(r"^-+", "", args.pop(0))
    if fn := fns.get(f"eg_{k}"):
      fn(*[thing(args.pop(0)) for arg in fn.__annotations__])
    else:
      set_dot(the, k, thing(args.pop(0)))  

def setup(s:str):
  out = S()
  for k, v in re.findall(r"([\w.]+)=(\S+)", s): set_dot(out, k, thing(v)) 
  return out

# --- Core: shared by see/act/imagine ---
def ready(f):
  """Shuffle, split train/test, build tree. Accepts filename or Data."""
  d = f if type(f)==Data else Data(csv(f))
  random.shuffle(d.rows)
  n = len(d.rows) // 2
  train = d.rows[:n][:the.learn.Budget]
  d2 = clone(d, train)
  return d, d2, build(d2, d2.rows), d.rows[n:]

def whatif(t, r, c):
  """Counterfactual: clone row, force one feature to mid, re-route."""
  r2 = r[:]; r2[c.at] = mid(c)
  return leaf(t, r2)

# --- Examples ---
def eg_h(): 
  """Show help."""
  print(__doc__)

def eg_the():  
  """Check config defaults."""
  print(o(the)); assert the.seed == 1

def eg_thing():
  """Test type coercion."""
  assert thing("3.14") == 3.14 and thing("true") in [True, 1]

def eg_num():
  """Test Welford's algorithm for mean and spread."""
  n = adds([10, 20, 30, 40, 50])
  assert n.mu == 30 and 15.8 < spread(n) < 15.9

def eg_sym():
  """Test symbol counting and entropy."""
  s = adds("aaabbc", Sym())
  assert mid(s) == "a" and 1.4 < spread(s) < 1.5

def eg_csv(f: str):
  """Test reading CSV rows."""
  rows = list(csv(f))
  assert len(rows) > 0; print(f"First row: {rows[0]}")

def eg_data(f: str):
  """Test Data object creation and column identification."""
  d = Data(csv(f))
  assert len(d.rows) > 0 and len(d.cols.y) > 0

def eg_dist(f: str):
  """Test distance calculation to 'perfect' row."""
  d = Data(csv(f))
  assert 0 <= disty(d, d.rows[0]) <= 1

def eg_same():
  """Test statistical significance math."""
  assert same([1, 2, 3], [1, 2, 3], 0.1)
  assert not same([1, 2, 3], [10, 20, 30], 0.1)

def eg_ranks():
  """Sort 50 treatments, find best statistical tier."""
  d = {f"t{j}": 
       [(10 if j<=5 else 20)*(-log(1-random.random()))**
        (1/(2 if j<=5 else 1)) for _ in range(50)]
       for j in range(1, 21)}
  [print(f"  {k:<5} median: {o(mid(n))}") 
   for k,n in bestRanks(d).items()]

# Analytics via Pearl's ladder of causation:

# |          | See            | Act            | Imagine          |
# |          | Rung 1:        | Rung 2:        | Rung 3:          |
# |          | association    | intervention   | counterfactual   |
# |----------|----------------|----------------|------------------|
# | Find     | Trends         | Alerts         | Forecasting      |
# |          | What changed?  | What's unusual | Where are things |
# |          |                | right now?     | heading?         |
# |----------|----------------|----------------|------------------|
# | Explain  | Summarize      | Compare        | Root cause       |
# |          | What drove     | How does this  | Are we on track  |
# |          | outcomes?      | differ?        | for our goals?   |
# |----------|----------------|----------------|------------------|
# | Compare  | Model          | Benchmark      | Simulate         |
# |          | What worked    | How good vs    | What if we       |
# |          | before?        | best practice? | change x?        |
# |----------|----------------|----------------|------------------|
# | Source   | training set   | test set       | perturbed test   |
# | tree.py  | build(d, rs)   | leaf(t, r)     | leaf(t, r')+rank |
# | Example  | see eg_see     | see eg_act     | see eg_imagine   |

# Each column is the same 3 questions asked with increasing causal 
# ambition. See only needs data. Act needs a model applied to new
# observations. Imagine needs that model plus a way to connect the
# observed row to a hypothetical twin (freezing latent factors).

# --- See (rung 1): inspect the tree built from training data ---
# Covers: trends + summarize + model (sorted best to worst).
def eg_see(f: str):
  """See: trends + summarize + model (sorted best to worst)."""
  _, _, t, _ = ready(f)
  showTree(t)

# --- Act (rung 2): route test rows, see actual vs predicted ---
# Covers: alerts (! flag) + compare (actual vs leaf) + benchmark.
def eg_act(f: str):
  """Act: alerts + compare + benchmark (test vs leaf)."""
  d, d2, t, test = ready(f)
  for r in sorted(test, key=lambda r: disty(d2, r))[:10]:
    lf = leaf(t, r)
    gap = disty(d2, r) - mid(lf.y)
    flag = " !" if abs(gap) > spread(lf.y) else "  "
    print(f"{flag} actual={o(disty(d2,r)):>5}"
          f"  leaf={o(mid(lf.y)):>5}"
          f"  gap={o(gap):>6}  n={lf.y.n}")

# --- Imagine (rung 3): perturb test, rank what-ifs ---
# Covers: forecast + root cause+simulate (what-if on worst).
def eg_imagine(f: str):
  """Imagine: forecast + root cause + simulate (what-if on worst)."""
  d, d2, t, test = ready(f)
  r = max(test, key=lambda r: disty(d2, r))
  now = mid(leaf(t, r).y)
  plans = [(mid(whatif(t, r, c).y), c.txt, mid(c))
           for c in d2.cols.x]
  print(f"  now={o(now)}")
  for s, name, val in sorted(plans):
    print(f"  {o(s):>5} if {name}={o(val)}"
          f"{'  <-- improves' if s < now else ''}")

# --- Full pipeline test (20 repeats) ---
def eg_test(f: str):
  """Run full train/predict/score pipeline."""
  d0 = Data(csv(f))
  outs, win = Num("win"), wins(d0)
  for _ in range(20):
    d, d2, t, test = ready(d0)
    guess = sorted(test, key=lambda r: mid(leaf(t, r).y))
    top = min(guess[:the.learn.Check], key=lambda r: disty(d2, r))
    add(outs, win(top))
  print(int(mid(outs)))

def eg_all(f: str):
  """Run all tests, let exceptions crash naturally."""
  egs = {k: v for k, v in globals().items() 
         if k[:3] == "eg_" and k != "eg_all"}
  for k, fn in egs.items():
    print(f"\n--- {k} ---")
    if fn.__doc__: print(fn.__doc__)
    random.seed(the.seed)
    fn(f) if "f" in fn.__annotations__ else fn()

# -- Start up --
the = setup(__doc__)
if __name__ == "__main__": cli(globals(), the)
