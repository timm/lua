local s = require "the"
local the, l, NUM, SYM, COLS, DATA = s.the, s.l, s.NUM, s.SYM, s.COLS, s.DATA
local abs, exp, log, max = math.abs, math.exp, math.log, math.max
local Cols = require("types").Cols

-- ## Update
-- add/sub/adds: The primary interface for state changes.
-- Centroids (mid) are computed once, cached, and reset on any update.

local function add(i, v, w)
  if v ~= "?" then i.n = i.n + 1; i:_add(v, w or 1) end; return v end

local function sub(i, v)
  return i:_add(v, -1) end

local function adds(vs,    num)
  num = num or require("types").Num()
  for _, v in ipairs(vs or {}) do add(num, v) end; return num end

function NUM._add(i, v, w,    err)
  if w < 0 and i.n <= 2 then i.n, i.mu, i.m2 = 0, 0, 0
  elseif i.n > 0 then
    err = v - i.mu
    i.mu = i.mu + w * err / i.n
    i.m2 = i.m2 + w * err * (v - i.mu) end end

function SYM._add(i, v, w)
  i.has[v] = (i.has[v] or 0) + w end

function COLS._add(i, row, w)
  for _, col in ipairs(i.all) do add(col, row[col.at], w) end end 
 
function DATA._add(i, row, w)
  if not i.cols then i.cols = Cols(row) 
  else  
    i._mid = nil
    i.cols:add(row, w) -- Fixed: COLS:add is now available.
    if w > 0 
    then l.push(i.rows, row) 
    else  --- usuually removes worst item, so search from back
      for n = #i.rows,1,-1 do if r == i.rows[n] then table.remove(i.rows, n); break end 
    end end end end

-- ## Query
-- Extraction of central tendency (mid) and diversity (spread).

function NUM.mid(i) return i.mu end

function SYM.mid(i,    most, mode)
  most = -1; for v, n in pairs(i.has) do if n > most then most, mode = n, v end end
  return mode end

function DATA.mid(i)
  i._mid = i._mid or l.map(i.cols.all, function(col) return col:mid() end)
  return i._mid end

function NUM.spread(i)
  return i.n > 1 and (max(0, i.m2) / (i.n - 1))^0.5 or 0 end

function SYM.spread(i)
  return -l.sum(i.has, function(_, v) return (v / i.n) * log(v / i.n, 2) end) 
end

function NUM.norm(i, v,    z)
  if v == "?" then return v end
  z = (v - i.mu)/(i:spread() + 1e-32)
  return 1 / (1 + exp(-1.7 * l.crop(z,-3,3)))end 
 
-- ## Distances
-- mink: Minkowski distance calculates aggregate goal error.
-- wins: opposite of regret, normalized between population median and best.

local function mink(vs,    err, n)
  local p = the.p or 2
  err, n = 0, 0; for _, x in ipairs(vs) do n = n + 1; err = err + abs(x)^p end
  return n == 0 and 0 or (err / n)^(1 / p) end

function DATA.disty(i, row,    fn)
  fn = function(col) return abs(col:norm(row[col.at]) - col.goal) end
  return mink(l.map(i.cols.y, fn)) end

function wins(data,    vs_errs, lo, n_mid)
  vs_errs = l.sort(l.map(data.rows, function(row) return data:disty(row) end))
  lo, n_mid = vs_errs[1], vs_errs[math.floor(#vs_errs / 2) + 1]
  return function(row)
    return math.floor(100 * (1 - ((data:disty(row) - lo) / (n_mid - lo + 1e-32)))) end 
end

-- ## Stats
-- Non-parametric comparisons: Cliff's Delta and KS-test.

local function same(xs, ys, eps,    n, m, n_gt, n_lt, ks, fn)
  xs, ys = l.sort(xs), l.sort(ys); n, m = #xs, #ys
  if abs(xs[math.floor(n/2)+1] - ys[math.floor(m/2)+1]) <= eps then return true end
  n_gt, n_lt = 0, 0
  for _, v in ipairs(xs) do
    n_gt = n_gt + l.bisect(ys, v); n_lt = n_lt + (m - l.bisect(ys, v + 1e-32)) end
  if abs(n_gt - n_lt) / (n * m) > the.cliffs then return false end
  ks, fn = 0, function(v) return abs(l.bisect(xs, v) / n - l.bisect(ys, v) / m) end
  for _, v in ipairs(xs) do ks = max(ks, fn(v)) end
  for _, v in ipairs(ys) do ks = max(ks, fn(v)) end
  return ks <= (the.ksconf or 1.36) * ((n + m) / (n * m))^0.5 end

function bestRanks(dict,    items, k0, vs0, best)
  items = {}
  for name, vs in pairs(dict) do 
    l.sort(vs); l.push(items, {name, vs, vs[math.floor(#vs/2)+1]}) end
  l.sort(items, function(a, b) return a[3] < b[3] end); k0, vs0 = items[1][1], items[1][2]
  best = {}; best[k0] = adds(vs0, require("types").Num(k0))
  for n = 2, #items do
    local k, vs = items[n][1], items[n][2]
    if same(vs0, vs, best[k0]:spread() * the.eps) then 
      best[k] = adds(vs, require("types").Num(k))
    else break end end; return best end

return {add = add, sub = sub, adds = adds, mink = mink, same = same, 
        bestRanks = bestRanks, wins = wins}

