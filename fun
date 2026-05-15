#!/usr/bin/env lua
-- fun runner: transpile + run a .fun file. forwards extra args.
-- --lua: dump transpiled Lua to stdout, don't run.
package.path = (debug.getinfo(1).source:match"@?(.*/)" or "./").."?.lua;"..package.path
local fun = require"fun"
if arg[1] == "--lua" then
  table.remove(arg, 1)
  local file = table.remove(arg, 1) or error("usage: fun --lua <file.fun>")
  io.write(fun.transpile(file))
  os.exit(0)
end
local file = table.remove(arg, 1) or error("usage: fun [--lua] <file.fun> [args...]")
arg[0] = file
fun(file)
