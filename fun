#!/usr/bin/env lua
-- fun runner: transpile + run a .fun file. forwards extra args.
package.path = (debug.getinfo(1).source:match"@?(.*/)" or "./").."?.lua;"..package.path
local fun = require"fun"
local file = table.remove(arg, 1) or error("usage: fun <file.fun> [args...]")
arg[0] = file
fun(file)
