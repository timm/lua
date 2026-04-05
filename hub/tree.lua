local s = require "the"
local the, l, NUM, SYM, TREE = s.the, s.l, s.NUM, s.SYM, s.TREE

-- ## Tree
-- Recursively partitions data to minimize variance.

function TREE.build(i, data, rows,    mid, best, bestW, w)
  local types, methods = require "types", require "methods"
  local leaf = the.leaf or 3
  mid, i.y = data:clone(rows):mid(), methods.adds(l.map(rows, function(r) return i.score(r) end))
  i.mids = l.kv(data.cols.y, function(c) return c.txt end, function(c) return mid[c.at] end)
  if #rows < 2 * leaf then return i end; best, bestW = nil, 1E32
  for _, col in ipairs(data.cols.x) do
    for _, cut in ipairs(col:splits(rows, i.score)) do
      w = cut.lhs.n * cut.lhs:spread() + cut.rhs.n * cut.rhs:spread()
      if w < bestW and math.min(#cut.left, #cut.right) >= leaf then 
        best, bestW = cut, w end end end
  if best then
    i.col, i.cut, i.at = best.col, best.cut, best.col.at
    i.left, i.right = types.Tree(i.score):build(data, best.left), 
                      types.Tree(i.score):build(data, best.right) 
  end; return i end

-- ## Navigation
-- Traversing and showing the tree structure.

function NUM.leaf(i, cut, v)
  return v <= cut end

function SYM.leaf(i, cut, v)
  return v == cut end

function TREE.leaf(i, row,    v)
  if not i.col then return i end; v = row[i.at]
  if v == "?" then return i.left:leaf(row) end
  -- Call the leaf method directly on the instance (Polymorphic HINT).
  return (i.col:leaf(i.cut, v) and i.left or i.right):leaf(row) end

function TREE.nodes(i, fn, n_lvl, s_pre)
  n_lvl, s_pre = n_lvl or 0, s_pre or ""; fn(i, n_lvl, s_pre)
  if not i.col then return end; local s_yes, s_no = i.col:op()
  local nodes = l.sort({{i.left, s_yes}, {i.right, s_no}},
                    function(a, b) return a[1].y:mid() < b[1].y:mid() end)
  for _, p in ipairs(nodes) do
    p[1]:nodes(fn, n_lvl + 1, i.col.txt .. " " .. p[2] .. " " .. l.rat(i.cut)) end 
end

function SYM.op(i) return "==", "!=" end
function NUM.op(i) return "<=", ">" end

function TREE.show(i)
  i:nodes(function(node, n_lvl, s_pre)
    local pre = n_lvl > 0 and string.rep("|   ", n_lvl - 1) .. s_pre or ""
    io.write(string.format("%-"..(the.Show or 30).."s ,%4s ,(%3d),  %s\n",
      pre, l.rat(node.y:mid()), node.y.n, l.rat(node.mids))) end) end

-- ## Splits
-- Divides rows based on a pivot.

local function split(col, rows, fn_score, cut, fn_test,    lhs, rhs, L, R, ok)
  local types, methods = require "types", require "methods"
  local leaf = the.leaf or 3
  lhs, rhs, L, R = types.Num(), types.Num(), {}, {}
  for _, row in ipairs(rows) do
    ok = row[col.at] == "?" or fn_test(row[col.at])
    l.push(ok and L or R, row); methods.add(ok and lhs or rhs, fn_score(row)) end
  if #L >= leaf and #R >= leaf then
    return {col = col, cut = cut, left = L, right = R, lhs = lhs, rhs = rhs} end 
end

function NUM.splits(i, rows, fn_score,    vs, n_med, cut)
  vs = {}
  for _, row in ipairs(rows) do if row[i.at] ~= "?" then l.push(vs, row[i.at]) end end
  if #vs < 2 then return {} end; l.sort(vs); n_med = vs[math.floor(#vs / 2) + 1]
  cut = split(i, rows, fn_score, n_med, function(v) return v <= n_med end)
  return cut and {cut} or {} end

function SYM.splits(i, rows, fn_score,    seen, outs, cut)
  seen, outs = {}, {}
  for _, row in ipairs(rows) do
    local v = row[i.at]
    if v ~= "?" and not seen[v] then
      seen[v], cut = true, split(i, rows, fn_score, v, function(x) return x == v end)
      if cut then l.push(outs, cut) end 
    end end; return outs end

return {build = TREE.build, show = TREE.show, split = split}

