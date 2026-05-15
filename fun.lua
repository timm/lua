-- fun.lua : ".fun" -> Lua transpiler.
-- fun = function   let = local   ! = return
-- `if (cond)` / `elseif (cond)` : paren required, `then` injected.
-- `end`/`do` written literally.
-- `\` at line end joins next line (blank-pad preserves line numbers).
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

-- Parse a balanced [...] as a comprehension; return nil if not a comp.
local function tryComp(s)
  local body = s:sub(2, -2)
  local fp = body:find(" for ")
  if not fp then return s end
  local e    = body:sub(1, fp - 1)
  local rest = body:sub(fp + 5)
  local ip = rest:find(" in ")
  if not ip then return s end
  local v     = rest:sub(1, ip - 1)
  local rest2 = rest:sub(ip + 4)
  local cp = rest2:find(" if ")
  local i, c
  if cp then
    i = rest2:sub(1, cp - 1)
    c = rest2:sub(cp + 4)
  else
    i = rest2
  end
  return comp(e, v, i, c)
end

local function line(b)
  if b:match"^%s*%-%-" or b:match"^%s*$" then return b end
  local strs, cmt = {}, ""
  local function hide(m) strs[#strs+1]=m; return "\3"..#strs.."\3" end
  b = b:gsub('%[%[.-%]%]', hide)
       :gsub('"[^"]*"',    hide)
       :gsub("'[^']*'",    hide)
       :gsub("(%s*%-%-.*)$", function(c) cmt = c; return "" end)
       :gsub("^(%s*)(%w+)%s*%?=%s*([^;]+)",  "%1if %2 == nil then %2 = %3 end")
       :gsub("([%w_%.]+)%s*([%+%-%*/])=%s+(%S+)", "%1 = %1 %2 %3")
       :gsub("%f[%w_]fun%f[%W]",       "function")
       :gsub("%f[%w_]let%f[%W]",       "local")
       :gsub("%f[%w_]if(%s*%b())",     "if%1 then")
       :gsub("%f[%w_]elseif(%s*%b())", "elseif%1 then")
       :gsub("function(%b())%s*=%s*$", "function%1")
       :gsub("!",         "return ")
       :gsub("(%b[])", tryComp)
       :gsub("\3(%d+)\3", function(n) return strs[tonumber(n)] end)
  return b .. cmt
end

local function showCtx(lua, n)
  local lines = {}
  for s in lua:gmatch"[^\n]*" do lines[#lines+1] = s end
  for i = math.max(1, n-2), math.min(#lines, n+2) do
    io.stderr:write(("%4d %s %s\n"):format(i, i==n and ">>" or "  ", lines[i] or ""))
  end
end

return function(file)
  if loaded[file] then return loaded[file] end
  local src = io.open(file):read"*a"
                           :gsub("^#!", "--")
                           :gsub("([^\n]*)\\\n([^\n]*)\n", "%1 %2\n\n")
  local longs = {}
  src = src:gsub("%[%[.-%]%]", function(m)
    longs[#longs+1] = m; return "\2"..#longs.."\2"
  end)
  local lua = src:gsub("[^\n]+", line)
                 :gsub("\2(%d+)\2", function(n) return longs[tonumber(n)] end)
  local fn, err = load(lua, file)
  if not fn then
    showCtx(lua, tonumber((err or ""):match":(%d+):") or 0)
    error(err)
  end
  loaded[file] = fn() or true
  return loaded[file]
end
