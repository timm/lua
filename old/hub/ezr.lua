-- lua/ezr.lua
local s = require "ezr"
local the, help, l = s.the, s.help, s.l
local NUM, SYM, COLS, DATA, TREE = s.NUM, s.SYM, s.COLS, s.DATA, s.TREE

-- HYDRATE shared tables with logic before loading types
local methods = require "ezr.methods"
function DATA.add(i, ...) return methods.add(i, ...) end
function COLS.add(i, ...) return methods.add(i, ...) end

local types = require "ezr.types"
local tree = require "ezr.tree"

local eg = {}
eg["-h"] = function(_) print(help) end
eg["--the"] = function(_) l.oo(the) end

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

return {NUM=NUM, SYM=SYM, DATA=DATA, types=types, methods=methods, tree=tree}
