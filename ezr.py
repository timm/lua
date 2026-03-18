#!/usr/bin/env python3 -B
"""
ezr.py: explainable multi-objective optimization   
(c) 2026 Tim Menzies, timm@ieee.org, MIT license   
  
Usage: 

    ./ezr.py [OPTIONS] [ARGS]   

Options:

    -h                    how help on command line options     
    --the                 show current config
    --list                list all demos
    --egs file            run all de,os
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
   
Input is CSV. Header (row 1) defines column roles as follows:   

    [A-Z]* : Numeric (e.g. "Age").     [a-z]* : Symbolic (e.g. "job").      
    *+     : Maximize (e.g. "Pay+").   *-     : Minimize (e.g. "Cost-").      
    *X     : Ignored (e.g. "idX").     ?      : Missing value (not in header)      


To install and test, download http://githib.com/timm/lua/ezr.py. Then:   
   
    chmod +x tree.py      
    mkdir -p $HOME/gits   # download sample data       
    git clone http://github.com/timm/moot $HOME/gits/moot      
    ./ezr.py --see ~/gits/moot/optimize/misc/auto93.csv      

Run all tests:

    ./ezr.py --egs ~/gits/moot/optimize/misc/auto93.csv   

"""
from time import perf_counter_ns as now
import re, random, sys, bisect
from random import random as rand, choices, choice, sample, shuffle
from math import log,log2,exp
from typing import Any, Iterable
from types import SimpleNamespace as S

# ---- 0. Structures ----
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

# ---- 1. Config ----
# Coerce command line arguments into updates to config, or calls to a library
# of demo functions.

def cli():
  """Executes functions or updates the configuration object via CLI arguments."""
  args = sys.argv[1:]
  while args:
    random.seed(the.seed)
    k = re.sub(r"^-+", "", args.pop(0))
    if fn := globals().get(f"eg_{k}"): 
      fn(*[thing(args.pop(0)) for arg in fn.__annotations__])
    else: 
      _nest(the, k, thing(args.pop(0)))  

def _nest(t, k, v):
  """Sets a value in a nested namespace using dot notation (e.g., 'a.b.c')."""
  for x in (ks := k.split("."))[:-1]: t=t.__dict__.setdefault(x, S())
  setattr(t, ks[-1], v)

def thing(s: str) -> Atom:
  """Safely coerces strings into numbers or booleans."""
  s = s.strip()
  for f in [int,float,lambda s:{"true":1,"false":0}.get(s.lower(),s)]:
    try: return f(s)
    except ValueError: pass

def o(x:Any):
  """Recursively formats objects for neat printing."""
  t=type(x)
  if float==t: return f"{x:.{the.show.Decimals}f}"
  if dict==t:  return "{"+", ".join(f"{k}={o(v)}" for k,v in x.items())+"}"
  if list==t:  return "{"+", ".join(map(o, x))+"}"
  if S==t:     return "S"+o(x.__dict__)
  if hasattr(x,"__dict__"): return x.__class__.__name__+o(x.__dict__)
  return str(x)

the = S()
for k,v in re.findall(r"([\w.]+)=(\S+)",__doc__): _nest(the, k, thing(v)) 

# ---  Config Egs ---
def eg_the():  
  """Check config defaults."""
  print(o(the)); assert int == type(the.seed)

def eg_thing():
  """Test type coercion."""
  assert thing("3.14  ") == 3.14 and thing(" true ") in [True, 1]

def eg_h(): 
  """Show help."""
  print(__doc__)

def eg_list():
  """List all demos."""
  for k,fn in sorted({k: v for k, v in globals().items() 
                      if k[:3] == "eg_"}.items()):
      s= f"--{k[3:]} {' '.join([k for k in fn.__annotations__])}"
      print(f"    {s:15} {fn.__doc__}")

def eg_egs(file: str):
  """Run all tests."""
  egs = {k: v for k, v in globals().items() if k[:3]=="eg_" and k!="eg_egs"}
  for k, fn in egs.items():
    print(f"\n--- {k} ----")
    if fn.__doc__: print(fn.__doc__)
    random.seed(the.seed)
    fn(file) if "file" in fn.__annotations__ else fn()

# ---- 1. Columns ----
# Columns let us increrement summaries or symbolic or numeric columns.

def Col(s="",a=0):
  """Factory: strings to column. Upper case ==> Nums. Else, return a Sym."""
  return (Num if s[0].isupper() else Sym)(s, a) 

class Num:
  """Summarizes continuous numbers (keeps a running mean and variance)."""
  def __init__(i, s="", a=0):
    """Anything ending in '-' is a goal to be minimized."""
    i.txt,i.at,i.n,i.mu,i.m2,i.sd,i.goal = s,a,0,0,0,0,s[-1:]!="-"

class Sym:
  """Summarizes categorical data (keeps a frequency count)."""
  def __init__(i, s="", a=0): i.txt,i.at,i.n,i.has = s,a,0,{}

def summarize(x: Num|Sym, v:Any, w:int=1) -> Any:
  """To add/subtract from this column, use w=1,-1 respectively"""
  if v=="?": return v
  x.n += w
  if Sym == type(x): 
    x.has[v] = w + x.has.get(v, 0)
  elif w < 0 and x.n <= 2:  # Nums. Case#1. resetting to zero
    x.n = x.mu = x.m2 = x.sd = 0
  else: # Nums. Case #2. Update using Welford.
    d = v - x.mu; x.mu += w*d/x.n; x.m2 += w*d*(v - x.mu)
    x.sd = (max(0,x.m2)/(x.n - 1))**.5 if x.n > 1 else 0

def mid(x:Col) -> Atom:
  """Returns the central tendency (mean for Num, mode for Sym)."""
  return x.mu if Num==type(x) else max(x.has, key=x.has.get)

def spread(x:Col) -> float:
  """Returns the variation (standard deviation for Num, entropy for Sym)."""
  return x.sd if Num==type(x) else -sum(v/x.n*log2(v/x.n) for v in x.has.values())

def norm(n: Num, v:Qty) -> float:
  """Squashes a number to a 0..1 scale based on its column distribution."""
  return v if v=="?" else 1/(1 + exp(-1.7 * (v - n.mu)/(spread(n)+1e-32)))

def pick(x):
  """Roulette-wheel select for dicts/Syms, Irwin-Hall(3) selection for Nums."""
  if Sym==type(x): return pick(x.has)
  if Num==type(x): 
    lo,hi = x.mu - 3*x.sd, x.mu + 3*x.sd 
    return max(lo, min(hi, x.mu + x.sd*2*(rand()+rand()+rand() - 1.5)))
  elif dict==type(x):
    n = sum(x.values()) * rand()
    for k, v in x.items():
      if (n := n - v) <= 0: return k

# ---  Column Egs ---
def eg_num():
  """Test Welford's algorithm for mean and spread."""
  n = Num(); [summarize(n,v) for v in [10, 20, 30, 40, 50]]
  print(o(sorted(pick(n) for _ in range(10))))
  assert n.mu == 30 and 15.8 < spread(n) < 15.9

def eg_sym():
  """Test symbol counting and entropy."""
  s = Sym(); [summarize(s,v) for v in "aaabbc"]
  print(o([pick(s) for _ in range(10)]))
  assert mid(s) == "a" and 1.4 < spread(s) < 1.5

# ---- 2. Data ----
class Data:
  """Holds tabular rows and separates X (independent) from Y (dependent) cols."""
  def __init__(i,src=None):
    src = iter(src or {})
    i.rows, i.cols, i._mids = [], Cols(next(src)), None
    adds(src,i)

class Cols:
  """Parses column headers to assign types (Num/Sym) and roles (X/Y)."""
  def __init__(i, names: list[str]):
    i.names, i.all = names, [Col(s,j) for j,s in enumerate(names)]
    i.x = [c for c in i.all if c.txt[-1] not in "+-!X"]
    i.y = [c for c in i.all if c.txt[-1]     in "+-!"]

def clone(d: Data, rs: list=None) -> Data:
  """Creates an empty Data object with the same columns as the original."""
  return adds(rs or [], Data([d.cols.names]))

def sub(x, v:Any): 
  """Removes an item from a summary (decrements counts)."""
  return add(x,v,-1)

def add(x: Data|Col, v:Any, w:int=1) -> Any:
  """Create or update summaries. Adds new rows to Data."""
  if Data is type(x):
    x._mids = None # centroid is now out of data
    [summarize(c, v[c.at], w) for c in x.cols.all] 
    (x.rows.append if w>0 else x.rows.remove)(v) # update cache of rows
  else: summarize(x,v,w) # Num or Sym
  return v

def mids(d:Data): 
  """Memoize centroid creation. Return current centroid."""
  d._mids = d._mids or [mid(c) for c in d.cols.all]
  return d._mids

def adds(src: Iterable, it=None) -> Data | Col:
  """Sequentially adds many items to a Data object or Column."""
  it = it or Num(); [add(it, v) for v in (src or [])]; return it

def csv(f, clean=lambda s: s.partition("#")[0].split(",")):
  """Yields rows from a CSV file, skipping comments and empty whitespace."""
  with open(f, encoding="utf-8") as file:
    for s in file:
      r = clean(s)
      if any(x.strip() for x in r): 
        yield  [thing(x) for x in r]

# ---  Data Egs ---
def eg_cols():
  """Show columns created from strings."""
  cols = Cols(["name","Age","Weight-"])
  [print(o(c)) for c in cols.x]

def eg_csv(file: str):
  """Test reading CSV rows."""
  rows = list(csv(file))
  assert len(rows) > 0; print(f"First row: {rows[0]}")

def eg_data(file: str):
  """Test Data object creation and column identification."""
  d = Data(csv(file))
  assert len(d.rows) > 0 and len(d.cols.y) > 0
  assert len(d.cols.y) > 0 
  [print(o(c)) for c in d.cols.all]

def eg_addsub(file:str):
  """Test we can incrementally add/subtract from a Data."""
  d  = Data(csv(file))
  d2 = clone(d)
  for r in d.rows: 
    add(d2,r)
    if len(d2.rows)==100: m1=mids(d2)
  m2 = mids(d2)
  for r in d.rows[::-1]:
     sub(d2,r)
     if len(d2.rows)==100: m3=mids(d2)
  assert all(abs(a - b) < 0.01 for a,b in zip(m1,m3))
  print("add",o(m1))
  print("all",o(m2))
  print("sub",o(m3))

# ---- 3. Distance ----
def minkowski(items:Iterable[Qty]) -> float : # 0..1
  """Calculates Minkowski distance for a list of items."""
  d,n = 0, 1e-32
  for item in items: d,n = d+item**the.p, n+1
  return (d/n) ** (1/the.p)

def disty(d: Data, r: Row) -> float:
  """Measures how far a row is from the theoretical 'perfect' row."""
  return minkowski(abs(norm(c, r[c.at]) - c.goal) for c in d.cols.y)

def distx(d: Data, r1: Row, r2:float) -> float:
  """Measures distance between two rows."""
  return minkowski(_distx1(c,r1[c.at],r2[c.at]) for c in d.cols.x)

def _distx1(c:Num|Sym, u:Any, v:Any) -> float:
  """Retrn distance between 2 items in same column. For missing values, assume largest psssibe"""
  if u==v=="?": return 1
  if Sym==type(c): return u != v
  u,v = norm(c,u), norm(c,v)
  u = u if u != "?" else (0 if v>0.5 else 1)
  v = v if v != "?" else (0 if u>0.5 else 1)
  return abs(u - v)

# ---  Distance Egs ---
def eg_distx(file:str):
  """Demo row distance to heaven."""
  d  = Data(csv(file))
  r1 = d.rows[0]
  D  = lambda r2: distx(d,r1,r2)
  print(*d.cols.names,sep="\t")
  for r in sorted(d.rows,key=D)[::30]: print(*r,sep="\t")

def eg_disty(file:str):
  """Demo row distance to heaven."""
  d = Data(csv(file))
  D = lambda r: disty(d,r)
  print(*d.cols.names,sep="\t")
  for r in sorted(d.rows,key=D)[::30]: print(*r,sep="\t")

# ---- 4. Cluster -----
def kmeans(d: Data, rows=None, k=10, n=10, cents=None):
  """Iterative K-Means. Returns a list of Data objects (final clusters)."""
  rows  = rows or d.rows
  cents = cents or choices(rows, k=k)
  out = []
  for _ in range(n):
    out = [clone(d) for _ in cents]
    for r in rows:
      i = min(range(len(cents)), key=lambda j: distx(d, cents[j], r))
      add(out[i], r)
    cents = [mids(kid) for kid in out if kid.rows]
  return out

def kpp(d: Data, rows=None, k=10, few=256):
  """K-Means++ initialization: returns a list of rows (centroids)."""
  rows = rows or d.rows
  out  = [choice(rows)] 
  while len(out) < k:
    t = sample(rows, min(few, len(rows)))
    weights = {i: min(distx(d, t[i], c)**2 for c in out) 
               for i in range(len(t)) }
    out.append(t[pick(weights)])
  return out

def half(d: Data, rows, few=20):
  """Splits rows in half by projecting them between 2 faraway points."""
  D = lambda r1,r2: distx(d,r1,r2)
  t = sample(rows, min(few, len(rows)))
  c, east, west = max(((D(i, j), i, j) for i in t for j in t),
                      key=lambda x: x[0])
  project = lambda r: (D(r,east)**2 + c**2 - D(r,west)**2) / (2*c + 1e-32)
  rows = sorted(rows, key=project)
  n = len(rows) // 2
  return rows[:n], rows[n:], east, west, c

def rhalf(d: Data, rows=None, stop=None, few=20) -> list[Data]:
  """Recursively halves the data, returning a flat list of leaf clusters."""
  rows = rows if rows is not None else d.rows
  stop = stop or len(d.rows)**0.5
  if len(rows) <= 2*stop: return [clone(d, rows)]
  left, right, _, _, _ = half(d, rows, few)
  return rhalf(d, left, stop, few) + rhalf(d, right, stop, few)

# ---  Cluster Eg ---

def eg_cluster(file: str):
  """Compare three clustering methods."""
  d = Data(csv(file))
  print(f"\n{'Algorithm':<18} | {'K':>3} | {'Time':>7} | "
        f"{'ErrX':<4} | {'ErrY':<4}")
  print("-" * 65)
  _cluster(d, "Baseline (None)", lambda: [d])
  _cluster(d, "K-Means",   lambda: kmeans(d, k=10))
  _cluster(d, "K-Means++", lambda: kmeans(d, k=10, cents=kpp(d, k=10)))
  _cluster(d, "Rhalf",    lambda: rhalf(d))

def _cluster(d, title, clusterer, repeats=20):
  """Help for eg_compare."""
  tm = errx = erry = k_count = 0
  for _ in range(repeats):
    shuffle(d.rows)
    t1 = now()
    out = clusterer()
    tm += (now() - t1) / 1e6 
    k_count += len(out)
    errx += sum(distx(d, r, mids(k)) for k in out for r in k.rows)
    erry += sum(abs(disty(d, r) - disty(d, mids(k))) 
                for k in out for r in k.rows)
  N = repeats * len(d.rows) # Denominator for averaging errors across all rows
  print(f"{title:<18} | {k_count/repeats:>3.0f} | {int(tm/repeats):5}ms | "
        f"{errx/N:.2f} | {erry/N:.2f}")
  
# ---- Main ----
# Start-up.

if __name__=="__main__": cli()

