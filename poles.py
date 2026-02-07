#!/usr/bin/env python3 -B
import random,sys
from math import exp,sqrt

class OBJ(dict):
  __getattr__,__setattr__ = dict.__getitem__,dict.__setitem__
  __repr__ = lambda i: o(i)

the=OBJ(seed=1, p=2)
BIG=1E32

#-------------------------------------------------------------------------
def NUM(**d): return OBJ(it=NUM, **d, mu=0, m2=0)
def SYM(**d): return OBJ(it=SYM, **d, has={})

def COL(at=0,txt=" "): 
  what = NUM if txt[0].isupper else SYM
  return what(at=at,txt=txt,n=0,goal=txt[-1]!="-")

def DATA(items=None,s=""):
 return adds(items, OBJ(it=DATA, n=0, s=s, rows=[], cols=None, mids=None))

def COLS(names):
  cols= [COL(at=n,txt=s) for n,s in enumerate(names)]
  return OBJ(it=COLS, names=names, all=cols,
             x= [c for c in cols if c.txt[-1] not in "-+!X"],
             y= [c for c in cols if c.txt[-1]     in "-+!" ])

def clone(data, rows=None): 
  return DATA([data.cols.names] + (rows or []))

#-------------------------------------------------------------------------
def adds(items=None, it=None):
  it = it or NUM(); [add(it,item) for item in (items or [])]; return it

def sub(i,v): return add(i, v, w=-1)

def add(i, v, w=1):
  if v!="?": 
    i.n += w
    if   SYM  is i.it : i.has[v] = w + i.has.get(v,0)
    elif NUM  is i.it : d = v-i.mu; i.mu += w*d/i.n; i.m2 += w*d*(v-i.mu)
    elif DATA is i.it :
      if not i.cols: i.cols=COLS(v)
      else: 
        i.mids = None
        for col in i.cols.all: add(col, v[col.at], w)
        (i.rows.append if w>0 else i.rows.remove)(v)
  return v

def sd(num): return 0 if num.n < 2 else sqrt(max(0,num.m2) / (num.n - 1))

def mid(col): print(col); return mode(col) if SYM is col.it else col.mu
def mode(sym): return max(sym.has, key=sym.has.get)

def mids(data):  
  data.mids = data.mids or [mid(col) for col in data.cols.all]
  return data.mids

def z(num,v): return max(-3,min(3, (v -  num.mu) / (sd(num) + 1/BIG)))
def norm(num,v): return 1 / (1 + exp( -1.7 * z(num,v)))

def minkowski(items):
  n,d = 0,0
  for item in items: n, d = n+1, d+item ** the.p
  return 0 if n==0 else (d / n) ** (1 / the.p)

def disty(data, row):
  return minkowski((norm(y,row[y.at]) - y.goal) for y in data.cols.y)

def distx(data,row1,row2):
  return minkowski(aha(x, row1[x.at], row2[x.at]) for x in data.cols.x)

def aha(col,u,v):
  if u==v=="?": return 1
  if SYM is col.it : return u != v
  u,v = norm(col,u), norm(col,v)
  u = u if u != "?" else (0 if v>0.5 else 1)
  v = v if v != "?" else (0 if u>0.5 else 1)
  return abs(u - v)

def order(data):
  data.rows.sort(key=lambda r: disty(data,r))
  return data

def likely(data):
  yn,y,n = clone(data), None, None
  maybe = lambda r: distx(yn,row,mid(y)) < disty(yn,row,mid(n))
  for j,row in enumerate(shuffle(data.rows)):
    if j <= 4:
      add(yn, row)
      if j == 4: 
        order(yn)
        y, n = clone(data, yn.rows[:2]), clone(data, yn.rows[2:])
    else:
      add(y if maybe(row) else n, row)
      if y.n > sqrt(y.n + n.n):
        order(y)
        add(n, sub(y, y.rows[-1]))
  return maybe

#-------------------------------------------------------------------------
def shuffle(lst): random.shuffle(lst); return lst

def o(t):
  match t:
    case _ if type(t) is type(o): return t.__name__
    case dict(): return "{"+" ".join(f":{k} {o(t[k])}" for k in t)+"}"
    case float(): return f"{int(t)}" if int(t) == t else f"{t:.2f}"
    case list(): return "[" + ", ".join(o(x) for x in t) + "]"
    case tuple(): return "(" + ", ".join(o(x) for x in t) + ")"
    case _: return str(t)

def cast(s):
  for f in [int,float,str]:
    try: return f(s)
    except: ...

def csv(f):
  with open(f,encoding="utf-8") as file:
    for s in file: 
      if s:=s.strip(): yield [cast(x.strip()) for x in s.split(",")]

def main(funs):
  args = iter(sys.argv[1:])
  for s in args:
    if f := funs.get(f"eg_{s[1:].replace('-','_')}"):
      random.seed(the.seed)
      f( *[t(next(args)) for t in f.__annotations__.values()])

#-------------------------------------------------------------------------
def eg__s(n:int): print(n)

def  eg__csv(f:str):
  data = DATA(csv(f))
  for row in data.rows[::25]: print(o(row))

def  eg__like(f:str):
  data = DATA(csv(f))
  likely(data)

if __name__ == "__main__": main(globals())
