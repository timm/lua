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
# Coerce command line arguments into updates to config, 
# or calls to a library of demo functions.

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
  """Sets a value in a nested namespace (e.g., 'a.b.c')."""
  for x in (ks := k.split("."))[:-1]: t=t.__dict__.setdefault(x,S())
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
  if dict==t: return "{"+", ".join(f"{k}={o(v)}" for k,v in x.items())+"}"
  if list==t: return "{"+", ".join(map(o, x))+"}"
  if S==t:    return "S"+o(x.__dict__)
  if hasattr(x,"__dict__"): return x.__class__.__name__+o(x.__dict__)
  return str(x)

the = S()
for k,v in re.findall(r"([\w.]+)=(\S+)",__doc__): _nest(the,k,thing(v)) 

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
  funs=globals().items()
  egs = {k: v for k, v in funs if k[:3]=="eg_" and k!="eg_egs"}
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
  return x.sd if Num==type(x) \
              else -sum(v/x.n*log2(v/x.n) for v in x.has.values())

def norm(n: Num, v:Qty) -> float:
  """Squashes a number to a 0..1 scale based on its column distribution."""
  return v if v=="?" else 1/(1 + exp(-1.7*(v-n.mu)/(spread(n)+1e-32)))

def pick(x):
  """Roulette-wheel select for dicts/Syms, Irwin-Hall(3) selection for Nums."""
  if Sym==type(x): return pick(x.has)
  if Num==type(x): 
    lo,hi = x.mu - 3*x.sd, x.mu + 3*x.sd 
    return max(lo, min(hi, x.mu+x.sd*2*(rand()+rand()+rand()-1.5)))
  elif dict==type(x):
    n = sum(x.values()) * rand()
    for k, v in x.items():
      if (n := n - v) <= 0: return k

# ---  Column Egs ---
def eg_num():
  """Test Welford's algorithm for mean and spread."""
  n = Num(); [summarize(n,v) for v in [10, 20, 30, 40, 50]]
  print(o(sorted(int(pick(n)) for _ in range(20))))
  assert n.mu == 30 and 15.8 < spread(n) < 15.9

def eg_sym():
  """Test symbol counting and entropy."""
  s = Sym(); [summarize(s,v) for v in "aaabbc"]
  print(*sorted(pick(s) for _ in range(20)))
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
    (x.rows.append if w>0 else x.rows.remove)(v) 
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
  return minkowski(abs(norm(c,r[c.at])-c.goal) for c in d.cols.y)

def distx(d: Data, r1: Row, r2:float) -> float:
  """Measures distance between two rows."""
  return minkowski(aha(c,r1[c.at],r2[c.at]) for c in d.cols.x)

def aha(c:Num|Sym, u:Any, v:Any) -> float:
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
def kpp(d: Data, rows=None, k=10, few=256):
  """Select centrois that are probably distant to each other."""
  rows = rows or d.rows
  out = [choice(rows)]
  while len(out) < k:
    t = sample(rows, min(few, len(rows)))
    ws = {i: min(distx(d,t[i],c)**2 for c in out) for i in range(len(t))}
    out.append(t[pick(ws)])
  return out

def kmeans(d: Data, rows=None, k=10, n=10, cents=None):
  """Mark rows by nearest centroids. Move centroids to mid of their rows. Repeat."""
  rows, out = rows or d.rows, []
  cents = cents or choices(rows, k=k)
  for _ in range(n):
    out = [clone(d) for _ in cents]
    for r in rows:
      i = min(range(len(cents)), key=lambda j: distx(d,cents[j],r))
      add(out[i], r)
    cents = [mids(kid) for kid in out if kid.rows]
  return out

def half(d: Data, rows, few=20):
  """Divide data using 2 distant points."""
  D = lambda r1,t2: distx(d,r1,r2)
  t = sample(rows, min(few, len(rows)))
  c, east, west = max(((D(r1,r2), i, j) for i in t for j in t),
                      key=lambda z: z[0])
  proj = lambda r: (D(r,east)**2 + c**2 - D(r,west)**2) / (2*c+1e-32)
  rows = sorted(rows, key=proj)
  n = len(rows) // 2
  return rows[:n], rows[n:], east, west, c, proj(rows[n])
 
def rhalf(d: Data, rows=None, stop=None, few=20) -> dict:
  """Recursively, diide data in half."""
  rows = rows if rows is not None else d.rows
  stop = stop or len(d.rows)**0.5
  if len(rows) <= 2 * stop: return [clone(d, rows)]
  l, r, east, west, c, cut = half(d, rows, few)
  return  rhalf(d, l, stop, few) + rhalf(d, r, stop, few)}

def near(d:Data, r1:Row, clusters:list[Data]) -> float:
  """Return kth rows near r1 within some clusters."""
  c = min(c for c in cluster, key=lambda c:distx(d,r1,mids(c)))
  return sorted(c.rows, key=lambda r2:distx(d,r1,r2))[:k]

# ---  Cluster Eg (Evaluation) ---
def eg_cluster(file: str):
  """Compare clustering methods."""
  train = Data(csv(file))
  print(f"\n{'Algorithm':<10} | {'Train':>9} | {'Err Mid':>7} | "
        f"{'Err 1NN':>7} | {'Err Base':>8}\n" + "-" * 52)
  def stats(test,cluster):
    shuffle(train.rows)
    k = near(train, r) for r in cjoices(test,100)

    for r in choices(test,100):
      err += disty(train,r) - knn(

  _kmeans(test):
    c = knn(testkmeans(train, k=10)
    return c, lambda r: min(c, key=lambda x: distx(d_train,r,mids(x)))
  def build_kpp(d_train):
    c = kmeans(d_train, k=10, cents=kpp(d_train, k=10))
    return c, lambda r: min(c, key=lambda x: distx(d_train,r,mids(x)))
  def build_tree(d_train):
    t = rhalf(d_train)
    return t, lambda r: rhalf_leaf(d_train, t, r)["leaf"]
  _report(d, "K-Means",   build_kmeans)
  _report(d, "K-Means++", build_kpp)
  _report(d, "Tree",      build_tree)

#have to wrok tithir this
def _report(d: Data, name: str, builder):
  """Helper for eg_cluster"""
  t0 = now()
  c, get_local_data = builder(d) 
  train_time = (now() - t0) / 1e6
  err_mid, err_1nn, err_base = 0.0, 0.0, 0.0
  n = len(d.rows)
  for r in d.rows:
    actual_y = disty(d, r)
    globals_sorted = sorted([row for row in d.rows if row != r], 
                            key=lambda x: distx(d, r, x))
    err_base += abs(actual_y - disty(d, globals_sorted[0]))
    local_data = get_local_data(r)
    local_rows = [row for row in local_data.rows if row != r]
    if not local_rows: # Fallback 
        local_rows = globals_sorted
    err_mid += abs(actual_y - disty(d, mids(local_data)))
    local_1nn = min(local_rows, key=lambda x: distx(d, r, x))
    err_1nn += abs(actual_y - disty(d, local_1nn))

  print(f"{name:<10} | {train_time:>7.2f}ms | {err_mid/n:>7.4f} | "
        f"{err_1nn/n:>7.4f} | {err_base/n:>8.4f}")

   
# ---- Main ----
# Start-up.

if __name__=="__main__": cli()

