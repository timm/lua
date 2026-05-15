-- fun.lua : ".fun" -> Lua transpiler. Per-line + indent-closed blocks.
-- Sigils:
--   fun = function   let = forward-decl local (no value)   ! = return
--   NAME := V        = local-with-value
--   `if (c):` / `elseif (c):` / `else:` / `for X in Y:` / `while c:` / `fun(args):`
--   Body after `:` on same line (one-liner, auto `end`) OR indented next lines
--   (multi-line, outdent emits `end`). Inline anonymous funs in expressions
--   still need explicit `end`.
local loaded = {}

local function comp(e,v,i,c)
  if not v:find"," and not i:find"%(" then
    v, i = "_,"..v, "ipairs("..i..")"
  elseif not i:find"%(" then
    i = "pairs("..i..")"
  end
  local guard = c and ("if "..c.." then ") or ""
  local close = c and "end " or ""
  return ("(function() local _r={} for %s in %s do %s_r[#_r+1]=%s %send return _r end)()")
         :format(v, i, guard, e, close)
end

-- Statement-level one-liner: `:` followed by body content on same line,
-- and line starts with a known opener (if/elseif/else/for/while/:=fun/=fun).
local function isStmtOneLiner(raw)
  if not raw:find":%s+%S" then return false end
  if raw:find"%f[%w_]end%f[%W]" then return false end
  local t = raw:gsub("^%s+", "")
  return t:match"^if%s*%("
      or t:match"^elseif%s*%("
      or t:match"^else%s*:"
      or t:match"^for%s"
      or t:match"^while%s"
      or t:match":=%s*fun%s*%("
      or t:match"^[%w_.%[%]\"'%-]+%s*=%s*fun%s*%("
end

local function endsBlockOpener(s)
  if s:match"%f[%w_]then%s*$" then return true end
  if s:match"%f[%w_]do%s*$" then return true end
  local t = s:gsub("^%s+", "")
  if t:match"^local%s+[%w_.,%s]+%s*=%s*function%b()%s*$" then return true end
  if t:match"^[%w_.%[%]\"'%-]+%s*=%s*function%b()%s*$" then return true end
  if t:match"^return%s+function%b()%s*$" then return true end
  return false
end

local function isContinuation(raw)
  return raw:match"^%s*elseif%f[%W]" or raw:match"^%s*else%f[%W]"
end

-- Per-line: hide strings/comments, run substitutions, restore.
local function line(b)
  if b:match"^%s*%-%-" or b:match"^%s*$" then return b end
  local strs, cmt = {}, ""
  local function hide(m) strs[#strs+1]=m; return "\3"..#strs.."\3" end
  b = b:gsub('%[%[.-%]%]', hide)
       :gsub('"[^"]*"',    hide)
       :gsub("'[^']*'",    hide)
       :gsub("(%s*%-%-.*)$", function(c) cmt = c; return "" end)
       :gsub("^(%s*)let%s+([%w_][%w_,%s]*%s*:=)", "%1%2")
       :gsub("^(%s*)([%w_][%w_,%s]*)%s*:=", "%1local %2 =")
       :gsub("(;%s*)([%w_][%w_,%s]*)%s*:=", "%1local %2 =")
       :gsub("^(%s*)([%w_.]+)%s*([%+%-%*/])=%s+", "%1%2 = %2 %3 ")
       :gsub("([:;])(%s*)([%w_.]+)%s*([%+%-%*/])=%s+",
             "%1%2%3 = %3 %4 ")
       :gsub("^(%s*)([%w_.]+)%s*%?=%s*([^;]+)",
             "%1if %2 == nil then %2 = %3 end")
       :gsub("([:;])(%s*)([%w_.]+)%s*%?=%s*([^;]+)",
             "%1%2if %3 == nil then %3 = %4 end")
       :gsub("%f[%w_]fun%f[%W]",       "function")
       :gsub("%f[%w_]let%f[%W]",       "local")
       :gsub("%f[%w_]if%s+(.-)%s*:%s*$", "if %1 then")
       :gsub("%f[%w_]if%s+(.-)%s*:(%s)", "if %1 then%2")
       :gsub("%f[%w_]elseif%s+(.-)%s*:%s*$", "elseif %1 then")
       :gsub("%f[%w_]elseif%s+(.-)%s*:(%s)", "elseif %1 then%2")
       :gsub("(%f[%w_]for%s.-)%s*:%s*$", "%1 do")
       :gsub("(%f[%w_]for%s.-)%s*:(%s)", "%1 do%2")
       :gsub("(%f[%w_]while%s.-)%s*:%s*$", "%1 do")
       :gsub("(%f[%w_]while%s.-)%s*:(%s)", "%1 do%2")
       :gsub("function(%b())%s*:%s*$", "function%1")
       :gsub("function(%b())%s*:(%s)", "function%1%2")
       :gsub("(%f[%w_]else)%s*:%s*$", "%1")
       :gsub("(%f[%w_]else)%s*:(%s)", "%1%2")
       :gsub("!",         "return ")
       :gsub("%b[]", function(m)
         local inner = m:sub(2, -2)
         local e,v,i,c = inner:match"^(.-) for (.-) in (.-) if (.+)$"
         if e then return comp(e,v,i,c) end
         e,v,i = inner:match"^(.-) for (.-) in (.+)$"
         if e then return comp(e,v,i) end
         return m
       end)
       :gsub("\3(%d+)\3", function(n) return strs[tonumber(n)] end)
  return b .. cmt
end

local function indent(s)
  return #((s:match"^(%s*)" or ""):gsub("\t", "  "))
end

local function showCtx(lua, n)
  local lines = {}
  for s in lua:gmatch"[^\n]*" do lines[#lines+1] = s end
  for i = math.max(1, n-2), math.min(#lines, n+2) do
    io.stderr:write(("%4d %s %s\n"):format(i, i==n and ">>" or "  ", lines[i] or ""))
  end
end

local function transpile(file)
  local src = io.open(file):read"*a":gsub("^#!", "--")
  local longs = {}
  src = src:gsub("%[%[.-%]%]", function(m)
    longs[#longs+1] = m; return "\2"..#longs.."\2"
  end)
  local out, stack = {}, {}
  for raw in (src.."\n"):gmatch"([^\n]*)\n" do
    if raw:match"^%s*$" or raw:match"^%s*%-%-" then
      out[#out+1] = raw
    else
      local ind = indent(raw)
      if not isContinuation(raw) then
        while #stack > 0 and stack[#stack] >= ind do
          out[#out+1] = string.rep(" ", stack[#stack]) .. "end"
          stack[#stack] = nil
        end
      end
      if isStmtOneLiner(raw) and not raw:match"%f[%w_]end%s*$" then
        raw = raw .. " end"
      end
      local cooked = line(raw)
      out[#out+1] = cooked
      if endsBlockOpener(cooked) and not isContinuation(raw) then
        stack[#stack+1] = ind
      end
    end
  end
  while #stack > 0 do
    out[#out+1] = string.rep(" ", stack[#stack]) .. "end"
    stack[#stack] = nil
  end
  return (table.concat(out, "\n")
              :gsub("\2(%d+)\2", function(n) return longs[tonumber(n)] end))
end

local function run(file)
  if loaded[file] then return loaded[file] end
  local lua = transpile(file)
  local fn, err = load(lua, file)
  if not fn then
    showCtx(lua, tonumber((err or ""):match":(%d+):") or 0)
    error(err)
  end
  loaded[file] = fn() or true
  return loaded[file]
end

return setmetatable({transpile=transpile, run=run},
                    {__call = function(_, file) return run(file) end})
