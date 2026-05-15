% FUN(1) | User Commands

# NAME

**fun** — transpile and run a *fun* source file (a tiny Lua-targeted
source language with Python-style `:` blocks and indent-closed bodies).

# SYNOPSIS

**fun** [*OPTS*] *FILE* [*ARGS*...]

# DESCRIPTION

*fun* is a Lua-targeted source language whose transpiler is a single
short Lua module (`fun.lua`). Source files use the `.fun` extension.

**The transpiler is strictly line-by-line.** Each physical line is
parsed and rewritten in isolation. There is **no line-continuation
character** — a backslash at end-of-line has no special meaning.
The only cross-line state is an indent stack used to emit closing
`end`s when a block's body outdents.

This has direct consequences:

- Conditions in `if (...)`, `elseif (...)`, `while (...)` **must
  close on the same line**.
- Comprehensions `[expr for v in iter (if c)]` **must fit on one
  line**.
- Long expressions that don't fit on one line must be broken via
  intermediate locals, not by splitting one statement across lines.

By the time the source reaches Lua, it *is* Lua. *fun* adds a small
set of per-line rewrites that compile away — no runtime layer.

# QUICK START

```bash
./fun foo.fun arg1 arg2
./fun -s foo.fun           # print transpiled Lua (no run)
./fun -h                   # help
```

```fun
#!/usr/bin/env fun
-- vim: ft=fun

greet := fun(name): !"hello, "..name
sq    := fun(x):    !x * x

print(greet("world"))
print(sq(5))
```

# LANGUAGE

## Sigils

| *fun*    | Lua                  | Notes                              |
|----------|----------------------|------------------------------------|
| `fun`    | `function`           | word substitution                  |
| `let`    | `local` (forward)    | for forward decls only             |
| `NAME :=` | `local NAME =`      | declare + assign in body           |
| `!`      | `return `            | sigil                              |
| `:`      | (block introducer)   | see below                          |

`fun` and `let` are word-boundary substitutions. Strings (`"..."`,
`'...'`, `[[...]]`) and trailing `--` comments are protected.

## Declarations

| Form                       | Meaning                                |
|----------------------------|----------------------------------------|
| `let a, b, c`              | forward-declare uninitialized locals   |
| `x := 5`                   | new local `x` with value               |
| `a, b := 1, 2`             | multi declare                          |
| `x = 5`                    | reassign existing (local or forward)   |

Use `let` ONLY at the top for forward refs (mutual recursion etc.).
Inside bodies, use `:=` to introduce new locals.

## Block introducer `:`

`:` ends a header line and opens a block:

```fun
if (x > 0):
  print("pos")
elseif (x < 0):
  print("neg")
else:
  print("zero")
```

| Header           | Lua                |
|------------------|--------------------|
| `if (c):`        | `if (c) then`      |
| `elseif (c):`    | `elseif (c) then`  |
| `else:`          | `else`             |
| `for X in Y:`    | `for X in Y do`    |
| `while c:`       | `while c do`       |
| `fun(args):`     | `function(args)`   |

`if` / `elseif` **require parens** around the condition.

## Indent-closed blocks

A line ending with `:` opens a block. The body is the consecutive
following lines at greater indent. The transpiler emits `end` when
indent returns to the header's level (or below).

```fun
foo := fun(x):
  if (x > 0):
    print("pos")
    return 1
  return 0
-- foo's `end` emitted here automatically.
```

## One-liners (auto-end)

If content follows `:` on the same line, it's a one-liner — the
transpiler auto-appends `end`:

```fun
sq    := fun(n): !n * n
greet := fun(s): !"hi "..s
if (x > 0): print("pos")
for i in xs: print(i)
```

becomes

```lua
local sq    = function(n) return n * n end
local greet = function(s) return "hi "..s end
if (x > 0) then print("pos") end
for _,i in ipairs(xs) do print(i) end
```

Auto-end is **skipped** if the line already contains `end`. So:

```fun
sort(xs, fun(a,b): !a < b end)
```

The user-supplied `end` closes the inline lambda; the call closes
with `)`. No auto-end injected.

## Inline lambdas in expressions

Anonymous `fun(args):` inside a call/argument list keep an explicit
`end` (the call's `,`/`)` continues the expression; indent can't
close it reliably):

```fun
sort(xs, fun(a,b): !a < b end)
table.sort(t, fun(a,b): !a[1] < b[1] end)
```

### Tip: avoid the explicit `end` by extracting the lambda

Bind the lambda to a local first — both functions then close via
indent, no explicit `end` anywhere:

```fun
-- ✗ inline lambda needs explicit `end` to close before `)`:
show := fun(tree):
  nodes(tree, fun(node, lvl, pre):
    p := ...
    io.write(...)
  end)

-- ✓ extract to a local — outdent closes both funs cleanly:
show := fun(tree):
  fn := fun(node, lvl, pre):
    p := ...
    io.write(...)
  nodes(tree, fn)
```

Same Lua output, less syntactic noise. Useful for any multi-line
anonymous fun passed as an argument.

## Return

`!` at line start (or after a `:`) becomes `return `:

```fun
foo := fun(x): !x * 2          -- return x*2
bar := fun(x):
  if (x > 0): !x
  !-x
```

## Comprehensions

```fun
squares := [x*x for x in xs]
evens   := [x for x in xs if x % 2 == 0]
labels  := [t.name for t in tasks if t.done]
```

Compile to an inline IIFE. The transpiler uses balanced-bracket
parsing, so `r[col.at]`-style indexing inside expr works:

```fun
xs := [r[col.at] for _,r in ipairs(rows) if r[col.at] ~= "?"]
```

Iterator handling:
- single loop var → `for _,v in ipairs(iter)`
- comma in loop var → `for k,v in pairs(iter)`
- iter contains `(` → passed through verbatim

**Comprehensions must fit on one line.**

## Strings and comments

- `--` single-line comment
- `--[[ ... ]]` long comment
- `[[ ... ]]` long string (multi-line, no interpolation)
- `"..."`, `'...'` regular strings (no interpolation)

# OPTIONS

`fun [opts] FILE [args]`:

| flag        | meaning                                          |
|-------------|--------------------------------------------------|
| `-h`        | print help                                       |
| `-s`        | print transpiled Lua to stdout (no execution)    |

Remaining args go to the script via `arg[1]`, `arg[2]`, ... and
`arg[0]` is the script path.

# FILES

- `fun.lua` — transpiler module
- `fun` — runner shim
- `*.fun` — source files
- `etc/funlexer.py` — Pygments lexer (`FunLexer`)
- `etc/funpdf.sh` — `.fun` → PDF
- `etc/syntax/fun.vim` — vim syntax
- `etc/nvimfun.lua`, `etc/nviminit.lua` — neovim filetype
- `etc/bat/syntaxes/Fun.sublime-syntax` — bat syntax
- `etc/fun-listings.tex` — LaTeX listings def

# DIAGNOSTICS

When transpiled Lua fails to load, `fun` writes a 5-line window
around the offending **transpiled** line to stderr, then errors. Line
numbers track source closely (per-line transpile preserves line
count; comprehension expansion pads newlines).

To see the transpiled output:

```bash
./fun -s file.fun
```

# RESTRICTIONS

## Line-by-line — no continuation

The transpiler processes one source line at a time. **No `\`
continuation, no implicit continuation.** Each `if`/`elseif`/`while`
header and each comprehension must fit on one line.

If a line gets too long, factor with intermediate locals:

```fun
-- ✗ too long, no way to wrap
result := some_long_call(arg_one, arg_two, ... arg_seven)

-- ✓ split via locals
args1 := (arg_one)
args2 := (arg_two)
result := some_long_call(args1, args2, ...)
```

Or for a long condition:

```fun
-- ✗
if (x > 0 and y > 0 and z > 0 and w > 0):
  body

-- ✓
all_pos := x > 0 and y > 0 and z > 0 and w > 0
if (all_pos):
  body
```

## Comprehension iterator with `]` inside

Iterator content can't contain literal `]` (e.g. `:gmatch"[^,]+"`).
Bind the iterator first:

```fun
-- ✗ broken
t := [thing(x) for x in s:gmatch"[^,]+"]

-- ✓
it := s:gmatch"[^,]+"
t  := [thing(x) for x in it]
```

## Indent rules

- Tabs count as 2 spaces (or pick consistent indent — don't mix)
- `elseif` / `else` continue the open `if` block (no premature close)
- Block bodies must indent **more** than their header
- Outdent below header indent closes the block

## `!` substitutes globally

`!` outside strings/comments becomes `return `. So:
- `!=` becomes `return =` — broken. Use `~=`.
- `not !x` becomes `not return x` — broken. Use `not x`.

## `:=` only at statement start

The `:=` pattern matches at the start of a line (after optional
whitespace). Don't use it mid-expression.

## Method `:` vs block `:`

The `:` is a method-call when followed immediately by an identifier
(`obj:method()`). It's a block introducer when followed by whitespace
or end-of-line (`if (c):`, `fun(x): body`).

## Plain tables have no methods

`xs:remove(n)` looks for a `remove` field; standard Lua. Use
`table.remove(xs, n)`.

## String hiding does not handle `\"`-escaped quotes

The hiding regex is `'"[^"]*"'`. Escaped quotes break it. Use single
quotes, `[[...]]`, or split via `..`.

# EXAMPLE

```fun
#!/usr/bin/env fun
-- vim: ft=fun

NUM := "Num"   -- type marker
Num := fun(txt, at):
  !{is=NUM, txt=txt or "", at=at or 0,
    n=0, mu=0, m2=0}

add := fun(num, v):
  num.n = num.n + 1
  d := v - num.mu
  num.mu = num.mu + d / num.n
  num.m2 = num.m2 + d * (v - num.mu)
  !num

mid := fun(num): !num.mu

adds := fun(values):
  out := Num()
  for _,v in ipairs(values): add(out, v)
  !out

print(mid(adds({1,2,3,4,5})))
```

# SEE ALSO

`lua(1)`, `pairs(3)`, `ipairs(3)`, `pygmentize(1)`, `pandoc(1)`

# AUTHORS

Tim Menzies <timm@ieee.org>.
