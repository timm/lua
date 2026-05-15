% FUN(1) | User Commands

# NAME

**fun** — transpile and run a *fun* source file (a tiny Lua-targeted
source language)

# SYNOPSIS

**fun** *FILE* [*ARGS*...]

# DESCRIPTION

*fun* is a Lua-targeted source language whose transpiler is a single
short Lua module (`fun.lua`). Source files use the `.fun` extension.
The runner shim `fun` reads a `.fun` file, transpiles it to Lua via
`fun.lua`, executes the result with the remaining arguments visible in
Lua's `arg` table, and forwards stdin/stdout/exit code.

By the time the source reaches Lua, it *is* Lua. *fun* adds a small
set of line-level rewrites that compile away — no runtime layer.

# QUICK START

```bash
./fun foo.fun arg1 arg2
```

Inside `foo.fun`:

```fun
#!/usr/bin/env ./fun
-- vim: ft=fun

let greet, sq

greet = fun(name) ! "hello, "..name end
sq    = fun(x)    ! x*x end

print(greet("world"))
print(sq(5))
```

# LANGUAGE

## Keyword sugar

| *fun*  | Lua        | Notes                       |
|--------|------------|-----------------------------|
| `fun`  | `function` | word-boundary substitution  |
| `let`  | `local`    | word-boundary substitution  |
| `!`    | `return `  | sigil; emits `return ` + RHS |

Substitutions are line-level. Strings (`"..."`, `'...'`, `[[...]]`)
and trailing `--` comments are hidden before substitution and restored
after, so `"!"` and other token-like contents survive unchanged.

## Control flow

`if` and `elseif` **require parentheses** around the condition; the
transpiler injects `then`. `end` and `do` are written literally.

```fun
if (x > 0)
  print("pos")
elseif (x < 0)
  print("neg")
else
  print("zero")
end
```

`for`, `while`, `repeat ... until` use plain Lua syntax (`do`/`end`
explicit, no sugar).

## Function definitions

`fun NAME(args) ... end` works like Lua's `function`:

```fun
fun sq(n) ! n*n end
fun NUM.mid(i) ! i.mu end
```

Anonymous: `fun(args) ... end`.

Named-as-local: combine with `let`:

```fun
let helper = fun(x) ! x+1 end
```

A trailing `=` on a `fun(args)` line is silently stripped (so an old
`name = fun(args) =` style still parses).

## Conditional init: `?=`

```fun
x ?= 42      -- if x == nil then x = 42 end
```

Statement-only; must start the line (optional indent allowed).

## Compound assignment

```fun
x += 1       -- x = x + 1
y -= 2       -- y = y - 2
z *= 3       -- etc.
w /= 4
```

Operators: `+= -= *= /=`. **LHS may be a dotted name**
(`[%w_%.]+` — so `obj.field += 1` works) and **RHS must be one
whitespace-separated token** (`%S+`). Bracket-indexed LHS like
`t[i] += 1` does **not** transform.

## Line continuation

A trailing `\` joins the next line; the joined-from physical line is
replaced with a blank to **preserve line numbers** for error reporting.

```fun
let result = some_function(arg1, arg2, \
                           arg3, arg4)
```

This is the **only** way to span constructs across physical lines for
features whose regex is per-line — see *one-line constraints* below.

## Comprehensions

```fun
let squares = [x*x for x in xs]
let evens   = [x   for x in xs if x % 2 == 0]
```

Compiles to an inline IIFE (immediately invoked function expression). If `iter` contains no `(`, the transpiler
wraps:

- single loop var → `for _,v in ipairs(iter)`
- comma in loop var → `for k,v in pairs(iter)`

If `iter` already contains `(`, it passes through verbatim.

## Strings and comments

- `--` starts a single-line comment.
- `--[[ ... ]]` is a long comment.
- `[[ ... ]]` is a long string (multi-line, **no interpolation**).
- `"..."`, `'...'` are regular strings (**no interpolation**).
- All string contents protected from substitution.

## Shebang

`#!/usr/bin/env ./fun` on line 1 makes the file directly executable;
the transpiler converts the shebang to a Lua comment before loading.

# OPTIONS

The `fun` runner takes no flags of its own. The first positional
argument is the `.fun` file; remaining arguments are forwarded to the
script via `arg[1]`, `arg[2]`, ... `arg[0]` is set to the script path.

# FILES

- `fun.lua` — the transpiler (a single Lua module).
- `fun` — the runner shim (`#!/usr/bin/env lua`).
- `*.fun` — *fun* source files.
- `etc/funlexer.py` — Pygments lexer (`FunLexer`).
- `etc/funpdf.sh` — `.fun` → PDF via pygmentize + pandoc + pdflatex.
- `etc/syntax/fun.vim` — vim syntax (loaded via `etc/nvimfun.lua`).
- `etc/nvimfun.lua`, `etc/nviminit.lua` — neovim filetype plugin.

# DIAGNOSTICS

When the transpiled Lua fails to load, `fun` writes a 5-line window
around the offending line (**transpiled** Lua, not source) to stderr,
then errors out. Line numbers refer to **transpiled** Lua, but the
blank-pad trick on `\` joins keeps source and transpiled line numbers
in lockstep, so the position usually points to the right physical
source line.

# ONE-LINE CONSTRAINTS

The transpiler runs substitutions **per physical line** (`src:gsub
"[^\n]+"`). Several constructs must therefore fit on one line.
Workaround: use `\` continuation.

## `if (...)` / `elseif (...)` — one line

The injection regex matches `if` (or `elseif`) followed by a
balanced-paren expression on the same line. Multi-line conditions
need `\`:

```fun
-- BAD: broken — closing paren on next physical line
if (very_long_condition_part1 and
    very_long_condition_part2)
  ...

-- OK: join with backslash
if (very_long_condition_part1 and \
    very_long_condition_part2)
  ...
```

## List comprehensions — one line

`[expr for var in iter]` (and the `if`-guarded form) must fit on one
line. The transpiler uses Lua's balanced-bracket matcher (`%b[]`) so
nested `[...]` inside the expression, iterator, or guard is fine
(e.g. `[r[i.at] for r in rows if r[i.at] ~= "?"]` works), but the
opening `[` and matching `]` must be on the **same physical line**.

```fun
-- BAD: broken — comprehension spans lines
let xs = [transform(x)
          for x in source]

-- OK: join with backslash
let xs = [transform(x) \
          for x in source]
```

## `?=` — one line, statement-leading

Pattern: `^(%s*)(%w+)%s*?=%s*([^;]+)`. Indented allowed; the RHS runs
up to `;` or end-of-line. Cannot follow other content on the same
line.

## Compound `+=`/`-=`/`*=`/`/=` — one word LHS

`(%w+)%s*([%+%-%*/])=%s+(%S+)`. Both sides constrained:

- LHS is a single `%w+` — **no fields or indexing**. `obj.field += 1`
  and `t[i] += 1` do **not** transform.
- RHS is **one** whitespace-separated token (`%S+`). `x += a + b`
  captures only `a`; the rest leaks.

Workaround: write the expansion by hand or wrap RHS in parens with no
internal whitespace — `x += (a+b)` works because `(a+b)` is one token.

# OTHER QUIRKS

## Lua statement-call ambiguity (`[` or `(` after a function call)

Lua grammar treats `f()[k]` as "call `f`, then index its return
value at `[k]`" — even when the `[` is on the next line. Newlines
are not statement terminators in Lua. So a comprehension or
parenthesized expression on the line **after** a function call gets
glued to that call:

```fun
-- BAD: broken — Lua parses as `print(...)[print(...) for k in fails]`
print(l.fmt("done"))
[print("FAIL "..k) for k in fails]
```

Lua tries to index `print`'s return value (nil) and errors with
`attempt to index a nil value`. The same trap fires when a
following line starts with `(`:

```fun
-- BAD: broken — Lua parses as `f()(g)()`
let x = f()
(g)()
```

Workaround: terminate the prior statement with `;`.

```fun
-- OK:
print(l.fmt("done"));
[print("FAIL "..k) for k in fails]
```

This is a Lua quirk, not a *fun* quirk — the transpiler emits Lua
exactly as written. Idiomatic rule: prepend `;` whenever a line
starts with `(` or `[` after a function call.

## `!` substitutes everywhere outside strings/comments

`!` is a literal global substitution to `return ` (with trailing
space). Lua identifiers can't contain `!`, so accidental damage is
rare, **but**:

- `!=` becomes `return =` — broken. Use Lua's `~=` for not-equal.
- `not !x` becomes `not return x` — broken. Just write `not x`.
- `if (x != y)` is **wrong**; write `if (x ~= y)`.

## `fun` and `let` use word boundaries

Frontier patterns `%f[%w_]fun%f[%W]` and `%f[%w_]let%f[%W]`. So:

- `letx` is **not** touched (no boundary).
- `myfun` is **not** touched.
- `funny` is **not** touched (`y` extends word).
- `fun(` and `fun ` and `let ` are transformed.

## String hiding does not handle `\"`-escaped quotes

The hiding regex is `'"[^"]*"'`. Strings containing escaped quotes
break the hiding:

```fun
let bad = "she said \"hi\""    -- hiding misparses this
```

Workaround: use single quotes, `[[...]]`, or split into pieces with
Lua's `..` concat.

## Method dispatch on plain tables

Plain Lua tables have no methods. `xs:remove(n)` is **not** sugar for
`table.remove(xs, n)` — Lua looks for a `remove` field and errors.
Use `table.remove(xs, n)` or alias at top: `let tremove =
table.remove`.

## No string interpolation anywhere

Neither `"..."`, `'...'`, nor `[[...]]` interpolate `{var}`. Build
strings with Lua's `..` concat.

## Long strings span multiple lines safely

`[[...]]` blocks are extracted from the whole source before line-by-
line processing, so multi-line long strings (and blank lines inside
them) work fine.

## Comments are passed through verbatim

A trailing `--` comment is split off before substitution and re-
appended after, so anything inside a comment survives unchanged.

# EXAMPLE

```fun
#!/usr/bin/env ./fun
-- vim: ft=fun

let Num, add

Num = fun(s,n) ! {name=s, at=n, n=0, mu=0, m2=0, sd=0} end

add = fun(c, v)
  c.n += 1
  let d = v - c.mu
  c.mu += d / c.n
  c.m2 += d * (v - c.mu)
  c.sd  = c.n < 2 and 0 or (c.m2 / (c.n - 1)) ^ 0.5
  ! c
end

-- comprehension: build cumulative stats
let xs = [add(Num("x",0), v) for v in {1,2,3,4,5}]
print(xs[#xs].mu, xs[#xs].sd)
```

# SEE ALSO

`lua(1)`, `pairs(3)`, `ipairs(3)`, `pygmentize(1)`, `pandoc(1)`

# AUTHORS

Tim Menzies <timm@ieee.org>, with iterative collaboration.
