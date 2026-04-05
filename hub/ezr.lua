#!/usr/bin/env lua

local s = require "the"
local the, help, l = s.the, s.help, s.l
local NUM, SYM, COLS, DATA, TREE = s.NUM, s.SYM, s.COLS, s.DATA, s.TREE

local types = require "types"
local methods = require "methods"
local tree = require "tree"

-- ## Eg
-- Complete test suite from ezr3.lua.

local eg = {}

eg["-h"] = function(_) print(help) end
eg["--the"] = function(_) l.oo(the) end

eg["--all"] = function(arg,    ss)
  ss = {}
  for k in pairs(eg) do if k ~= "--all" then l.push(ss, k) end end
  for _, k in ipairs(l.sort(ss)) do
    print("\n" .. k)
    math.randomseed(the.seed)
    eg[k](arg) end end

eg["--csv"] = function(f,    n)
  n = 0
  for row in l.things(f) do 
    if n % 30 == 0 then print(l.cat(l.map(row, l.rat))) end
    n = n + 1 end end

eg["--data"] = function(f,    data)
  data = types.Data(f)
  for _, c in ipairs(data.cols.y) do
    print(string.format("%s: n=%d mid=%s spread=%s", 
      c.txt, c.n, l.rat(c:mid()), l.rat(c:spread()))) end end

eg["--tree"] = function(f,    data,rows,fn_y)
  data = types.Data(f); rows = l.many(data.rows, the.Budget)
  data = data:clone(rows)
  fn_y = function(r) return data:disty(r) end
  tree.build(types.Tree(fn_y), data, data.rows):show() end

eg["--ranks"] = function(    dict,name,k,len)
  dict = {}
  for n = 1, 20 do
    name = "t" .. n;
    dict[name] = {}
    k, len = (n <= 5 and 2 or 1), (n <= 5 and 10 or 20)
    for _ = 1, 50 do 
      l.push(dict[name], l.weibull(k, len)) end end
  print("\nTop Tier Treatments:")
  for k, num in pairs(methods.bestRanks(dict)) do
    print(l.fmt("  %-5s median: %s", k, l.rat(num:mid()))) end end

-- ## Eg
-- Verification suite restored from ezr3.lua.

eg["--test"] = function(f,    data,outs,n,test,data2,node,top,fn_win,fn_y,fn_sort)
  data = types.Data(f)
  outs = types.Num("win")
  fn_win = methods.wins(data)
  for _ = 1, 20 do
    l.shuffle(data.rows)
    n = #data.rows // 2
    test = l.slice(data.rows, n + 1)
    data2 = data:clone(l.slice(data.rows, 1, math.min(n, the.Budget)))
    fn_y = function(r) return data2:disty(r) end
    node = tree.build(types.Tree(fn_y), data2, data2.rows)
    fn_sort = function(a, b) return node:leaf(a).y:mid() < node:leaf(b).y:mid() end
    l.sort(test, fn_sort)
    top = l.sort(l.slice(test, 1, the.Check), function(a,b) 
      return data2:disty(a) < data2:disty(b) end)
    methods.add(outs, fn_win(top[1])) end
  print(l.rat(math.floor(outs:mid()))) end

-- ## Main
-- CLI loop.

local function main(    k, v, n)
  n = 1
  while n <= #arg do
    k, v = arg[n], arg[n + 1]; n = n + 1
    if eg[k] then math.randomseed(the.seed); eg[k](v and l.thing(v) or nil)
      if v and not eg[v] then n = n + 1 end
    else
      for k1 in pairs(the) do
        if k == "-" .. k1:sub(1, 1) then the[k1] = l.thing(v); n = n + 1 end 
      end end end end

if (arg[0] or ""):match("ezr.*%.lua$") then main() end

return NUM, SYM, COLS, DATA, TREE, types.Tree, types.Sym, types.Num, types.Cols, 
       types.Data, methods.add, methods.sub, methods.adds, methods.mink, 
       tree.split, methods.same

