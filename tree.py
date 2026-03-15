#!/usr/bin/env python3 -B
"""
tree.py: explainable multi-objective optimization   
(c) 2026 Tim Menzies, timm@ieee.org, MIT license   
   
Input is CSV. Header (row 1) defines column roles as follows:   

    [A-Z]* : Numeric (e.g. "Age").     [a-z]* : Symbolic (e.g. "job").   
    *+     : Maximize (e.g. "Pay+").   *-     : Minimize (e.g. "Cost-").   
    *X     : Ignored (e.g. "idX").     ?      : Missing value (not in header)   
   
For help on command line options:
    ./tree.py -h

To install and test, download http://githib.com/timm/lua/tree.py. Then:   

    chmod +x tree.py   
    mkdir -p $HOME/gits   # download sample data    
    git clone http://github.com/timm/moot $HOME/gits/moot   
    ./tree.py --tree ~/gits/moot/optimize/misc/auto93.csv   
   
Options:   

    -h                    help   
    --learn.leaf=3        set examples per leaves in a tree   
    --learn.Budget=50     set number of rows to evaluate   
    --learn.Check=5       set number of guesses to check   
    --stats.cliffs=0.195  set threshold for Cliff's Delta   
    --stats.conf=1.36     set confidence coefficient for KS test   
    --stats.eps=0.35      set margin of error multiplier   
    --show.Show=30        set display width/padding for trees   
    --show.Decimals=2     set number of decimals for float formatting   
    --seed=1              set random number seed   
    --p=2                 set distance parameter (1=Manhattan, 2=Euclidean)   

Tests:

    --the                 print the configuration object
    --csv   <str>         read csv and print every 30th row
    --data  <str>         load data and print y-column stats
    --tree  <str>         build and print a decision tree
    --ranks               run best ranks statistical demo
    --test  <str>         run optimization test, make predictions, print score
"""
from time import perf_counter_ns as now
import math, re, random, sys, bisect
from typing import Any, Iterable
from types import SimpleNamespace as S

# --- Types ----
type Qty  = int | float
type Atom = str | bool | Qty
type Row  = list[Atom]
type Rows = list[Row]
type Col  = Num | Sym
type Cols = list[Col]
type Data = tuple[Rows, Cols]
type Tree = Data | tuple[Data, Tree, Tree]

# --- Create ----
class Tree:
  def __init__(i, d, rs):
    i.d = clone(d, rs)
    i.col,i.cut,i.L,i.R = 0,0,None,None

class Num:
  def __init__(i, s="", a=0):
    i.txt,i.at,i.n,i.mu,i.m2,i.goal = s,a,0,0,0,s[-1:]!="-"

class Sym:
  def __init__(i, s="", a=0): i.txt,i.at,i.n,i.has = s,a,0,{}

class Data:
  def __init__(i,src=None):
    src = iter(src or {})
    i.rows, i.cols, i._mid = [], Cols(next(src)), None
    adds(src,i)

class Cols:
  def __init__(i, n: list[str]):
    i.names, i.x, i.y, i.all = n, [], [], []
    for j,s in enumerate(n):
      i.all += [(Num if s[0].isupper() else Sym)(s, j)] 
      if not s.endswith("X"):
        (i.y if s[-1] in "+-!" else i.x).append(i.all[-1])

def clone(d: Data, rs: list=None) -> Data:
  return adds(rs or [], Data([d.cols.names]))

# --- Update ----
def adds(src: Iterable, it=None) -> Data | Col:
  it = it or Num(); [add(it, v) for v in (src or [])]; return it

def sub(x, v:Any): return add(x,v,-1)

def add(x, v:Any, w:int=1) -> Any:
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
  if type(x)==Num: return x.mu
  if type(x)==Sym: return max(x.has, key=x.has.get)
  x._mid = x._mid or [mid(c) for c in x.cols.all]
  return x._mid

def spread(x:Col) -> Qty:
  if type(x) == Sym:
    return -sum(v/x.n*math.log2(v/x.n) for v in x.has.values())
  return (max(0,x.m2)/(x.n - 1))**.5 if x.n > 1 else 0

def norm(n: Num, v:Qty) -> float:
  return v if v=="?" else 1/(1+math.exp(-1.7*(v - n.mu)/(spread(n)+1e-32)))

def mink(items):
  d,n = 0, 1e-32
  for item in items: d,n = d+item**the.p, n+1
  return (d/n) ** (1/the.p)

def disty(d: Data, r: list) -> float:
  return mink(abs(norm(c, r[c.at]) - c.goal) for c in d.cols.y)

def scoresy(d, rs=None): 
  return adds(disty(d, r) for r in (rs or d.rows))

def goals(d: Data) -> dict: 
  return {c.txt: mid(c) for c in d.cols.y}

# --- Tree ---
def splits(c: Col, rs: list, d: Data):
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

def build(d, rs):
  def _branch(t):
    bestW, best = 1e32, None
    for c in t.d.cols.x:
      for cut, L, R, w in splits(c, t.d.rows, d):
        if min(len(L),len(R)) >= the.learn.leaf and w < bestW:
          bestW, best = w, (c, cut, L, R)
    if best:
      t.col, t.cut, L, R = best
      t.L, t.R = _node(Tree(d, L)), _node(Tree(d, R))
  def _node(t):
    t.y, t.mids = scoresy(d, t.d.rows), goals(t.d)
    if len(t.d.rows) >= 2 * the.learn.leaf: _branch(t)
    return t
  return _node(Tree(d, rs))

def nodes(t: Tree, l=0, col=None, op="", cut=None):
  yield t, l, col, op, cut
  if t.L:
    ops = ("<=",">") if type(t.col)==Num else ("==","!=")
    for k, op_s in sorted(zip([t.L, t.R], ops),
                          key=lambda x: mid(x[0].y)):
      yield from nodes(k, l+1, t.col, op_s, t.cut)

def showTree(t: Tree):
  for n, l, col, op, cut in nodes(t):
    p = f"{col.txt} {op} {o(cut)}" if col else ""
    print(f"{'|   '*(l-1)+p if l>0 else '':<{the.show.Show}}"
          f",{o(mid(n.y)):>4} "
          f",({n.y.n:3}), {o(n.mids)}")

def leaf(t: Tree, r: Row) -> Tree:
  if not t.L: return t
  v = r[t.col.at]
  go = (v != "?" and (v<=t.cut if type(t.col)==Num else v==t.cut))
  return leaf(t.L if go else t.R, r)

# --- Stats ---
def same(xs: list, ys: list, eps: float) -> bool:
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

def bestRanks(d: dict) -> dict:
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
  for f in [int,float,lambda s:{"true":True,"false":False}.get(s.lower(),s)]:
    try: return f(s)
    except ValueError: pass

def o(x):
  if type(x)==float: return f"{x:.{the.show.Decimals}f}"
  if type(x)==dict:  return "{"+", ".join(f"{k}={o(x[k])}" for k in x)+"}"
  if type(x)==list:  return "{"+", ".join(map(o, x))+"}"
  if type(x)==S:     return "S"+o(x.__dict__)
  if hasattr(x, "__dict__"): return x.__class__.__name__ + o(x.__dict__)
  return str(x)

def csv(f, clean=lambda s: s.partition("#")[0].split(",")):
  with open(f, encoding="utf-8") as file:
    for s in file:
      r = clean(s)
      if any(x.strip() for x in r): yield [thing(x.strip()) for x in r]

def wins(d: Data):
  ds = [disty(d, r) for r in d.rows]
  lo, med = min(ds), sorted(ds)[len(ds)//2]
  return lambda r: int(100*(1 - ((disty(d,r) - lo) / (med - lo +1e-32))))

def set_dot(t, k, v):
  for x in (ks := k.split("."))[:-1]: t = t.__dict__.setdefault(x, S())
  setattr(t, ks[-1], v)

def cli(fns, the):
  args = sys.argv[1:]
  while args:
    random.seed(the.seed)
    k = re.sub(r"^-+", "", args.pop(0))
    if fn := fns.get(f"eg_{k}"):
      fn(*[thing(args.pop(0)) for arg in fn.__annotations__])
    else:
      set_dot(the, k, thing(args.pop(0)))  # <--- Shrunk to 1 line!
     
# --- Examples ---
def eg_h(): print(__doc__)

def eg_the():  print(o(the))

def eg_csv(f: str):
  [print(row) for n,row in enumerate(csv(f)) if n%30==0]

def eg_data(f: str):
  [print(o(col)) for col in Data(csv(f)).cols.y]

def eg_tree(f: str):
  d = Data(csv(f))
  random.shuffle(d.rows)
  d2 = clone(d, d.rows[:the.learn.Budget])
  showTree(build(d2, d2.rows))

def eg_ranks():
  d = {}
  for j in range(1, 21):
    k, lam = (2, 10) if j <= 5 else (1, 20)
    d[f"t{j}"] = [lam*(-math.log(1-random.random()))**(1/k)
                   for _ in range(50)]
  print("\nTop Tier Treatments:")
  for k, num in bestRanks(d).items(): print(f"  {k:<5} median: {o(mid(num))}")

def eg_test(f: str):
  d, outs = Data(csv(f)), Num("win")
  win = wins(d)
  for _ in range(20):
    random.shuffle(d.rows)
    n = len(d.rows) // 2
    train,test = d.rows[:n][:the.learn.Budget], d.rows[n:]
    d2 = clone(d, train)
    t = build(d2, d2.rows)
    guess = sorted(test,key=lambda r: mid(leaf(t, r).y))
    top = min(guess[:the.learn.Check], key=lambda r: disty(d2, r))
    add(outs, win(top))
  print(o(int(mid(outs))))

the = S()
[set_dot(the, k, thing(v)) for k, v in re.findall(r"([\w.]+)=(\S+)", __doc__)]

if __name__ == "__main__": cli(globals(), the)
