#!/usr/bin/env lua
-- fun runner: transpile + run a .fun file. forwards extra args.
package.path = (debug.getinfo(1).source:match"@?(.*/)" or "./").."?.lua;"
            .. package.path

local HELP = [[
fun : run a .fun file (transpile to Lua + execute)

usage:
  fun [opts] FILE.fun [script-args...]

opts:
  -h, --help     show this help
  -s, --show     print transpiled Lua to stdout (do not run)

examples:
  fun ezr.fun --tree
  fun -s ezr.fun > ezr.lua
]]

local opt
while arg[1] and arg[1]:sub(1,1) == "-" do
  local a = table.remove(arg, 1)
  if a == "-h" or a == "--help" then print(HELP); os.exit(0)
  elseif a == "-s" or a == "--show" then opt = "show"
  else io.stderr:write("unknown flag: "..a.."\n"); os.exit(1) end
end

local file = table.remove(arg, 1) or
             (io.stderr:write(HELP) and os.exit(1))
arg[0] = file

local fun = require"fun"
if opt == "show" then
  io.write(fun.transpile(file))
else
  fun.run(file)
end
