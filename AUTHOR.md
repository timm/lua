# AUTHOR.md — Authoring Conventions for Course Docs

> Spec for writing (and auto-generating) the per-file docs, glossary,
> syllabus, README. Hand this to an LLM with a source file and it
> should produce conformant output.

## 0. Project context

- **Audience:** 400/500-level (senior undergrad / grad). Comfortable
  programmer, new to most ML concepts.
- **Source language:** `fun` (a tiny Lua-targeted DSL, ~150-line
  transpiler in `fun.lua`).
- **Lecture format:** Two 70-min lectures per night, same evening.
  One `<file>.md` per night.
- **Exercises:** Students port `.fun` to Python (via LLM). Goal is
  understanding the *concepts*, not the language.
- **Exam:** Show a tagged `.fun` snippet with 3 seeded bugs. Student
  explains tags, finds bugs, explains effect of each, proposes fix.

## 1. Site layout

```
/                       repo root
  README.md             1-page summary + badges + link to docs/
  <file>.fun            source files
  AUTHOR.md             this file
  Makefile              `make repl-check`, `make solutions`, ...
  docs/
    README.md           site home (Jekyll renders as index)
    syllabus.md         week-by-week schedule, dep graph
    glossary.md         canonical concepts (alphabetical)
    <file>.md           per-source walkthrough + REPL
    fun.1.md            language reference
    img/                figures (PNG / SVG)
    _config.yml         Jekyll + just-the-docs config
    <file>_test.zip     answer keys (encrypted, per-file password)
```

All URLs **relative**. Docs must be readable on a local clone with
no server.

## 2. Categories (11 prefixes)

```
a  AI / algorithm theory          aBAYES, aLAPLACE, aGAUSS
c  code / language idiom          cITER, cCLOS, cPRECEDENCE
s  general SE pattern             sDISPATCH, sDRY, sSEPARATION
t  this-codebase specific         tIS, tCM, tKLASSES
b  gotcha / breakage              bDIVZERO, bMISSING, bSDZERO
o  optimization (incl. perf)      oONLINE, oBISECT, oCACHE
h  human factors                  hREADABLE, hEXPLAIN
m  math / formal theory           mWELFORD, mPDF, mLOG
l  limitations                    lCOLDSTART, lINDEPENDENCE
e  evaluation / empirical         eTRAINTEST, eMETRICS
r  references / history           rWELFORD1962, rCOHEN1988
```

## 3. Concept ID rules

- Format: `<prefix><UPPERCASE>`, ≤10 chars total.
- Mnemonic, not cryptic (`aLAPLACE`, not `aLAP`).
- **One canonical ID per concept.** No synonyms in prose.
  - Pick one: e.g. `aWARMSTART` (never alternate with "burn-in").
- IDs are a contract once exams reference them. Renames cascade:
  `git rebase` all docs in one commit.
- Glossary additions are append-only after first release.

## 4. Glossary entry schema

```markdown
## aLAPLACE
**Category:** a (AI)
**Aliases:** none (avoid: "smoothing", "add-k smoothing")
**Defines:** Add-k smoothing for symbolic likelihoods:
(count + k·prior) / (n + k). Prevents zero-probability for unseen
feature values.
**Why:** Naive Bayes assigns P=0 to any unseen feature×class pair;
one zero kills the product.
**Depends on:** aBAYES, aPRIOR
**Used in:** [nb.md](nb.md#alaplace)
**Refs:** Manning & Schütze 1999, §6.2
**Added:** 2026-05
```

Alphabetical by ID within `glossary.md`.

## 5. `<file>.md` schema

```markdown
---
title: <file> — <short description>
nav_order: <integer, week order>
prereqs: [<file1>, <file2>]
new_concepts: <count>
reused_concepts: <count>
---

![License](https://img.shields.io/badge/license-MIT-blue)
![Lang](https://img.shields.io/badge/lang-fun-purple)

# <file>.md — <subject>

**Source:** [`<file>.fun`](../<file>.fun)
**See also:** [glossary](glossary.md) · [syllabus](syllabus.md)
**Prerequisite:** ran `make install` (see [README](README.md))

## Problem
One paragraph. What task. What input → output.

## Approach
2-3 sentences. High-level strategy + key trade-off.

## Architecture

ASCII flow diagram. Show data + control.

## Key structures
- bulleted list, 3-5 items, one line each

## Walkthrough

### <Section name>

```fun
<5-15 lines of source, copy-pasted verbatim>
```

Prose explaining the snippet. Tags inline: [`aBAYES`].

First mention of any concept emits a callout:

> [!NOTE]
> **aBAYES** (a) — Bayes' rule: P(C|x) ∝ P(x|C)·P(C). Foundation
> for generative classification.
> See [glossary](glossary.md#abayes).

Concepts introduced in earlier files (per `nav_order`) get a
reused callout instead:

> [!TIP]
> **aBAYES** — previously seen in [nb.md](nb.md#abayes). Reminder:
> Bayes' rule for class probability.

[Repeat for each section: Classes / Update / Query / Stats / Demo]

## REPL session

> [!TIP]
> Run these prompts. Match the output. Then port the logic to
> Python in your solutions directory.

    [1]> ./fun <file>.fun --the
    {Budget=50, Check=5, ...}

    [2]> ./fun <file>.fun --tree
    ...

(Per-file numbering. 10-30 prompts. Mix bands:
  Run / Predict / Modify — see §6.)

## Limitations & gotchas
- `lCOLDSTART` — Naive Bayes assigns P=0 to first instance of any
  unseen class. Mitigation: burn-in period.
- `bDIVZERO` — Welford guard for n=1.

## Shortcuts made
- "We use string markers for type dispatch; production code might
  use metatables."
- "Confusion matrix recorded only after `wait` rows; not a holdout."

## Exercises

### Night 1 — prompts [1] through [15]
Port each prompt to Python. Match output. Submit `<file>_part1.py`.

### Night 2 — prompts [16] through [30]
Same, plus: implement the modify-band prompts (varying k, m, ...)
and explain the observed shifts. Submit `<file>_part2.py` +
`<file>_notes.md`.

### Self-check
Answers in `<file>_test.zip` (password: see LMS).
```

## 6. REPL prompt design

### Numbering
- Per-file, starting at `[1]>`.
- Cross-doc references use file prefix: `nb[12]>` in support /
  discussion.

### Bands (per Bloom's, collapsed)
1. **Run** (Remember + Understand): "type and see"
2. **Predict** (Apply + Analyze): show input, ask student to
   predict output before running
3. **Modify** (Evaluate + Create): change something, explain effect

Rough mix per file: ~5 Run, ~10 Predict, ~5 Modify (1:2:1).

### Determinism
- First prompt should pin the seed if randomness is involved
  (e.g., `the.seed = 1`).
- Output normalized: dicts sorted (`o()` does this).

### No self-test prompts
Don't write "before running, what do you think?" prompts that the
runner can't verify. Such reflection is for class discussion only,
not the doc.

## 7. README.md (site home) schema

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
- [Syllabus](syllabus.md) — week-by-week + dependency graph
- [Glossary](glossary.md) — all concept definitions
- Per-file walkthroughs:
  - [ezr.md](ezr.md) — decision tree learner
  - [nb.md](nb.md) — naive Bayes classifier
  - …
- [fun.1.md](fun.1.md) — language reference
- [AUTHOR.md](../AUTHOR.md) — authoring conventions
```

## 8. syllabus.md schema

```markdown
# Syllabus

Files are read in `nav_order`. Later files assume prior concepts
unless explicitly re-introduced.

## Dependency graph

```
ezr ──→ nb ──→ active ──→ ...
```

## Schedule

| Night | File | New concepts | Topics |
|-------|------|--------------|--------|
| 1 | ezr | aONLINESTAT, mWELFORD, sDISPATCH, ... | decision tree |
| 2 | nb  | aBAYES, aLAPLACE, aMEST, ... | naive Bayes |
| ... | ... | ... | ... |

## Pacing
Two 70-min lectures per night. 8-12 new concepts/night absorbable;
reused concepts (callout `[!TIP]`) free.
```

## 9. Lint rules (enforced by `make repl-check`)

1. Every REPL prompt re-runs in CI; output diffed against doc.
   Fail on drift.
2. Every concept tag in `<file>.md` matches a glossary entry.
   Fail if missing.
3. Every glossary entry referenced at least once. Warn if orphan.
4. First mention of a concept in a file uses `[!NOTE]`.
   Later mentions in the same file use plain tag link (no callout).
5. Reused-from-prior-file mentions use `[!TIP]`.
6. **Warn on duplicate full callout** for an already-introduced
   concept (within a file OR globally).
7. No synonym appears in prose alongside a canonical ID
   (e.g., "warm-start" prose AND `aWARMSTART` tag in same file).
8. ≤10 chars per concept ID. Prefix is one of 11 valid categories.
9. URLs are relative (no `https://` to internal docs).

## 10. Tone

K&R direct. "You" not "the user." Admit limits. Lead with tiny
concrete examples. No marketing. No "powerful," "easy," "elegant"
adjectives. Don't talk about ABILITY ("the system can…"); describe
WHAT IT DOES.

Reference text for calibration: [K&R Ch1 prose](etc/kr_ch1.md)
(if archived locally).

## 11. Update protocol

- Glossary entries: append-only after release. New `**Added:**`
  date per entry.
- Concept renames: rebase all `<file>.md` and `glossary.md` in
  one commit. Don't fragment across PRs.
- REPL output changes: regenerate via test harness. CI lint
  catches drift.
- Prose changes in `<file>.md`: free. No protocol.
- New file added: update `syllabus.md` nav_order + dep graph.
- New concept added: glossary entry first, then reference.

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
- [ ] No synonym used alongside its canonical ID
- [ ] First-mention callouts present; reuses use `[!TIP]`
- [ ] Links are relative
- [ ] Front-matter `nav_order` and `prereqs` set
- [ ] Image captions present
- [ ] Tone scan: removed adjectives ("powerful", "easy", etc.)
