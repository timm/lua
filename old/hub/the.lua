local l = require "lib"
local help = [[
ezr.lua : explainable multi-objective optimiization
(c) 2026, Tim Menzies <timm@ieee.org>, MIT license

  -B Budget=50     initial building budget
  -C Check=5       final check budget
  -c cliffs=0.195  Cliff's delta threshold
  -e eps=0.35      Cohen's threshold
  -k ksconf=1.36   KS test threshold
  -l leaf=3        min rows per tree leaf
  -p p=2           distance coeffecient
  -s seed=1        random number seed
  -S Show=30       width LHS tree displau
  -h               show help
]]

local the = {}
for k, v in help:gmatch("([%w_]+)%s*=%s*([^%s]+)") do the[k] = l.thing(v) end
math.randomseed(the.seed)

return {the=the, help=help, l=l, NUM={}, SYM={}, COLS={}, DATA={}, TREE={}}

