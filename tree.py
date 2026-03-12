#!/usr/bin/env python3 -B
from time import perf_counter_ns as now
import math, re, random, sys, bisect
from types import SimpleNamespace as S
from typing import Any, Iterable

of = type
the = S(leaf=2, Budget=50, Show=30, seed=1, p=2, cliffs=0.195,
        conf=1.36, eps=0.35, Check=5)

class Obj:
  __repr__ = lambda i: i.__class__.__name__+o(i.__dict__)+"}"

class Tree(Obj):
  def __init__(i, sc):
    i.sc,i.col,i.cut,i.L,i.R,i.mids,i.y = sc,0,0,None,None,{},Num()

class Num(Obj):
  def __init__(i, s="", a=0):
    i.txt,i.at,i.n,i.mu,i.m2,i.goal = s,a,0,0,0,s[-1:]!="-"

class Sym(Obj):
  def __init__(i, s="", a=0): i.txt,i.at,i.n,i.has = s,a,0,{}

class Data(Obj):
  def __init__(i,src=None):
    src = iter(src or {})
    i.rows,i.cols = [], Cols(next(src))
    adds(src,i)

class Cols(Obj):
  def __init__(i, n: list):
    i.names, i.x, i.y, i.all = n, [], [], []
    for j, s in enumerate(n):
      i.all += [(Num if s[0].isupper() else Sym)(s, j)]
      if not s.endswith("X"):
        (i.y if re.search(r"[+\-!]$", s) else i.x).append(i.all[-1])

Qty  = int | float
Atom = str | bool | Qty
Row  = list[Atom]
Rows = list[Row]
Col  = Num  | Sym
It   = Data | Col

def adds(src: Iterable, it=None) -> It:
  it = it or Num(); [add(it, v) for v in (src or [])]; return it

def add(x, v:Any) -> Any:
  if v == "?": return v
  if  of(x) == Cols: [add(c, v[c.at]) for c in x.all]
  elif of(x) == Data:
    if not x.cols: x.cols = Cols(v)
    else: x.rows += [v]; add(x.cols, v)
  else:
    x.n += 1
    if of(x) == Num:
      d = v - x.mu; x.mu += d/x.n; x.m2 += d*(v - x.mu)
    else: x.has[v] = 1 + x.has.get(v, 0)
  return v

def mid(x:Col) -> Atom:
  return x.mu if of(x) == Num else max(x.has, key=x.has.get)

def spread(x:Col) -> Qty:
  if of(x) == Sym:
    return -sum(v/x.n*math.log2(v/x.n) for v in x.has.values())
  return (x.m2/(x.n - 1))**.5 if x.n > 1 else 0

def norm(n: Num, v:Qty) -> float:
  if v == "?": return v
  sd = spread(n) + 1e-32
  return 1/(1 + math.exp(-1.7*(v - n.mu)/sd))

def disty(d: Data, r: list) -> float:
  ls = [abs(norm(c, r[c.at]) - c.goal)**the.p for c in d.cols.y]
  return (sum(ls)/len(ls))**(1/the.p) if ls else 0

def clone(d: Data, rs: list=[]) -> Data:
  return adds(rs, Data([d.cols.names]))

def same(xs: list, ys: list, eps: float) -> bool:
  xs, ys = sorted(xs), sorted(ys)
  n, m = len(xs), len(ys)
  if abs(xs[n//2] - ys[m//2]) <= eps: return True
  gt = lt = 0
  for a in xs:
    gt += bisect.bisect_left(ys, a)
    lt += m - bisect.bisect_right(ys, a)
  if abs(gt - lt) / (n * m) > the.cliffs: return False
  ks = lambda v: abs(bisect.bisect_right(xs,v)/n
                    - bisect.bisect_right(ys,v)/m)
  return max(max(map(ks,xs)), max(map(ks,ys))) \
         <= the.conf * ((n+m)/(n*m))**0.5

def bestRanks(d: dict) -> dict:
  items = sorted(d.items(),
                 key=lambda kv: sorted(kv[1])[len(kv[1])//2])
  k0, lst0 = items[0]
  best = {k0: adds(lst0, Num(k0))}
  for k, lst in items[1:]:
    if same(lst0, lst, spread(best[k0])*the.eps):
      best[k] = adds(lst, Num(k))
    else: break
  return best

# --- Splits & Build ---
def splits(c:Col, rs: list):
  if vs := [r[c.at] for r in rs if r[c.at] != "?"]:
    cuts = set(vs) if of(c)==Sym else [sorted(vs)[len(vs)//2]]
    for cut in cuts:
      fn = lambda v: v=="?" or (v==cut if of(c)==Sym else v<=cut)
      L, R = [], []
      [(L if fn(r[c.at]) else R).append(r) for r in rs]
      yield cut, L, R

def grow(t: Tree, d: Data, rs: list):
  bestW, best = 1e32, None
  for c in d.cols.x:
    for cut, L, R in splits(c, rs):
      if min(len(L), len(R)) >= the.leaf:
        w = sum(spread(adds([t.sc(r) for r in s]))
                * len(s) for s in (L,R))
        if w < bestW: bestW, best = w, (c, cut, L, R)
  if best:
    t.col, t.cut, L, R = best
    t.L, t.R = build(Tree(t.sc), d, L), build(Tree(t.sc), d, R)

def build(t: Tree, d: Data, rs: list) -> Tree:
  t.y = adds([t.sc(r) for r in rs])
  t.mids = {c.txt: mid(c) for c in clone(d,rs).cols.y}
  if len(rs) >= 2 * the.leaf: grow(t, d, rs)
  return t

def nodes(t: Tree, l: int=0, p: str=""):
  yield t, l, p
  if t.L:
    op = ("<=",">") if of(t.col)==Num else ("==","!=")
    for k, op_s in sorted([(t.L, op[0]), (t.R, op[1])],
                          key=lambda x: mid(x[0].y)):
      yield from nodes(k, l+1, f"{t.col.txt} {op_s} {o(t.cut)}")

def leaf(t: Tree, r: Row) -> Tree:
  if not t.L: return t
  v = r[t.col.at]
  go = (v != "?" and (v<=t.cut if of(t.col)==Num else v==t.cut))
  return leaf(t.L if go else t.R, r)

def thing(s: str) -> Atom:
  for fun in [int,float,
              lambda s: {"true":True,"false":False}.get(s.lower(),s)]:
    try: return fun(s)
    except: ...

def o(x):
  if of(x)==float: return f"{x:.2f}"
  if of(x)==dict:
    return "{"+", ".join(f"{k}={o(v)}" for k,v in sorted(x.items()))+"}"
  if of(x)==list: return "{"+", ".join(map(o, x))+"}"
  return str(x)

def csv(f, clean=lambda s: s.partition("#")[0].split(",")):
  with open(f, encoding="utf-8") as file:
    for s in file:
      r = clean(s)
      if any(x.strip() for x in r):
        yield [thing(x.strip()) for x in r]

def eg_csv(f: str):
  [print(row) for n,row in enumerate(csv(f)) if n%30==0]

def eg_data(f: str):
  [print(o(col)) for col in Data(csv(f)).cols.y]

def eg_tree(f: str):
  d= Data(csv(f))
  random.shuffle(d.rows)
  d2 = clone(d, d.rows[:the.Budget])
  for n, l, p in nodes(
      build(Tree(lambda r: disty(d2, r)), d2, d2.rows)):
    print(f"{'|   '*(l-1)+p if l>0 else '':<{the.Show}}"
          f",{o(mid(n.y)):>4} "
          f",({n.y.n:3}), {o(n.mids)}")

def eg_ranks():
  d = {}
  for j in range(1, 21):
    k, lam = (2, 10) if j <= 5 else (1, 20)
    d[f"t{j}"] = [lam*(-math.log(1-random.random()))**(1/k)
                   for _ in range(50)]
  print("\nTop Tier Treatments:")
  for k, num in bestRanks(d).items():
    print(f"  {k:<5} median: {o(mid(num))}")

def wins(d: Data):
  ds = [disty(d, r) for r in d.rows]
  lo, med = min(ds), sorted(ds)[len(ds)//2]
  return lambda r: int(
    100*(1 - ((disty(d, r) - lo) / (med - lo + 1e-32))))

def eg_test(f: str):
  d, outs = Data(csv(f)), Num("win")
  win = wins(d)
  for _ in range(20):
    random.shuffle(d.rows)
    n = len(d.rows) // 2
    test, d2 = d.rows[n:], clone(d, d.rows[:n][:the.Budget])
    t = build(Tree(lambda r: disty(d2, r)), d2, d2.rows)
    test.sort(key=lambda r: mid(leaf(t, r).y))
    top = sorted(test[:the.Check], key=lambda r: disty(d2, r))
    add(outs, win(top[0]))
  print(o(int(mid(outs))))

if __name__ == "__main__":
  args = sys.argv[1:]; random.seed(the.seed)
  while args:
    k = re.sub(r"^-+", "", args.pop(0))
    if fn := globals().get(f"eg_{k}"):
      fn(*[thing(args.pop(0)) for arg in fn.__annotations__])
    elif hasattr(the, k): setattr(the, k, thing(args.pop(0)))
