---
title: nb — Naive Bayes
nav_order: 20
prereqs: [ezr]
new_concepts: 30
reused_concepts: 0
repl_prompts: 12
---

![License](https://img.shields.io/badge/license-MIT-blue)
![Lang](https://img.shields.io/badge/lang-fun-purple)

# nb.md — naive Bayes classifier

**Source:** [`nb.fun`](../nb.fun)
**See also:** [glossary](glossary.md) · [syllabus](syllabus.md)
**Prerequisite:** ran `make install` (see [home](index.md))

## Big picture

Naive Bayes asks: given the values in this row, which class is
most probable? It answers with three ideas glued together — Bayes'
rule (invert observed→hidden), independence assumption (treat
features separately), and online learning (classify and train at
the same time).

## Problem

Input: a CSV file. Last column (or any column ending `!`) is the
class label. Other columns are features (numeric or symbolic).
Output: per-row predicted class plus a confusion matrix at the end.

## Approach

For each incoming row: predict its class using everything seen so
far, record predicted vs actual, then add the row to the model.
After all rows, summarize in a confusion matrix and derived
metrics (recall, precision, G-score). For hyper-parameter tuning,
run many trials and rank treatments by statistical equivalence.

## Architecture

```
                CSV
                 │
                 ▼
            ┌────────┐    add()     ┌─────────────┐
   row ───▶ │  Data  │ ──────────▶  │ Cols(x, y)  │
            └────────┘              └─────────────┘
                 │                        │
                 │ for each row,          │ per col:
                 │ after warm-up          │  Num → mu, sd
                 ▼                        │  Sym → has[v]
            ┌──────────┐                  │
            │ argmax   │ ◀────────────────┘
            │ likes()  │   per class
            └──────────┘
                 │
                 ▼
            confusion matrix → stats → G-score → rank
```

## Key structures

- `Num{at, txt, n, mu, m2, sd}` — numeric column summary
- `Sym{at, txt, n, has}` — categorical column with value counts
- `Data{rows, cols}` — rows + per-column summaries
- `cm[want][got]` — confusion matrix
- `the` — config (k, m, wait, file)

## Walkthrough

### Lecture 1 — columns + type-marker dispatch

```fun
-- @1,2,4
Num := fun(at, txt):
  !{is=NUM, at=at or 0, txt=txt or "",
    n=0, mu=0, m2=0, sd=0}

Sym := fun(at, txt):
  !{is=SYM, at=at or 0, txt=txt or "",
    n=0, has={}}

add = fun(it, v):
  if (it.is == DATA): _data(it, v); !v
  if (it.is == COLS): _cols(it, v); !v
  if (it.is == SYM):  _sym(it, v);  !v
  _num(it, v)
  !v
```

[#1 Num column](glossary.md#1-num-column) and
[#2 Sym column](glossary.md#2-sym-column) are plain tables tagged
with an `is` string. [#4 type marker dispatch](glossary.md#4-type-marker-dispatch)
in `add` switches on that string — no metatables, no inheritance.

The Num column never stores values. Just running statistics via
[#3 Welford's algorithm](glossary.md#3-welfords-algorithm).

```fun
-- @3
_num := fun(num, v):
  if (v == "?"): !nil
  num.n += 1
  d := v - num.mu
  num.mu += d / num.n
  num.m2 += d * (v - num.mu)
  num.sd = num.n < 2 and 0 or sqrt(num.m2/(num.n - 1))
```

    [1]> ./fun nb.fun --testNum
    (silent on success — see eq() inside --testNum)

    [2]> ./fun nb.fun --testSym
    (silent on success)

### Lecture 2 — data plumbing

Header row picks column types by case (`Age` → Num, `name` → Sym),
column suffix picks role (`Class!` → y, `Weight-` → x, `IdX` →
ignore).

```fun
-- @5,6,7,9,10
Cols := fun(names):
  all := {}
  for at,txt in ipairs(names): push(all, Col(at, txt))
  xs, ys := {}, {}
  for _,c in ipairs(all):
    if (not c.txt:find"[!X]$"): push(xs, c)
    if (c.txt:find"!$"): push(ys, c)
  !{is=COLS, names=names, all=all, x=xs, y=ys}

Data := fun(txt, src):
  data := {is=DATA, txt=txt or "", rows={}, cols=nil}
  if (src):
    for row in src: add(data, row)
  !data
```

[#5 Cols factory](glossary.md#5-cols-factory) splits names into
[#6 independent vs class column](glossary.md#6-independent-vs-class-column)
buckets. [#7 Data container](glossary.md#7-data-container) loads
rows on demand from any iterator — typically a
[#9 CSV iterator](glossary.md#9-csv-iterator) which streams one
row at a time and runs every token through
[#10 type coercion](glossary.md#10-type-coercion).

Per-class summaries need fresh empty Data with the same shape.
That's [#8 clone](glossary.md#8-clone).

```fun
-- @8
clone := fun(data, rows):
  d := Data(data.txt, nil)
  add(d, data.cols.names)
  if (rows):
    for _,r in ipairs(rows): add(d, r)
  !d
```

    [3]> ./fun nb.fun --cols
    {{is=Sym, ..., txt=Class!, ...}}

    [4]> ./fun nb.fun --data
    {is=Num, ..., mu=23.45, ...}

### Lecture 3 — likelihood + Bayes

Per-feature likelihood is type-dispatched.

```fun
-- @13,14,16
SYM_like := fun(sym, v, prior):
  n := (sym.has[v] or 0) + the.k * (prior or 0)
  !max(1/BIG, n / (sym.n + the.k + 1/BIG))

NUM_like := fun(num, v):
  z := 1/BIG
  var := num.sd^2 + z
  !(1 / sqrt(2 * pi * var)) * exp(-((v - num.mu)^2) / (2 * var))
```

[#13 symbolic likelihood](glossary.md#13-symbolic-likelihood) is
count-based with [#16 Laplace smoothing](glossary.md#16-laplace-smoothing)
controlled by `the.k`.
[#14 Gaussian likelihood](glossary.md#14-gaussian-likelihood)
treats numeric features as normal — uses density, not point mass.

The full row likelihood combines class prior with feature
likelihoods.

```fun
-- @11,12,15,17,18
likes := fun(data, row, nall, nh):
  b := (#data.rows + the.m) / (nall + the.m * nh)
  s := sum(data.cols.x, fun(c):
             v := row[c.at]
             !v == "?" and 0 or log(like(c, v, b))
           end)
  !log(b) + s
```

[#11 Bayes' rule](glossary.md#11-bayes-rule) says posterior ∝
likelihood × prior. The [#12 prior probability](glossary.md#12-prior-probability)
`b` is computed with [#17 m-estimate](glossary.md#17-m-estimate)
smoothing.
[#18 naive independence](glossary.md#18-naive-independence) is
the `sum` over independent feature contributions — feature
correlations are ignored.

[#15 log-likelihood](glossary.md#15-log-likelihood) prevents
underflow: `log(prior) + Σ log(P(featᵢ | class))` instead of
multiplying tiny probabilities.

    [5]> ./fun nb.fun --like
    0.013...    0.428...

    [6]> ./fun nb.fun --likes
    -47.234...

### Lecture 4 — online algorithm + confusion matrix

```fun
-- @19,20,21,22
nb := fun(data):
  klasses, cm := {}, {}
  n, nk := 0, 0
  klassAt := data.cols.y[1].at
  for _,row in ipairs(data.rows):
    want := row[klassAt]
    if (not klasses[want]):
      nk += 1
      klasses[want] = clone(data)
      klasses[want].txt = want
      cm[want] = {}
    if (n > the.wait):
      got := most(klasses, fun(_,d): !likes(d, row, n, nk) end)
      if (got):
        cm[want][got] = 1 + (cm[want][got] or 0)
    n += 1
    add(klasses[want], row)
  !cm
```

[#21 online classify-then-train](glossary.md#21-online-classify-then-train)
is the loop: predict, score, train. The first `wait` rows are
training-only — the [#20 warm-start period](glossary.md#20-warm-start-period)
keeps random guesses from polluting the score.

[#19 argmax classification](glossary.md#19-argmax-classification)
via `most` picks the class with highest log-likelihood.

[#22 confusion matrix](glossary.md#22-confusion-matrix) `cm` is a
nested map: `cm[want][got]` counts instances per (actual, predicted)
pair.

    [7]> ./fun nb.fun --nb
    (table of n, tn, fn, fp, tp, pd, pf, prec, acc, g, class)

    [8]> ./fun nb.fun --diabetes
    (same table, diabetes dataset)

### Lecture 5 — metrics

```fun
-- @24,25,26,27,28
rec  := tp / (tp + fn + 1e-32)
spec := tn / (tn + fp + 1e-32)
g    := 2 * rec * spec / (rec + spec + 1e-32)
row  := {class=tostring(pos), n=n,
         tn=tn, fn=fn, fp=fp, tp=tp,
         pd  =pct(tp,    tp+fn),    -- recall
         pf  =pct(fp,    fp+tn),    -- false alarm
         prec=pct(tp,    tp+fp),    -- precision
         acc =pct(tp+tn, n),        -- accuracy
         g   =floor(100*g + 0.5)}
```

For a [#23 critical class](glossary.md#23-critical-class), reduce
multi-class to binary and report:

- [#24 recall (pd)](glossary.md#24-recall-pd) — found positives
- [#25 false alarm (pf)](glossary.md#25-false-alarm-pf) — wrong flags
- [#26 precision](glossary.md#26-precision) — trustworthiness of positives
- [#27 accuracy](glossary.md#27-accuracy) — overall (misleading on imbalance)
- [#28 G-score](glossary.md#28-g-score) — harmonic mean of recall and specificity

G-score is the headline metric for the `--experiment` sweep:
single number balancing detection vs false alarms.

    [9]> ./fun nb.fun --soybean
    (per-class metrics for soybean dataset)

    [10]> ./fun nb.fun -w 30 --nb
    (run with 30-row warm-start instead of default 5)

### Lecture 6 — statistical ranking

The `--experiment` sweep runs naive Bayes 20 times for each of
4 sample sizes × 3 k values × 3 m values = 36 treatments. Then
ranks them by G-score.

```fun
-- @29,30
sames := fun(dict):
  names := [k for k,_ in pairs(dict)]
  nums  := {}
  for _,nm in ipairs(names): nums[nm] = adds(dict[nm], Num())
  sort(names, fun(a,b): !nums[a].mu > nums[b].mu end)
  out := {}
  rank := 1
  lead := names[1]
  for _,nm in ipairs(names):
    if (nm ~= lead):
      sdPool := sqrt((nums[lead].sd^2 + nums[nm].sd^2) / 2)
      eps    := max(sdPool * 0.35, 1)
      if (not same(dict[lead], dict[nm], eps)):
        rank += 1
        lead = nm
    push(out, {name=nm, num=nums[nm], rank=rank})
  !out
```

[#29 pooled SD](glossary.md#29-pooled-sd) gives the scale for
"meaningful difference" — multiplying by 0.35 is Cohen's
small-effect cutoff.

[#30 statistical ranking](glossary.md#30-statistical-ranking)
chains: keep promoting treatments to the same rank as long as
they're statistically indistinguishable from the current group's
lead. Three escalating tests gate equivalence: Cohen's d (cheap),
Cliff's delta (effect size), Kolmogorov–Smirnov (distribution
shape).

Result: rank-1 group is the *honest* set of best treatments —
not just the single max.

    [11]> ./fun nb.fun --experiment
    G-score on 'tested_positive' (rank 1 = top tier):
       1  n=200,k=1,m=1   66.50    5.52
       1  n=200,k=1,m=2   66.40    3.72
       ...

    [12]> ./fun nb.fun -k 2 -m 0 --experiment
    (sweep with hand-picked k, m baseline)

## Limitations

- **Independence is naive** — correlated features get
  double-counted. Words "buy" and "now" in spam carry overlapping
  signal that the model treats as twice the evidence.
- **Cold start** — before warm-up, every prediction is random.
  The `wait` parameter trades early data points for prediction
  honesty.
- **Imbalanced classes inflate accuracy** — 95%-negative data
  scores 95% accuracy from "always say no." Critical class +
  G-score is the antidote.
- **Numeric assumes Gaussian** — bimodal or skewed numeric
  features get a poor likelihood. Discretize or transform if you
  see this.

## Shortcuts made

- **String type markers, not metatables** — `it.is == NUM` for
  dispatch. Production might use proper classes; we keep state
  inspectable.
- **No held-out test set** — online classify-then-train gives
  prequential evaluation. Equivalent to a 1-step rolling test
  but doesn't separate trends across data eras.
- **Critical class chosen by filename** — `--experiment` looks
  at `the.f` to pick the target class. A real tool would let
  you pass `--target tested_positive`.
- **G-score is one of many** — F1, MCC, ROC-AUC are also
  reasonable. We picked G for symmetry between TPR and TNR.

## Exercises

### Week 1 — prompts [1]-[6]
Port each prompt's logic to Python. Match output. Submit
`nb_part1.py` covering: Num/Sym/Cols, CSV ingestion, likelihood
calculations, log-Bayes prediction.

### Week 2 — prompts [7]-[12]
Port the online algorithm, confusion matrix, metrics, and the
statistical-ranking sweep. Add at least one modify-band variation
(e.g., change `the.wait`, sweep different k×m grid). Submit
`nb_part2.py` + `nb_notes.md` explaining observed shifts.

### Self-check
Answers in `nb_test.zip` (password: see LMS).
