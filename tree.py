#!/usr/bin/env python3 -B
import math, re, random, sys, bisect
from types import SimpleNamespace as o

the = o(leaf=3, Budget=50, Show=30, seed=1, p=2, cliffs=0.195, conf=1.36, eps=0.35)

# --- Types (Data Containers) ---
class Num:
  def __init__(i, s="", a=0): i.txt,i.at,i.n,i.has,i.ok,i.goal = s,a,0,[],0,s[-1:]!="-"
class Sym:
  def __init__(i, s="", a=0): i.txt,i.at,i.n,i.has = s,a,0,{}
class Cols:
  def __init__(i, n):
    i.names, i.x, i.y, i.all = n, [], [], []
    for j, s in enumerate(n):
      c = (Num if s[0].isupper() else Sym)(s, j); i.all.append(c)
      if not s.endswith("X"): (i.y if re.search(r"[+\-!]$", s) else i.x).append(c)
class Data:
  def __init__(i): i.rows, i.cols = [], None
class Tree:
  def __init__(i, sc): i.sc,i.col,i.cut,i.L,i.R,i.mids,i.y = sc,0,0,None,None,{},Num()

# --- Update ---
def adds(src, it=None):
  it = it or Num(); [add(it, v) for v in (src or [])]; return it

def add(x, v):
  if v == "?": return v
  t = type(x)
  if   t == Num:  x.n+=1; x.ok=0; x.has.append(v)
  elif t == Sym:  x.n+=1; x.has[v] = x.has.get(v, 0) + 1
  elif t == Cols: [add(c, v[c.at]) for c in x.all]
  elif t == Data:
    if x.cols: x.rows.append(add(x.cols, v))
    else:      x.cols = Cols(v)
  return v

# --- Query ---
def ok(n):
  if not n.ok: n.has.sort(); n.ok = 1
  return n

def mid(x):
  t = type(x)
  if t == Num: h = ok(x).has; return h[len(h)//2] if h else 0
  if t == Sym: return max(x.has, key=x.has.get) if x.has else None

def spread(x):
  t = type(x)
  if t == Num:
    h = ok(x).has; m = len(h)
    return (h[int(0.9*m)]-h[int(0.1*m)])/2.56 if m>1 else 0
  if t == Sym: return -sum(v/x.n * math.log2(v/x.n) for v in x.has.values() if v>0)

def norm(n, v):
  h = ok(n).has; return max(0, min(1, (v-h[0])/(h[-1]-h[0]))) if v!="?" and len(h)>1 else v

def disty(d, r):
  ls = [abs(norm(c, r[c.at]) - c.goal)**the.p for c in d.cols.y]
  return (sum(ls)/len(ls))**(1/the.p) if ls else 0

def clone(d, rs=[]):
  add(d2 := Data(), d.cols.names)
  for r in rs: add(d2, r)
  return d2

# --- Stats ---
def same(x, y, eps):
  ok(x); ok(y); xs, ys, n, m = x.has, y.has, len(x.has), len(y.has)
  if abs(mid(x) - mid(y)) <= eps: return True
  gt = lt = 0
  for a in xs: 
     gt += bisect.bisect_left(ys, a)
     lt += m - bisect.bisect_right(ys, a)
  if abs(gt - lt) / (n * m) > the.cliffs: return False
  ks = lambda v: abs(bisect.bisect_right(xs, v)/n - bisect.bisect_right(ys, v)/m)
  return max(max(map(ks, xs)), max(map(ks, ys))) <= the.conf * ((n+m)/(n*m))**0.5

def bestRanks(d):
  all_c, num_all = [], Num("overall")
  for k, lst in d.items(): n = Num(k); adds(lst, n); adds(lst, num_all); all_c.append(n)
  all_c.sort(key=mid); best = [all_c[0]]
  for j in range(1, len(all_c)):
    if same(all_c[0], all_c[j], spread(num_all) * the.eps): best.append(all_c[j])
    else: break
  return best

# --- Splits & Build ---
def leaf(c, cut, v): return v <= cut if type(c) == Num else v == cut

def cuts(c, rs):
  vs = [r[c.at] for r in rs if r[c.at] != "?"]
  if type(c) == Sym: return list(set(vs))
  vs.sort(); return [vs[len(vs)//2]] if len(vs) >= 2 else []

def step(rs, c, cut):
  L = [r for r in rs if r[c.at]!="?" and leaf(c, cut, r[c.at])]
  R = [r for r in rs if r[c.at]!="?" and not leaf(c, cut, r[c.at])]
  return (L, R) if min(len(L), len(R)) >= the.leaf else None

def build(t, d, rs):
  t.y = adds([t.sc(r) for r in rs])
  t.mids = {c.txt: mid(c) for c in clone(d, rs).cols.y}
  if len(rs) < 2 * the.leaf: return t
  bestW, best = 1e32, None
  for c in d.cols.x:
    for cut in cuts(c, rs):
      if ss := step(rs, c, cut):
        w = sum(spread(adds([t.sc(r) for r in s])) * len(s) for s in ss)
        if w < bestW: bestW, best = w, (c, cut, ss)
  if best:
    t.col, t.cut, (L, R) = best
    t.L = build(Tree(t.sc), d, L); t.R = build(Tree(t.sc), d, R)
  return t

# --- Helpers & Display ---
def thing(s):
  s = s.strip()
  for f in [int, float, lambda x: {"true":True, "false":False}.get(x, x)]:
    try: return f(s)
    except: pass

def rat(x):
  t = type(x)
  if t == float: return f"{x:.2f}"
  if t == dict:  return "{"+", ".join(sorted(f"{k}={rat(v)}" for k,v in x.items()))+"}"
  if t == list:  return "{"+", ".join(map(rat, x))+"}"
  return str(x)

def nodes(t, l=0, p=""):
  yield t, l, p
  if t.L:
    op = ("<=", ">") if type(t.col) == Num else ("==", "!=")
    for k, o in sorted([(t.L, op[0]), (t.R, op[1])], key=lambda x: mid(x[0].y)):
      yield from nodes(k, l+1, f"{t.col.txt} {o} {rat(t.cut)}")

# --- Examples ---
def eg_data(f):
  d = Data()
  with open(f) as fp: [add(d, list(map(thing, l.split(",")))) for l in fp]
  random.shuffle(d.rows); d2 = clone(d, d.rows[:the.Budget])
  for n,l,p in nodes(build(Tree(lambda r: disty(d2, r)), d2, d2.rows)):
     print(f"{'|   '*(l-1)+p if l>0 else '':<{the.Show}}",end="")
     print(f",{rat(mid(n.y)):>4} ,({n.y.n:3}), {rat(n.mids)}")

def eg_ranks(dummy):
  dict_ = {}
  for j in range(1, 21):
    k, lam = (2, 10) if j <= 5 else (1, 20)
    dict_[f"t{j}"] = [weibull(k, lam) for _ in range(50)]
  print("\nTop Tier Treatments:")
  for num in bestRanks(dict_): print(f"  {num.txt:<5} median: {rat(mid(num))}")

def weibull(k, lam): return lam * (-math.log(1 - random.random()))**(1/k)

if __name__ == "__main__":
  args = sys.argv[1:]; random.seed(the.seed)
  while args:
    k = re.sub(r"^-+", "", args.pop(0)); v = args.pop(0)
    if f"eg_{k}" in globals(): globals()[f"eg_{k}"](v)
    elif hasattr(the, k): setattr(the, k, thing(v))
