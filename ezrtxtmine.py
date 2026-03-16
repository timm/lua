#!/usr/bin/env python3 -B
"""textmine.py: complement naive bayes + active learning
(c) 2026 Tim Menzies timm@ieee.org, MIT license"""
import random, statistics
from math import log
from collections import defaultdict
from ez import (Data, Row, csv, cli, align,
                the, say, filename, clone)
from prep import dataFromPrep

# --- CNB core ---------------------------------------------------
def cnb(data, rows=None, alpha=1.0):
  rows, key = rows or data.rows, data.cols.klass
  freq  = defaultdict(lambda: defaultdict(float))
  total, klasses = defaultdict(float), set()
  for r in rows:
    k = r[key]; klasses.add(k)
    for at in data.cols.x:
      v = r[at] if r[at] != "?" else 0
      freq[k][at] += v; total[at] += v
  T, n, ws = sum(total.values()), len(data.cols.x), {}
  for k in klasses:
    den = T + n*alpha - sum(freq[k].values()) + 1e-32
    ws[k] = {a: -log((total[a]+alpha
      -freq[k].get(a,0)+1e-32)/den) for a in total}
  if the.text.Norm:
    ws = {k: {a: v/(sum(abs(x) for x in w.values())
           or 1e-32) for a,v in w.items()}
        for k,w in ws.items()}
  return ws

def cnbLike(ws, at, row, k):
  v = row[at] if row[at] != "?" else 0
  return v * ws[k].get(at, 0)

def cnbLikes(ws, data, row, k):
  return sum(cnbLike(ws, at, row, k) for at in data.cols.x)

# --- Helpers ----------------------------------------------------
def _setup(src):
  data = Data(csv(src)) if isinstance(src, str) else dataFromPrep(src)
  key  = data.cols.klass
  pos  = [i for i, r in enumerate(data.rows) if r[key] == "yes"]
  return data, key, pos, set(range(len(data.rows)))

def _best(ws, data, r):
  return max(ws, key=lambda k: cnbLikes(ws, data, r, k))

def _recall(ws, data, key):
  ps = [r for r in data.rows if r[key] == "yes"]
  if not ps: return 0
  return int(100*sum(_best(ws,data,r) == "yes" for r in ps)/len(ps))

def _iqr(vs):
  qs = statistics.quantiles(vs, n=4); return qs[2] - qs[0]

def _warm(pos, idx):
  ti   = random.sample(pos, min(the.text.yes, len(pos)))
  rest = list(idx - set(ti))
  return set(ti + random.sample(rest, min(the.text.no, len(rest))))

# --- Random baseline --------------------------------------------
def text_mining(src):
  data, key, pos, idx = _setup(src)
  out = [_recall(cnb(data, [data.rows[i] for i in
         _warm(pos, idx)]), data, key)
         for _ in range(the.text.valid)]
  md = statistics.median(out)
  print(f"Random {the.text.yes}+/{the.text.no}-: "
        f"pd={md} iqr={_iqr(out) if len(out)>1 else 0}")
  return True

# --- Active learning --------------------------------------------
def active(src):
  data, key, pos, idx = _setup(src)
  trails = []
  for _ in range(the.text.valid):
    lab = _warm(pos, idx); pool = idx - lab; trail = []
    while True:
      ws = cnb(data, [data.rows[i] for i in lab])
      trail.append(_recall(ws, data, key))
      if len(lab) >= the.learn.Budget or not pool: break
      pick = max(pool, key=lambda i:
        cnbLikes(ws, data, data.rows[i], "yes"))
      lab.add(pick); pool.discard(pick)
    trails.append(trail)
  n  = min(len(t) for t in trails)
  w0 = the.text.yes + the.text.no
  print(f"\n{'='*40}\nActive CNB {the.text.valid}x "
        f"warm={w0} B={the.learn.Budget}\n{'='*40}")
  rows = [["labeled", "pd", "iqr"]]
  for s in range(n):
    vs = [t[s] for t in trails]; md = statistics.median(vs)
    rows.append([w0+s, md, _iqr(vs) if len(vs) > 1 else 0])
  align(rows); return True

# --- Demos ------------------------------------------------------
def eg_like(file:filename):
  "show CNB scores for first 5 rows"
  data = Data(csv(file)); ws = cnb(data)
  rows = [["want", "got", "score"]]
  for r in data.rows[:5]:
    got = _best(ws, data, r)
    sc  = max(cnbLikes(ws, data, r, k) for k in ws)
    rows.append([r[data.cols.klass], got, round(sc, 2)])
  align(rows)

def eg_sweep(file:filename):
  "vary sample size: 10, 20, 40"
  for y in [10, 20, 40]:
    the.text.yes = the.text.no = y; text_mining(file)

def eg_data(file:filename):
  "random baseline evaluation"
  return text_mining(file)

def eg_active(file:filename):
  "active learning: warm start then acquire to budget"
  return active(file)

if __name__ == "__main__": cli(globals())
