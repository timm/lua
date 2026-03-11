#!/usr/bin/env python3 -B
import math, re, random, sys, bisect
from types import SimpleNamespace as S
from typing import Any, Iterable

of = type
the = S(leaf=3, Budget=50, Show=30, seed=1, p=2, cliffs=0.195, conf=1.36, eps=0.35)

class Num:
  def __init__(i, s="", a=0): i.txt,i.at,i.n,i.has,i.ok,i.goal = s,a,0,[],0,s[-1:]!="-"
class Sym:
  def __init__(i, s="", a=0): i.txt,i.at,i.n,i.has = s,a,0,{}
class Cols:
  def __init__(i, n: list):
    i.names, i.x, i.y, i.all = n, [], [], []
    for j, s in enumerate(n):
      c = (Num if s[0].isupper() else Sym)(s, j); i.all.append(c)
      if not s.endswith("X"): (i.y if re.search(r"[+\-!]$", s) else i.x).append(c)
class Data:
  def __init__(i): i.rows, i.cols = [], None
class Tree:
  def __init__(i, sc): i.sc,i.col,i.cut,i.L,i.R,i.mids,i.y = sc,0,0,None,None,{},Num()

Qty  = int | float
Atom = str | bool | Qty
Row  = list[Atom]
Rows = list[Row]
Col  = Num  | Sym
It   = Data | Col 

def adds(src: list, it=None) -> It :
  it = it or Num(); [add(it, v) for v in (src or [])]; return it

def add(x, v:Any, w: int=1) -> Any:
  if v == "?": return v
  if  of(x) == Cols: [add(c, v[c.at], w) for c in x.all]
  elif of(x) == Data:
    if not x.cols: x.cols = Cols(v)
    else: (x.rows.append if w>0 else x.rows.remove)(v); add(x.cols, v, w)
  else:
    x.n += w
    if of(x) == Num: x.ok = 0; (x.has.append if w>0 else x.has.remove)(v)
    else: x.has[v] = x.has.get(v, 0) + w
  return v

def ok(n: Num) -> Num:
  if not n.ok: n.has.sort(); n.ok = 1
  return n

def mid(x:Col)-> Atom:
  if of(x) == Sym: return max(x.has, key=x.has.get) 
  h = ok(x).has; return h[len(h)//2] if h else 0

def spread(x:Col) -> Qty:
  if of(x) == Sym: return -sum(v/x.n*math.log2(v/x.n) for v in x.has.values())
  h, m = ok(x).has, len(x.has)
  a, b = (m//10, 9*m//10) if m > 4 else (0, m-1)
  return (h[b] - h[a])/2.56 if m else 0

def norm(n: Num, v:Qty) -> float:
  h = ok(n).has
  return v if v == "?" else max(0, min(1, (v-h[0]) / (h[-1]-h[0] + 1e-32)))

def disty(d: Data, r: list) -> float:
  ls = [abs(norm(c, r[c.at]) - c.goal)**the.p for c in d.cols.y]
  return (sum(ls)/len(ls))**(1/the.p) if ls else 0

def clone(d: Data, rs: list=[]) -> Data:
  return adds(rs, adds([d.cols.names], Data()))

def same(x: Num, y: Num, eps: float) -> bool:
  xs, ys, n, m = ok(x).has, ok(y).has, len(x.has), len(y.has)
  if abs(mid(x) - mid(y)) <= eps: return True
  gt = lt = 0
  for a in xs: 
    gt += bisect.bisect_left(ys, a) 
    lt += m - bisect.bisect_right(ys, a)
  if abs(gt - lt) / (n * m) > the.cliffs: return False
  ks = lambda v: abs(bisect.bisect_right(xs, v)/n - bisect.bisect_right(ys, v)/m)
  return max(max(map(ks, xs)), max(map(ks, ys))) <= the.conf * ((n+m)/(n*m))**0.5

def bestRanks(d: dict) -> dict:
  num_all = Num("overall")
  all_c = [adds(adds(lst, Num(k)).has, num_all) for k, lst in d.items()]
  all_c.sort(key=mid)
  best = {all_c[0].txt: all_c[0]}
  for c in all_c[1:]:
    if same(all_c[0], c, spread(num_all) * the.eps): best[c.txt] = c
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
        w = sum(spread(adds([t.sc(r) for r in s])) * len(s) for s in (L,R))
        if w < bestW: bestW, best = w, (c, cut, L, R)
  if best:
    t.col, t.cut, L, R = best
    t.L, t.R = build(Tree(t.sc), d, L), build(Tree(t.sc), d, R)

def build(t: Tree, d: Data, rs: list) -> Tree:
  t.y = adds([t.sc(r) for r in rs])
  t.mids = {c.txt: mid(c) for c in clone(d,rs).cols.y}
  if len(rs) >= 2 * the.leaf: grow(t, d, rs)
  return t
  
def thing(s: str):
  s = s.strip()
  if s.lower() in ["true", "false"]: return s.lower() == "true"
  try: return int(s)
  except:
    try: return float(s)
    except: return s

def o(x):
  if of(x) == float: return f"{x:.2f}"
  if of(x) == dict:  return "{"+", ".join(f"{k}={o(v)}" for k,v in sorted(x.items()))+"}"
  if of(x) == list:  return "{"+", ".join(map(o, x))+"}"
  return str(x)

def nodes(t: Tree, l: int=0, p: str=""):
  yield t, l, p
  if t.L:
    op = ("<=", ">") if of(t.col) == Num else ("==", "!=")
    for k, op_s in sorted([(t.L, op[0]), (t.R, op[1])], key=lambda x: mid(x[0].y)):
      yield from nodes(k, l+1, f"{t.col.txt} {op_s} {o(t.cut)}")

def eg_data(f: str):
  with open(f) as fp: d = adds([list(map(thing, l.split(","))) for l in fp], Data())
  random.shuffle(d.rows); d2 = clone(d, d.rows[:the.Budget])
  for n, l, p in nodes(build(Tree(lambda r: disty(d2, r)), d2, d2.rows)):
    print(f"{'|   '*(l-1)+p if l>0 else '':<{the.Show}},{o(mid(n.y)):>4} "
          f",({n.y.n:3}), {o(n.mids)}")

def eg_ranks():
  dict_ = {}
  for j in range(1, 21):
    k, lam = (2, 10) if j <= 5 else (1, 20)
    dict_[f"t{j}"] = [lam * (-math.log(1 - random.random()))**(1/k) for _ in range(50)]
  print("\nTop Tier Treatments:")
  for k, num in bestRanks(dict_).items(): print(f"  {k:<5} median: {o(mid(num))}")

if __name__ == "__main__":
  args = sys.argv[1:]; random.seed(the.seed)
  while args:
    k = re.sub(r"^-+", "", args.pop(0))
    if fn := globals().get(f"eg_{k}"):
      fn(*[thing(args.pop(0)) for _ in range(fn.__code__.co_argcount)])
    elif hasattr(the, k): setattr(the, k, thing(args.pop(0)))
