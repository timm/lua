---
title: Glossary
nav_order: 99
---

# Glossary

Strict numeric order, append-only. Numbers never reused or
reordered. `**Category:**` is a tag for grouping in prose; sort
order here is always 1, 2, 3, ...

---

## 1. Num column

**Category:** this-codebase

**Source:** functions `Num`, `_num` in `nb.fun`

**Defines:** Online numeric column. Stores incremental count `n`,
mean `mu`, sum-of-squared-deviations `m2`, and standard deviation
`sd`. No data values retained.

**Why:** Constant memory regardless of stream length. Lets one
pass build summary statistics for any size data.

**Depends on:** [#3 Welford's algorithm](glossary.md#3-welfords-algorithm)

**Used in:** [nb.md](nb.md#1-num-column)

**Added:** 2026-05

## 2. Sym column

**Category:** this-codebase

**Source:** functions `Sym`, `_sym` in `nb.fun`

**Defines:** Online categorical column. Stores `n` (total) and
`has` (value → count). No order, no inferred mean.

**Why:** Symbols have no arithmetic mean — count distribution is
the summary.

**Depends on:** none

**Used in:** [nb.md](nb.md#2-sym-column)

**Added:** 2026-05

## 3. Welford's algorithm

**Category:** math

**Source:** function `_num` in `nb.fun`

**Defines:** Online single-pass mean/variance update.
For each new value v: d = v − μ; μ += d/n; m2 += d·(v − μ_new).
Variance = m2/(n−1).

**Why:** Naive sum-of-squares loses precision for large n;
Welford is numerically stable and incremental.

**Depends on:** none

**Used in:** [nb.md](nb.md#3-welfords-algorithm)

**Refs:** Welford 1962, *Technometrics* 4(3)

**Added:** 2026-05

## 4. type marker dispatch

**Category:** code

**Source:** function `add` in `nb.fun`; markers `NUM`, `SYM`, `COLS`, `DATA`

**Defines:** Each table carries an `is` field with a string tag.
`add` switches on `it.is` to dispatch to `_num`, `_sym`, `_cols`,
or `_data`. No metatables, no method lookup.

**Why:** Plain Lua tables, no metamethod cost; string compare is
trivial. Keeps polymorphism explicit and inspectable.

**Depends on:** none

**Used in:** [nb.md](nb.md#4-type-marker-dispatch)

**Added:** 2026-05

## 5. Cols factory

**Category:** this-codebase

**Source:** functions `Cols`, `Col` in `nb.fun`

**Defines:** Takes a list of column names; builds a Num for names
starting uppercase, Sym otherwise. Returns `{x, y, all, names}`.

**Why:** Header row dictates column types. Naming convention
encodes type at the data file level.

**Depends on:** [#1 Num column](glossary.md#1-num-column),
[#2 Sym column](glossary.md#2-sym-column),
[#6 independent vs class column](glossary.md#6-independent-vs-class-column)

**Used in:** [nb.md](nb.md#5-cols-factory)

**Added:** 2026-05

## 6. independent vs class column

**Category:** this-codebase

**Source:** function `Cols` in `nb.fun`

**Defines:** Column name suffixes encode role: `!` = class output,
`X` = ignored, others = independent (x). Lists `xs`, `ys`
populated accordingly.

**Why:** Single header line carries dataset semantics — what to
predict, what to skip, what to use.

**Depends on:** [#5 Cols factory](glossary.md#5-cols-factory)

**Used in:** [nb.md](nb.md#6-independent-vs-class-column)

**Added:** 2026-05

## 7. Data container

**Category:** this-codebase

**Source:** functions `Data`, `_data` in `nb.fun`

**Defines:** Holds row list (`rows`) and column summaries
(`cols`). First added row becomes the header (defines `cols`);
subsequent rows are stored and folded into each column's stats.

**Why:** One object holds the raw data and its summary side by
side. No re-scan to compute means/counts.

**Depends on:** [#5 Cols factory](glossary.md#5-cols-factory)

**Used in:** [nb.md](nb.md#7-data-container)

**Added:** 2026-05

## 8. clone

**Category:** this-codebase

**Source:** function `clone` in `nb.fun`

**Defines:** Build a new empty `Data` with the same column
structure as a source `Data`. Optionally seed with rows.

**Why:** Per-class summaries (in `nb`) need same shape but
disjoint stats. Clone gives that without copying logic.

**Depends on:** [#7 Data container](glossary.md#7-data-container)

**Used in:** [nb.md](nb.md#8-clone)

**Added:** 2026-05

## 9. CSV iterator

**Category:** code

**Source:** function `csv` in `nb.fun`

**Defines:** Returns a closure that, on each call, yields the
next parsed row from a CSV file. Coroutine-style without
coroutines. Closes the file at EOF.

**Why:** Streams rows one at a time — constant memory on huge
files. Composable with `for row in csv(file)`.

**Depends on:** [#10 type coercion](glossary.md#10-type-coercion)

**Used in:** [nb.md](nb.md#9-csv-iterator)

**Added:** 2026-05

## 10. type coercion

**Category:** code

**Source:** function `thing` in `nb.fun`

**Defines:** Convert a string token to bool / number / string in
that order. `"true"` → `true`, `"42"` → `42`, `"hi"` → `"hi"`.

**Why:** CSV is all strings. Downstream code expects typed
values for arithmetic and equality.

**Depends on:** none

**Used in:** [nb.md](nb.md#10-type-coercion)

**Added:** 2026-05

## 11. Bayes' rule

**Category:** AI

**Source:** function `likes` in `nb.fun`

**Defines:** P(class | row) ∝ P(row | class) · P(class).
For prediction, the proportional form suffices — no need for
the normalization constant P(row).

**Why:** Inverts what we observe (features) into what we want
(class). Foundation of generative classifiers.

**Depends on:** [#12 prior probability](glossary.md#12-prior-probability),
[#13 symbolic likelihood](glossary.md#13-symbolic-likelihood),
[#14 Gaussian likelihood](glossary.md#14-gaussian-likelihood)

**Used in:** [nb.md](nb.md#11-bayes-rule)

**Refs:** Mitchell 1997 *Machine Learning* §6.2

**Added:** 2026-05

## 12. prior probability

**Category:** AI

**Source:** function `likes` in `nb.fun` (variable `b`)

**Defines:** P(class) before seeing the row. Computed as
`(#rows_in_class + m) / (total_rows + m·n_classes)` —
m-estimated, not raw frequency.

**Why:** Without a prior, rare classes get spurious confidence.
Smoothing avoids zeros for never-seen classes.

**Depends on:** [#17 m-estimate](glossary.md#17-m-estimate)

**Used in:** [nb.md](nb.md#12-prior-probability)

**Added:** 2026-05

## 13. symbolic likelihood

**Category:** AI

**Source:** function `SYM_like` in `nb.fun`

**Defines:** P(value | class) for categorical features:
`(count + k·prior) / (n + k)`.

**Why:** Direct count from training data; smoothed so unseen
values don't get probability zero.

**Depends on:** [#16 Laplace smoothing](glossary.md#16-laplace-smoothing)

**Used in:** [nb.md](nb.md#13-symbolic-likelihood)

**Added:** 2026-05

## 14. Gaussian likelihood

**Category:** math

**Source:** function `NUM_like` in `nb.fun`

**Defines:** P(value | class) for numeric features under normal
assumption: (1/√(2π·var)) · exp(−(v−μ)² / (2·var)).

**Why:** Numeric features are continuous — point probability
is 0. Use density instead, treat it as a likelihood score.

**Depends on:** [#1 Num column](glossary.md#1-num-column)

**Used in:** [nb.md](nb.md#14-gaussian-likelihood)

**Added:** 2026-05

## 15. log-likelihood

**Category:** math

**Source:** function `likes` in `nb.fun`

**Defines:** Sum of log probabilities instead of product of
probabilities. log(a·b) = log a + log b.

**Why:** Multiplying many small probabilities underflows to 0.
Logging keeps numbers in additive range; argmax preserved
because log is monotone.

**Depends on:** none

**Used in:** [nb.md](nb.md#15-log-likelihood)

**Added:** 2026-05

## 16. Laplace smoothing

**Category:** AI

**Source:** function `SYM_like` in `nb.fun` (parameter `the.k`)

**Defines:** Add `k` pseudo-counts to numerator (weighted by
prior) and `k` to denominator. Prevents P(value | class) = 0
for value never seen with that class.

**Why:** One zero in a product makes the whole product zero.
Smoothing trades perfect MLE for usable predictions on sparse
data.

**Depends on:** none

**Used in:** [nb.md](nb.md#16-laplace-smoothing)

**Refs:** Manning & Schütze 1999 §6.2.2

**Added:** 2026-05

## 17. m-estimate

**Category:** AI

**Source:** function `likes` in `nb.fun` (parameter `the.m`)

**Defines:** Smoothed prior: `(n_class + m) / (n_total + m·n_classes)`.
`m` controls how strongly to pull toward uniform.

**Why:** Same problem as Laplace but for class frequencies.
Avoids zero-prior for unseen-yet classes during warm-start.

**Depends on:** [#16 Laplace smoothing](glossary.md#16-laplace-smoothing)

**Used in:** [nb.md](nb.md#17-m-estimate)

**Added:** 2026-05

## 18. naive independence

**Category:** AI

**Source:** function `likes` in `nb.fun`

**Defines:** Assume features are conditionally independent given
the class: P(row | class) = ∏ᵢ P(featureᵢ | class). "Naive"
because it's almost never true.

**Why:** Joint distributions over many features are
intractable. The independence shortcut works astonishingly well
in practice, especially when features carry redundant signal.

**Depends on:** [#11 Bayes' rule](glossary.md#11-bayes-rule)

**Used in:** [nb.md](nb.md#18-naive-independence)

**Added:** 2026-05

## 19. argmax classification

**Category:** AI

**Source:** functions `most`, `nb` in `nb.fun`

**Defines:** Predicted class = the one with the highest
posterior log-likelihood. `most` returns the key whose value
function is maximal.

**Why:** Bayes gives a score per class; classification reduces
to picking the winner.

**Depends on:** [#11 Bayes' rule](glossary.md#11-bayes-rule)

**Used in:** [nb.md](nb.md#19-argmax-classification)

**Added:** 2026-05

## 20. warm-start period

**Category:** this-codebase

**Source:** function `nb` in `nb.fun` (`the.wait`)

**Defines:** Skip classification for the first `wait` rows.
Just train. After `n > wait`, classify each row before adding
it to training.

**Why:** With zero training examples, every prediction is a
guess. Wait until classifier has signal before scoring it.

**Depends on:** [#21 online classify-then-train](glossary.md#21-online-classify-then-train)

**Used in:** [nb.md](nb.md#20-warm-start-period)

**Added:** 2026-05

## 21. online classify-then-train

**Category:** AI

**Source:** function `nb` in `nb.fun`

**Defines:** For each incoming row: (1) predict its class using
current model, (2) record predicted vs actual, (3) update the
model with the row. No separate train/test split.

**Why:** Mirrors streaming deployment. Every row provides a
honest prequential evaluation — train was never told the answer
before predicting.

**Depends on:** none

**Used in:** [nb.md](nb.md#21-online-classify-then-train)

**Refs:** Dawid 1984 *J. Royal Statistical Soc.* (prequential)

**Added:** 2026-05

## 22. confusion matrix

**Category:** eval

**Source:** function `nb` in `nb.fun` (variable `cm`)

**Defines:** Square table indexed by actual class × predicted
class. `cm[want][got]` = number of times `want` was predicted as
`got`. Diagonal = correct.

**Why:** All classifier metrics derive from the four cells per
class (TP, FP, FN, TN). One table holds everything.

**Depends on:** none

**Used in:** [nb.md](nb.md#22-confusion-matrix)

**Added:** 2026-05

## 23. critical class

**Category:** eval

**Source:** function `eg["--experiment"]` in `nb.fun`

**Defines:** A single class chosen as the focus of evaluation
(`phytophthora-rot` for soybean, `tested_positive` for
diabetes). Multi-class problem reduced to binary for that
class.

**Why:** Aggregate accuracy hides per-class behavior. When one
class matters (rare disease, fraud), evaluate it specifically.

**Depends on:** [#22 confusion matrix](glossary.md#22-confusion-matrix)

**Used in:** [nb.md](nb.md#23-critical-class)

**Added:** 2026-05

## 24. recall (pd)

**Category:** eval

**Source:** function `stats` in `nb.fun`

**Defines:** TP / (TP + FN). Of all actual positives, fraction
correctly identified. Also called sensitivity, hit rate,
detection probability.

**Why:** Measures how well a classifier finds the positive
class. Critical when missing positives is costly (cancer, fraud).

**Depends on:** [#22 confusion matrix](glossary.md#22-confusion-matrix)

**Used in:** [nb.md](nb.md#24-recall-pd)

**Added:** 2026-05

## 25. false alarm (pf)

**Category:** eval

**Source:** function `stats` in `nb.fun`

**Defines:** FP / (FP + TN). Of all actual negatives, fraction
wrongly flagged positive. Also called false positive rate.

**Why:** High recall is cheap if you flag everything. False
alarm rate balances the picture.

**Depends on:** [#22 confusion matrix](glossary.md#22-confusion-matrix)

**Used in:** [nb.md](nb.md#25-false-alarm-pf)

**Added:** 2026-05

## 26. precision

**Category:** eval

**Source:** function `stats` in `nb.fun`

**Defines:** TP / (TP + FP). Of all rows predicted positive,
fraction actually positive.

**Why:** Tells you how trustworthy a positive prediction is.
Critical when acting on a positive has real cost.

**Depends on:** [#22 confusion matrix](glossary.md#22-confusion-matrix)

**Used in:** [nb.md](nb.md#26-precision)

**Added:** 2026-05

## 27. accuracy

**Category:** eval

**Source:** function `stats` in `nb.fun`

**Defines:** (TP + TN) / N. Fraction of rows classified
correctly.

**Why:** Simple intuitive number. Misleading on imbalanced
data: a 95%-negative dataset gets 95% accuracy from "always
say no."

**Depends on:** [#22 confusion matrix](glossary.md#22-confusion-matrix)

**Used in:** [nb.md](nb.md#27-accuracy)

**Added:** 2026-05

## 28. G-score

**Category:** eval

**Source:** function `stats` in `nb.fun`

**Defines:** Harmonic mean of recall (pd) and specificity
(1 − pf): 2·rec·spec / (rec + spec). Range 0–100 (here, scaled).

**Why:** Single number balancing detection vs false alarms.
Harmonic mean punishes one-sided wins (high recall but high pf).

**Depends on:** [#24 recall (pd)](glossary.md#24-recall-pd),
[#25 false alarm (pf)](glossary.md#25-false-alarm-pf)

**Used in:** [nb.md](nb.md#28-g-score)

**Added:** 2026-05

## 29. pooled SD

**Category:** math

**Source:** function `sames` in `nb.fun`

**Defines:** Combined standard deviation of two samples:
sqrt((sd₁² + sd₂²) / 2). Used as an effect-size scale (`eps`).

**Why:** Comparing two distributions needs a meaningful "small
difference" threshold. Pooled SD provides scale; multiplying
by 0.35 gives Cohen's small-effect cutoff.

**Depends on:** [#1 Num column](glossary.md#1-num-column)

**Used in:** [nb.md](nb.md#29-pooled-sd)

**Refs:** Cohen 1988 *Statistical Power Analysis* (d ≈ 0.35 small)

**Added:** 2026-05

## 30. statistical ranking

**Category:** eval

**Source:** functions `sames`, `same`, `cliffsDelta`, `ks` in `nb.fun`

**Defines:** Sort treatments by mean (descending). Rank 1 =
best treatment plus all others statistically equivalent to it.
Rank 2 = first treatment NOT equivalent + all equivalent to that.
Equivalence test: Cohen's d (cheap gate) → Cliff's delta (effect
size) → Kolmogorov–Smirnov (distribution shape).

**Why:** Naive "best mean wins" ignores noise. Statistical
ranking groups indistinguishable treatments together — honest
about what the data can resolve.

**Depends on:** [#29 pooled SD](glossary.md#29-pooled-sd)

**Refs:** Arcuri & Briand 2014 *STVR*, Kolmogorov 1933,
Cliff 1993 *Psych. Bull.*

**Used in:** [nb.md](nb.md#30-statistical-ranking)

**Added:** 2026-05
