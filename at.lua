-- at.lua : ".at" -> Lua transpiler.
-- @ = function   $ = local   ! = return   . = end (followed by space/EOL)
-- ** = exponent  ++ = concat
-- Bracketed conditions: `if (cond) body .`, `elseif (cond) body .`,
-- `while (cond) body .`. Transpiler inserts `then`/`do` after the brackets.
-- `\` at line end joins next line (with blank-pad to preserve line numbers).
local loaded = {}

return function(file)
  if loaded[file] then return loaded[file] end

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

  local function line(b)
    if b:match"^%s*%-%-" or b:match"^%s*$" then return b end
    local strs = {}
    local function hide(m) strs[#strs+1]=m; return "\3"..#strs.."\3" end
    b = b:gsub('%[%[.-%]%]', hide)       -- long strings
    b = b:gsub('"[^"]*"',    hide)        -- double-quoted
    b = b:gsub("'[^']*'",    hide)        -- single-quoted
    local cmt = ""
    b = b:gsub("(%s*%-%-.*)$", function(c) cmt = c; return "" end)
    b = b:gsub("^(%s*)(%w+)%s*%?=%s*([^;]+)",  "%1if %2 == nil then %2 = %3 end")
    b = b:gsub("(%w+)%s*([%+%-%*/])=%s+(%S+)", "%1 = %1 %2 %3")
    b = b:gsub("@","function")                                -- @ = function
    b = b:gsub("%$","local ")                                 -- $ = local
    b = b:gsub("function(%b())%s*=%s*$", "function%1")        -- strip optional `=` after args
    b = b:gsub("%*%*","^")                                    -- ** = exponent
    b = b:gsub("%+%+","\1")                                   -- shield ++ for ..
    b = b:gsub("%.%.%.","\4")                                 -- shield vararg
    b = b:gsub("%.%.","\5")                                   -- shield literal ..
    b = b:gsub("%.(%s)"," end %1")                            -- . + space  -> end
    b = b:gsub("%.$"," end ")                                 -- . at EOL   -> end
    b = b:gsub("\5","..")
    b = b:gsub("\4","...")
    b = b:gsub("\1","..")                                     -- ++ -> ..
    b = b:gsub("!","return ")                                 -- ! = return
    local function brkt(kw, close)
      b = b:gsub("(%f[%w]"..kw.."%s*%b())(%s+)(%w+)", function(p,g,w)
        if w == close then return nil end
        return p.." "..close..g..w
      end)
      b = b:gsub("(%f[%w]"..kw.."%s*%b())%s*$", "%1 "..close)
    end
    brkt("if",     "then")
    brkt("elseif", "then")
    brkt("while",  "do")
    b = b:gsub("%[(.-) for (.-) in (.-) if (.-)%]", comp)
    b = b:gsub("%[(.-) for (.-) in (.-)%]", comp)
    b = b:gsub("\3(%d+)\3", function(n) return strs[tonumber(n)] end)
    return b .. cmt
  end

  local raw = io.open(file):read"*a":gsub("^#!","--")
                                    :gsub("([^\n]*)\\\n([^\n]*)\n", "%1 %2\n\n")
  local longs = {}
  raw = raw:gsub("%[%[.-%]%]", function(m)
    longs[#longs+1] = m
    return "\2"..#longs.."\2"
  end)
  local lua = raw:gsub("[^\n]+", line)
                 :gsub("\2(%d+)\2", function(n) return longs[tonumber(n)] end)
  local fn, err = load(lua, file)
  if not fn then
    local n = tonumber((err or ""):match":(%d+):")
    if n then
      local ls = {}
      for s in lua:gmatch"[^\n]*" do ls[#ls+1] = s end
      for i = math.max(1,n-2), math.min(#ls,n+2) do
        io.stderr:write(("%4d %s %s\n"):format(i, i==n and ">>" or "  ", ls[i] or ""))
      end
    end
    error(err)
  end
  loaded[file] = fn() or true
  return loaded[file]
end
