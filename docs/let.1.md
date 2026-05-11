% LET(1) | User Commands

# NAME

**let** — transpile and run a *let* source file (a tiny Lua-targeted source language)

# SYNOPSIS

**let** *FILE* [*ARGS*...]

# DESCRIPTION

*let* is a Lua-targeted source language whose transpiler is a single ~135-line
Lua function (`lets.lua`). Source files use the `.let` extension. The runner
shim `let` reads a `.let` file, transpiles it to Lua via `lets.lua`, executes
the result with the remaining arguments visible in Lua's `arg` table, and
forwards stdin/stdout/exit code.

By the time the source reaches Lua, it *is* Lua. *let* adds syntactic sugar
that compiles away — there is no runtime layer.

# QUICK START

```bash
./let foo.let arg1 arg2
```

Inside `foo.let`:

```let
#!/usr/bin/env let
-- vim: ft=let

Exports = greet, sq

greet = (name): "hello, {name}"
sq    = (x): x ** 2

print(greet("world"))
print(sq(5))

^ Exports()
```

The shebang `#!/usr/bin/env let` makes the file directly executable (the
shebang line is stripped before transpilation, and Lua tolerates it too).

# LANGUAGE

## Paragraphs

A *paragraph* is a run of non-blank lines, terminated by a blank line or EOF.

A paragraph whose **first line begins with whitespace** *or* with a `#`
character is a **comment paragraph**: every line in it is emitted to Lua
prefixed with `-- ` (markdown-style headings like `## Tree` survive intact).

Otherwise the paragraph is **code**, processed line by line; any blocks
still open when the paragraph ends are auto-closed.

```let
## This whole paragraph is a comment.
Even non-indented continuation lines get prefixed.

sq = (x): x ** 2     -- this paragraph is code
```

## Locals and declarations

| *let*                 | Lua                                            |
|-----------------------|------------------------------------------------|
| `let x = v`           | `local x = v`                                  |
| `let a,b,c = 1,2,3`   | `local a,b,c = 1,2,3`                          |
| `let f = (x): x+1`    | `local function f(x) return x+1 end`           |
| `let helper`          | `local helper` (forward declaration)           |

## Return

| *let*           | Lua            | Notes                                                      |
|-----------------|----------------|------------------------------------------------------------|
| `^ expr`        | `return expr`  | Line-start; `^` followed by optional whitespace, then expr |
| `^expr`         | `return expr`  | Space after `^` is optional                                |
| `^`             | `return`       | Bare return (no value)                                     |
| `if X: ^ expr`  | `if X then return expr end` | One-liner if with return-value body          |

`^` is recognized only at the **start** of a statement body. Inside string
literals or arithmetic expressions, `^` keeps its Lua meaning (exponent).

## Functions

Three equivalent forms.

### Statement form, named, multi-line

```let
sq = (n):
  ^ n ** 2
```

The header (`name = (params):`) must fit on one physical line. The body is
the indented lines that follow. The function closes when the paragraph ends.

Dotted and bracketed LHS work:

```let
NUM.mid = (i): i.mu
eg["-h"] = (_): print(help) end
```

`NUM.mid = ...` becomes `function NUM.mid(i) ... end`.
`eg["-h"] = ...` becomes `eg["-h"] = function(_) ... end` (assignment
form, since `function eg["x"](...)` is not legal Lua).

### Statement form, named, one-liner

Content after `:` on the same line auto-closes and auto-returns the body:

```let
sq     = (n): n ** 2                  -- function sq(n) return n^2 end
greet  = (name): "hello, {name}!"
helper = (x): x + 1
```

Auto-return is suppressed when the body starts with a statement keyword
(`if`, `for`, `while`, `local`, `do`, `repeat`, `return`, `break`), contains
`;`, or *is* an assignment (`lhs = rhs`).

### Inline lambda (expression context)

Inline lambdas inside expressions need an **explicit `end`** because no
paragraph boundary closes them, and require **whitespace after `:`** so the
transpiler can distinguish them from method calls (`obj:method`):

```let
cubed  = map({1,2,3}, (x): x*x*x end)
sorted = table.sort(xs, (a,b): a < b end)
```

The space after `:` is mandatory in lambdas. `(x):body end` (no space) is
not recognized as a lambda.

## Control flow

### `if` / `elseif` / `else`

```let
if x > 0:
  ^ "pos"
elseif x < 0:
  ^ "neg"
else:
  ^ "zero"
end                                   -- explicit close before sibling code

if cond: ^ "yes"                      -- one-liner; auto-closes
```

The block-opener form is `if cond:` with nothing after the colon.
The one-liner form is `if cond: body` — the body auto-returns/auto-closes.
`elseif`/`else` are continuations of an open `if` and end with `:`.

### `for`

```let
for i = 1, 10: print(i)               -- numeric, one-liner
for i = 1, n:                         -- numeric, multi-line
  acc = acc + i
end

for x in xs:                          -- iterates pairs(xs)
  print(x)
end

for x in io.lines("foo"): print(x)    -- iter has `(`; left as-is
for k,v in s:gmatch"x": print(k,v)    -- iter has `"`; left as-is
```

A bare iterable becomes `pairs(...)`. Iterators detected by presence of
`(`, `"`, or `'` are passed through verbatim — so `s:gmatch"..."` and
`io.lines("...")` work as expected.

### `while`

Standard Lua syntax (no sugar):

```let
while lo <= hi do
  let m = (lo + hi) // 2
  ...
end
```

### Inner block close

When sibling code follows an inner block within the same paragraph, the
inner block needs an explicit `end`. `end` may appear on its own line *or*
collapsed onto the last body line:

```let
trace = (n):
  for i = 1, n:
    s = s + i
    print(i, s)
  end                                 -- own line
  ^ s

trace = (n):
  for i = 1, n:
    s = s + i
    print(i, s) end                   -- collapsed onto body
  ^ s
```

Multiple consecutive `end`s may chain: `body end end end`. The transpiler
counts trailing `end` tokens, subtracts self-closing block-openers on the
same line, and emits the right depth change.

## Operators

| *let*           | Lua                          | Notes                          |
|-----------------|------------------------------|--------------------------------|
| `**`            | `^`                          | Exponent                       |
| `..`            | `..`                         | String concat (Lua-standard)   |
| `//`            | `//`                         | Integer divide (Lua 5.3+)      |
| `!=`            | `~=`                         | Not equal                      |
| `?=`            | truthy default assignment    | `x ?= y` → `x = x or y`        |
| `+= -= *= /=`   | compound assignment          | `x += 1` → `x = x + 1`         |
| <code>&#124;></code> | function call (pipe)    | `x \|> f` → `f(x)`; chains LTR |

`?=` and `+= -= *= /=` are statement-only and must start the line.

`|>` rewrites left-to-right by repeated substitution until none remain. The
right side must be a bare function name (not a call expression).

## Strings

Double-quoted strings interpolate `{expr}`:

```let
greet = (name, n): "hello {name}, you are {n}"
```

`{expr}` compiles to `"..tostring(expr).."`, so any Lua expression works.

Single-quoted strings and `[[...]]` long strings are not interpolated.

The transpiler protects the contents of `"..."` strings from
operator-substitution passes, so `"!="` survives as `"!="` (not `"~="`),
and `"a**b"` survives unchanged.

## List comprehensions

```let
squares = [x*x for x in xs]
evens   = [x   for x in xs if x % 2 == 0]
labels  = [t.name for t in tasks if t.done]
```

Compiled to an inline IIFE that builds and returns a table.

## Modules — `Exports`

A file becomes a module by listing exported names at the top and returning
the snapshot at the bottom:

```let
Exports = inc, dec, double

inc    = (x): x + 1
dec    = (x): x - 1
double = (x): x * 2

^ Exports()
```

`Exports = a, b, c` expands to:

```lua
local a, b, c
local Exports = function() return {a=a, b=b, c=c} end
```

Exported names are forward-declared as locals. Subsequent **bare**
assignments (`inc = (x): ...`) populate those slots. **Do not** re-declare
exported names with `let` — that creates a fresh shadowing local invisible
to the `Exports()` snapshot.

`^ Exports()` at the end returns the module table.

# OPTIONS

The `let` runner takes no flags of its own. The first positional argument
is the `.let` file; remaining arguments are forwarded to the script via
`arg[1]`, `arg[2]`, ... `arg[0]` is set to the script path.

# FILES

- `lets.lua` — the transpiler (a single Lua function).
- `let` — the runner shim (Lua script with `#!/usr/bin/env lua`).
- `*.let` — *let* source files.
- `etc/let.ssh` — a2ps sheet for pretty-printing `.let` to PostScript/PDF.
- `etc/nvimlet.lua` — neovim filetype + syntax plugin (loaded from `etc/init.lua`).

# DIAGNOSTICS

When the transpiled Lua fails to load, `let` writes the *transpiled output*
to stderr followed by Lua's parse error. The error line number refers to
the **transpiled** Lua, not the source `.let` file.

To dump the transpiled output without running:

```bash
lua -e 'local orig=load; _G.load=function(s,n) io.stderr:write(s) return orig(s,n) end' \
  let foo.let
```

# THE COLON `:` — ALL MEANINGS

`:` is overloaded. The transpiler disambiguates by **what follows it**.

| Pattern                                | Meaning                          |
|----------------------------------------|----------------------------------|
| `obj:method(...)` / `obj:method"..."`  | Lua method call (passthrough)    |
| `if cond:` *EOL*                       | block-opener `if cond then`      |
| `if cond: body`                        | one-liner: `if cond then body end` (auto-closes) |
| `else:` / `elseif cond:`               | continuation of an open `if`     |
| `for X:` *EOL* / `for X: body`         | block-opener / one-liner `for`   |
| `name = (args):` *EOL*                 | named-fn block-opener            |
| `name = (args): body`                  | named-fn one-liner               |
| `let name = (args):` (...same...)      | same, with `local` declaration   |
| `(args): body end`                     | inline anonymous lambda (must have `end` on same line) |

**Disambiguation rule.** A method call has the shape `:identifier` (no
whitespace between `:` and the next token). A let-language `:` is always
followed by **end-of-line, whitespace, or whitespace-then-content**.

You **cannot mix one-liner and continuation**. `if X: body` already closes
the `if`; a following `else:` is dangling. If you need a chain, use the
block-opener form on every branch:

```let
if X:
  body1
else:
  body2
end
```

# LIMITATIONS AND GOTCHAS

## Headers must be one line

Function and control-flow **headers** (everything up to and including the
opening `:`) must fit on one physical line. The body that follows may span
many lines.

## Increment / decrement

`++` and `--` are **not** increment/decrement. `--` starts a Lua comment.
Use `+= 1` / `-= 1`.

## Inline-lambda body cannot span lines

The inline-lambda regex `(args): body end` matches within a single line.
A closure with a multi-line body must be extracted to a named helper:

```let
-- ✗ broken — inline lambda body cannot span lines
let cb = (node, lvl, pre): 
  let p = lvl > 0 and ("|   "):rep(lvl-1)..pre or ""
  io.write(...) end

-- ✓ extract to a named helper
let cb = (node, lvl, pre):
  let p = lvl > 0 and ("|   "):rep(lvl-1)..pre or ""
  io.write(...)
end
i:nodes(cb)
```

## Inline-lambda needs space after `:`

`(args): body end` requires **whitespace after `:`** so the transpiler
distinguishes it from a method call. `(x):body end` is not a lambda —
it's parsed as a method call on `(x)`.

## One-liner `if` + extra `end`

A one-liner self-closes via the transpiler. Adding an explicit `end`
collapses the wrong block:

```let
for k in pairs(eg): if k != "--all": l.push(ss, k) end end
                                                      ↑↑↑
                                       one end too many — close for + outer
```

Either drop the `end` (one-liner `if` already closes itself):

```let
for k in pairs(eg): if k != "--all": l.push(ss, k) end
                                                    ↑
                                       just closes the for
```

Or use block-opener form. The transpiler counts trailing `end` tokens;
when in doubt, dump the transpiled Lua and count blocks by hand (see
**DIAGNOSTICS** below).

## Comprehensions and brackets inside iterators

The comprehension regex `[expr for x in iter]` stops at the **first** `]`.
If `iter` contains a literal `]` (e.g., inside a string), the regex
captures too little:

```let
-- ✗ broken — `]` inside "[^,]+" closes the comprehension early
let t = [l.thing(x) for x in s:gmatch"[^,]+"]
```

**Workaround**: bind the iterator to a let first:

```let
-- ✓ works — `xs` has no special chars
let xs = s:gmatch"[^,]+"
let t  = [l.thing(x) for x in xs]
```

Or use a plain `for` loop and `l.push`.

## `Exports` shadowing

`Exports = the, DATA, NUM` forward-declares `the, DATA, NUM` as locals.
**Do not** re-declare those names with `let`:

```let
Exports = the, NUM

-- ✗ creates a fresh local; Exports() snapshot still sees the original nil
let the = {}

-- ✓ bare assignment populates the slot Exports already declared
the = {}
```

Other names (helpers, library, math shortcuts) should still use `let`
because they're not exported.

## Long strings

`[[...]]` long strings work and pass through unchanged. They **do not
interpolate**. They **cannot contain blank lines** — a blank line in the
source ends the current paragraph; subsequent lines are mis-parsed.
Keep `[[...]]` blocks compact, or use multiple `".."` concatenations.

## `^` is statement-leading only

`^` is rewritten to `return` only at the **start** of a body. Mid-line
`^` keeps its Lua meaning (exponent). So `f = (x): x ^ 2 end` is `x^2`,
not `return 2`. And `^ x` / `^x` at the start of a body line is `return`.

## `;` suppresses auto-return in one-liners

The one-liner forms auto-prepend `return` to expression bodies. A `;` in
the body signals "this is a statement sequence, don't add `return`":

```let
l.push = (t,x): t[1+#t] = x; return x end
-- → function(t,x) t[1+#t] = x; return x end   (no auto-return)
```

Body that starts with `if`/`for`/`while`/`local`/`do`/`repeat`/`return`/
`break`, or is an assignment, also skips the auto-return.

## Method dispatch on plain tables

Plain Lua tables have no methods. `i.rows:remove(n)` is **not** sugar for
`table.remove(i.rows, n)` — it looks for a `remove` field on `i.rows`
and errors. Use `table.remove(i.rows, n)` (or alias once at top:
`let tremove = table.remove`).

# EXAMPLE

```let
#!/usr/bin/env let
-- vim: ft=let

Exports = sum, mean, classify

## Tiny stats helpers.

sum  = (xs):
  let n = 0
  for _, x in ipairs(xs): n = n + x
  ^ n

mean = (xs): sum(xs) / #xs

classify = (n):
  if n > 0:
    ^ "pos"
  elseif n < 0:
    ^ "neg"
  else:
    ^ "zero"
  end

^ Exports()
```

# SEE ALSO

`lua(1)`, `pairs(3)`, `ipairs(3)`, `a2ps(1)`

# AUTHORS

Tim Menzies <timm@ieee.org>, with iterative collaboration.
