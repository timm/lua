---
title: AUTHOR — Conventions
nav_order: 98
---

# AUTHOR.md — Authoring Conventions for Course Docs

> Spec for writing (and auto-generating) the per-file docs, glossary,
> syllabus, README. Hand this to an LLM with a source file and it
> should produce conformant output.

## 0. Project context

- **Audience:** 400/500-level (senior undergrad / grad). Comfortable
  programmer, new to most ML concepts.
- **Source language:** `fun` (a tiny Lua-targeted DSL, ~150-line
  transpiler in `fun.lua`).
- **Lecture format:** 3 weeks per topic. 3 nights/week, 1 lecture/night,
  70 min each = **9 lectures (~10.5 hrs) per `<file>.md`**.
- **Exercises:** Students port `.fun` to Python (via LLM). Goal is
  understanding the *concepts*, not the language.
- **Exam:** Tagged `.fun` snippet with 3 seeded bugs. Student
  explains concepts, finds bugs, explains effect of each, proposes fix.

## 1. Site layout

```
/                       repo root
  README.md             1-page summary + badges + link to docs/
  <file>.fun            source files
  Makefile              `make repl-check`, `make solutions`, ...
  docs/
    index.md            site home (Jekyll convention)
    AUTHOR.md           this file (authoring conventions)
    syllabus.md         3-week-block schedule, dep graph
    glossary.md         canonical concepts (by category, then alphabetical)
    <file>.md           per-source walkthrough + REPL
    fun.1.md            language reference
    img/                figures (PNG / SVG)
    _config.yml         Jekyll + just-the-docs config
    <file>_test.zip     answer keys (encrypted, per-file password)
```

All URLs **relative**. Docs must be readable on a local clone with
no server.

## 2. Categories

Used only for grouping in glossary (sort key). No prefix in prose.

| Tag | Meaning |
|-----|---------|
| AI | algorithm theory |
| code | language idiom |
| SE | general SE pattern |
| this-codebase | local convention |
| gotcha | breakage |
| optimization | perf or algo |
| human | readability / explainability |
| math | formal theory |
| limit | known limitation |
| eval | empirical / metrics |

## 3. Concept naming

- **Identity = sequential integer.** First glossary entry is `1`,
  second `2`, etc. Append-only. Numbers never reused, never resorted.
- **Phrase = human label**, ≤4 words. "Bayes' rule",
  "Welford's algorithm", "Laplace smoothing".
- **Citation = function name(s)** in source — never line numbers.
  Function names are refactor-stable; line numbers aren't.
  Multiple functions allowed per entry: `classify, like, prior`.
- One canonical phrase per concept. **No synonyms in prose.**
- Tags in `.fun` source: one-line comment listing IDs that the
  next code chunk illustrates. Format: `-- @23,44,61,100`.
  Place above the function/section it tags.
- Cross-doc links use slug `#<N>-<phrase-kebab>` (e.g.,
  `glossary.md#23-bayes-rule`).
- Phrase renames cascade: `git grep && rebase` all docs in one commit.
  Number stays the same — only the slug suffix changes.
- Glossary entries: **append-only after first release. Never
  renumber.** A retired concept gets a `**Status:** retired` line
  but keeps its number forever.

## 4. Glossary entry schema

```markdown
## 23. Bayes' rule
**Category:** AI
**Source:** functions `classify`, `like`, `prior` in `nb.fun`
**Defines:** P(C|x) ∝ P(x|C)·P(C). Foundation for generative
classification.
**Why:** Need to invert observed→hidden probability.
**Depends on:** [#19 prior probability](glossary.md#19-prior-probability),
[#21 conditional probability](glossary.md#21-conditional-probability)
**Used in:** [nb.md](nb.md#23-bayes-rule)
**Refs:** Manning & Schütze 1999, §6.2; Mitchell 1997, §6.2
**Added:** 2026-05
```

Sort order: **strict numeric, ascending** (1, 2, 3, ...). Categories
are a *grouping label* on each entry, not a sort key.
**Refs live inside the entry — no separate references file.**

## 5. `<file>.md` schema

```markdown
---
title: <file> — <subject>
nav_order: <integer>
prereqs: [<file1>, <file2>]
new_concepts: <count>     # target ~45
reused_concepts: <count>
repl_prompts: <count>     # target ~80
---

![License](https://img.shields.io/badge/license-MIT-blue)
![Lang](https://img.shields.io/badge/lang-fun-purple)

# <file>.md — <subject>

**Source:** [`<file>.fun`](../<file>.fun)
**See also:** [glossary](glossary.md) · [syllabus](syllabus.md)
**Prerequisite:** ran `make install` (see [home](index.md))

## Big picture
1 paragraph. The whole topic in plain English. Why care.

## Problem
What task. What input → output. Concrete.

## Approach
2-3 sentences. High-level strategy + key trade-off.

## Architecture
ASCII flow diagram. Show data + control.

## Key structures
Bulleted list, 3-5 items, one line each.

## Walkthrough
Order: simple → complex. ~9 sub-sections (one per lecture).

### Lecture 1 — <Section name>

Embed the relevant snippet **verbatim** so the reader doesn't hunt
through the source file:

```fun
-- @23,44,61,100        (from nb.fun)
classify= fun(row)
  ...5-15 lines...
  end
```

Prose explaining the snippet. First mention of a concept links to
glossary by **number-phrase slug**:

[#23 Bayes' rule](glossary.md#23-bayes-rule) says posterior is
proportional to likelihood × prior. Implemented in `classify`
above and `like`/`prior` (not shown).

Reused-from-earlier-file mention uses a callout:

> [!TIP]
> Recall [#7 Welford's algorithm](glossary.md#7-welfords-algorithm)
> from [ezr.md](ezr.md). Same online-mean trick applies here.

REPL prompts interspersed (per-file numbering, restart at [1]):

    [1]> ./fun nb.fun --the
    {file=diabetes.csv, ...}

[Repeat for 9 lectures: ~5 new concepts + ~9 prompts each.]

## Limitations
- Naive Bayes assumes feature independence — fails on correlated
  features.
- Cold start: P=0 for first instance of unseen class
  (mitigated by warm-start period).

## Shortcuts made
- "We use string markers for type dispatch; production code might
  use metatables."
- "Confusion matrix only after `wait` rows; not a holdout."

## Exercises

### Week 1 — prompts [1]-[27]
Port each prompt to Python. Match output. Submit `<file>_part1.py`.

### Week 2 — prompts [28]-[54]
Same, plus first round of modify-band prompts. Submit
`<file>_part2.py`.

### Week 3 — prompts [55]-[80]
Final modify-band prompts; explain observed shifts in
`<file>_notes.md`. Submit `<file>_part3.py` + notes.

### Self-check
Answers in `<file>_test.zip` (password: see LMS).
```

## 6. REPL prompt design

### Numbering
- Per-file, starting at `[1]>`. **~80 prompts per `<file>.md`.**
- ~9 prompts per lecture (range 5-15).
- Cross-doc references use file prefix: `nb[12]>` in support/
  discussion.

### Bands (Bloom's, collapsed) — target mix per doc

| Band | Count | What |
|------|-------|------|
| Run (Remember + Understand) | ~20 | type and see |
| Predict (Apply + Analyze) | ~40 | predict output before running |
| Modify (Evaluate + Create) | ~20 | change something, explain effect |

Ratio 1:2:1.

### Determinism
- First prompt should pin the seed if randomness is involved
  (e.g., `the.seed = 1`).
- Output normalized: dicts sorted (`o()` does this).

### No self-test prompts
Don't write "before running, what do you think?" prompts that the
runner can't verify. Such reflection is for class discussion only,
not the doc.

## 7. index.md (site home) schema

```markdown
![License](https://img.shields.io/badge/license-MIT-blue)
![Build](https://img.shields.io/badge/build-passing-green)
![Docs](https://img.shields.io/badge/docs-current-blue)

# <Course name>

**Audience:** 400/500-level. Familiar with one language; new to ML.

## Quickstart
```bash
git clone ...
make install
./fun ezr.fun --tree
```

## Site map
- [Syllabus](syllabus.md) — 3-week blocks + dependency graph
- [Glossary](glossary.md) — all concept definitions
- Per-file walkthroughs:
  - [ezr.md](ezr.md) — decision tree learner
  - [nb.md](nb.md) — naive Bayes classifier
  - …
- [fun.1.md](fun.1.md) — language reference
- [AUTHOR.md](AUTHOR.md) — authoring conventions
```

## 8. syllabus.md schema

```markdown
# Syllabus

3 weeks per `<file>.md`. 3 lectures/week, 70 min each.
Files read in `nav_order`. Later files assume prior concepts
unless explicitly re-introduced.

## Dependency graph

```
ezr ──→ nb ──→ active ──→ ...
```

## Schedule

| Weeks | File | New concepts | Topics |
|-------|------|--------------|--------|
| 1-3 | ezr | ~45 | decision tree, Welford, rank stats |
| 4-6 | nb  | ~45 | Bayes, Laplace, m-est, warm-start |
| 7-9 | ... | ... | ... |

## Pacing
~5 new concepts/lecture, ~45/doc absorbable. Reused concepts
(callout `[!TIP]`) free. Past ~50 concepts/doc, students
saturate — split into two docs if a topic naturally needs more.
```

## 9. Lint rules (enforced by `make repl-check`)

1. Every REPL prompt re-runs in CI; output diffed against doc.
   Fail on drift.
2. Glossary numbers are dense and monotonic: 1, 2, 3, ..., no gaps,
   no duplicates, no out-of-order entries (except retired entries
   which keep their slot).
3. Every glossary-linked slug `#N-phrase` in `<file>.md` resolves
   to an entry; the `N` and `phrase` must match the entry header.
4. Every glossary entry referenced ≥ once in some `<file>.md`
   OR appears in a `.fun` `-- @N,...` tag comment. Warn on orphan.
5. Every `-- @N,N,...` tag in `.fun` source resolves to existing
   glossary entries.
6. Every `**Source:**` function name in glossary exists in the
   referenced `.fun` file.
7. First mention of a concept in a file links to glossary; later
   mentions in the same file are plain text (no repeated link).
8. Reused-from-prior-file mentions use `[!TIP]` callout.
9. No alias prose alongside the canonical phrase
   (e.g., "burn-in" prose AND "warm-start period" link in same file).
10. Phrase ≤4 words.
11. URLs are relative for internal docs (no `https://` to internal).

## 10. Tone

K&R direct. "You" not "the user." Admit limits. Lead with tiny
concrete examples. No marketing. No "powerful," "easy," "elegant"
adjectives. Don't talk about ABILITY ("the system can…"); describe
WHAT IT DOES.

Reference text for calibration: [K&R Ch1 prose](etc/kr_ch1.md)
(if archived locally).

## 11. Update protocol

- Glossary entries: append-only. New entries get the next integer.
  Never reuse, renumber, or reorder.
- Retiring an entry: add `**Status:** retired (YYYY-MM)`. Number
  stays. Citations and prose mentions removed in the same PR.
- Phrase renames: rebase all `<file>.md`, `glossary.md`, and any
  `.fun` `-- @N` comments in one commit. Don't fragment across PRs.
  Slug suffix changes (`#23-bayes-rule` → `#23-bayes-theorem`);
  number stays.
- Function renames: bump `**Source:**` in glossary entry and any
  `.fun` `-- @N` tag comments still referencing it (the tag itself
  doesn't name the function; lint catches drift via §9 rule 6).
- REPL output changes: regenerate via test harness. CI lint
  catches drift.
- Prose changes in `<file>.md`: free. No protocol.
- New file added: update `syllabus.md` nav_order + dep graph.
- New concept added: glossary entry first (next integer), then
  reference from `.fun` (`-- @N`) and `.md` (slug link).

## 12. Solutions and tests

- `solutions/<file>_partN.py` — student-written Python ports.
  Not provided by instructor.
- `<file>_test.zip` (in `docs/`) — encrypted answer key per file.
  Different password per file. Self-marking after student finishes.
  Password distribution: LMS / online course tool, NOT in repo.
- Exam content: kept outside this repo (online course platform).

## 13. Jekyll / GH Pages

`_config.yml`:

```yaml
title: <Course name>
description: <one-line subject>
theme: just-the-docs
search_enabled: true
heading_anchors: true
color_scheme: light
nav_external_links:
  - title: Source on GitHub
    url: https://github.com/USER/REPO
```

Each markdown file gets front-matter:

```yaml
---
title: nb — Naive Bayes
nav_order: 3
---
```

## 14. `.fun` source layout — Unix man-page header at column 1

Every `.fun` file opens with a **column-1 header** (no leading
whitespace beyond the language requires) that acts as the man-page
masthead. Lay it out parsimoniously — usually 10-20 lines total.
After this header, sections (`-- ## Classes`, `-- ## Library`, ...)
follow, each producing a column break in the rendered PDF.

The header contains, in order:

1. **Shebang + vim modeline + help string**
   ```fun
   #!/usr/bin/env fun
   -- vim: ft=fun
   the, help := {}, [[
   ezr.fun : explainable multi-objective optimization
   ...defaults inline (`-f f=auto93.csv`, `-B Budget=50`, etc.)...
   ]]
   ```
2. **Shortcuts** — pull common stdlib names into locals. Pack tight,
   one line per category:
   ```fun
   abs, min, max, log, exp :=
     math.abs, math.min, math.max, math.log, math.exp
   floor, rand, randomseed :=
     math.floor, math.random, math.randomseed
   fmt, mtype := string.format, math.type
   ```
3. **Markers** — type tags as strings. One line if it fits:
   ```fun
   NUM, SYM, COLS, DATA, TREE := "Num","Sym","Cols","Data","Tree"
   ```
4. **Forward refs** — names assigned later but used earlier in the
   file. One line:
   ```fun
   let push, csv, add, o, mid, build, leaf, nodes
   ```
5. **Snapshots** — anything captured at load-time before user code
   runs (e.g., for `rogues()`):
   ```fun
   b4 := {}; for k,_ in pairs(_ENV): b4[k] = true
   ```

This header is column-1 in the sense that **everything in it is at
indent zero**. It's compact, scannable, and gives a reader the file's
"manifest" before any logic starts.

Constructors, update, library, query, stats, examples, main all live
below in their own `-- ## Section` blocks. Each section header
triggers a `\columnbreak` in the rendered PDF, so a reader can scan
the printed page column-by-column to find each conceptual block.

Dream layout: Classes and Update on page 1. Achievable with
`Cols=3 Font=5 Orient=landscape` if the help string stays short.

## 15. Images

- Location: `docs/img/`
- Naming: `<file>-figN.png` (e.g., `nb-fig1.png`)
- Format: SVG preferred; PNG if rasterizing. Max ~500KB.
- 1-3 figures per `<file>.md` typical.
- Markdown reference: `![caption](img/nb-fig1.png)`.

## 16. Quick checklist before commit

- [ ] All REPL prompts run and match output (`make repl-check`)
- [ ] No new concept missing a glossary entry
- [ ] No synonym used alongside its canonical phrase
- [ ] First-mention links present; reuses use `[!TIP]`
- [ ] Links are relative
- [ ] Front-matter `nav_order` and `prereqs` set
- [ ] `new_concepts` ≤ ~50; `repl_prompts` ~80
- [ ] Image captions present
- [ ] Tone scan: removed adjectives ("powerful", "easy", etc.)
