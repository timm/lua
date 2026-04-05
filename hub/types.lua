local s = require "the"
local l, NUM, SYM, COLS, DATA, TREE = s.l, s.NUM, s.SYM, s.COLS, s.DATA, s.TREE

-- ## Structs
-- Constructors for core data containers.
-- Num/Sym summarize streams; Tree holds the model.

local function Tree(fn_score)
  return l.new(TREE, {score = fn_score}) end

local function Sym(s_name, n)
  return l.new(SYM, {txt = s_name or "", at = n or 0, has = {}, n = 0}) end

local function Num(s_name, n)
  return l.new(NUM, {txt = s_name or "", at = n or 0, n = 0, mu = 0, m2 = 0,
                   goal = s_name and s_name:match "-$" and 0 or 1}) end

local function Cols(ss_names,    xs, ys, all, col)
  xs, ys, all = {}, {}, {}
  for n, name in ipairs(ss_names) do
    col = l.push(all, (name:match "^[A-Z]" and Num or Sym)(name, n))
    if not name:match "X$" then l.push(name:match "[%+%-!]$" and ys or xs, col) end end
  return l.new(COLS, {x = xs, y = ys, all = all, names = ss_names}) end

local function Data(src,    data)
  data = l.new(DATA, {rows = {}, cols = nil, _mid = nil})
  if type(src) == "string" then for row in l.things(src) do DATA.add(data, row) end
  else for _, row in ipairs(src or {}) do DATA.add(data, row) end end
  return data end

function DATA.clone(i, rows)
  return require("methods").adds(rows or {}, Data({i.cols.names})) end

return {Tree = Tree, Sym = Sym, Num = Num, Cols = Cols, Data = Data}

