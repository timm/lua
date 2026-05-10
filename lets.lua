-- lets.lua : tiny "let" -> Lua. one-liners auto-close. `end` closes blocks.
--                                 `..` is string concat (Lua-standard).
local lets, loaded = nil, {}

lets = function(file)
  if loaded[file] then return loaded[file] end

  local function expr(s)
    s = s:gsub("%[(.-) for (.-) in (.-) if (.-)%]",
      "(function() local t={} for %2 in pairs(%3) do if %4 then t[#t+1]=%1 end end return t end)()")
    s = s:gsub("%[(.-) for (.-) in (.-)%]",
      "(function() local t={} for %2 in pairs(%3) do t[#t+1]=%1 end return t end)()")
    -- Protect "..." strings so ** != etc don't mangle their contents.
    local strs = {}
    s = s:gsub('"[^"]*"', function(m) strs[#strs+1]=m; return "\2"..#strs.."\2" end)
    s = s:gsub("%*%*","\0"):gsub("\0","^")                     -- ** -> ^
    s = s:gsub("!=", "~=")                                     -- != -> ~=
    while s:find"|>" do                                        -- x |> f -> f(x)
      s = s:gsub("([%w_]+%b()?)%s*|>%s*([%w_]+)", "%2(%1)") end
    s = s:gsub("\2(%d+)\2", function(n) return strs[tonumber(n)] end)
    s = s:gsub('"([^"]*)"', function(c)                        -- "hi {name}" interp
      if not c:find"{" then return nil end
      return '"'..c:gsub("{([^}]+)}", '"..tostring(%1).."')..'"' end)
    return s
  end

  local function ret(bd) return (bd:gsub("^%^%s?","return ")) end
  local function open1(opn, bd)
    if bd == "" then return opn end
    return opn.." "..ret(bd).." end"
  end
  local function openF(opn, bd)
    if bd == "" then return opn end
    bd = ret(bd)
    local kw = bd:match"^(%w+)" or ""
    local skip = bd:find";" or kw=="return" or kw=="if" or kw=="for"
              or kw=="while" or kw=="local" or kw=="do" or kw=="repeat"
              or kw=="break"
              or bd:match"^[%w_%.%[%]%s,]+=[^=]"  -- assignment
    if not skip then bd = "return "..bd end
    return opn.." "..bd.." end"
  end

  local function line(b)
    b = b:gsub("^(%w+)%s*%?=%s*(.+)$",  "%1 = %1 or %2")
    b = b:gsub("^(%w+)%s*([%+%-%*/])=%s*(.+)$", "%1 = %1 %2 %3")
    -- if/elseif/else/for first so inline-lambda doesn't eat their `(...)` conds
    b = b:gsub("^if%s+(.-):%s*$", "if %1 then")
    b = b:gsub("^if%s+(.-):%s+(.+)$", function(c,bd)
      return open1("if "..c.." then", bd) end)
    b = b:gsub("^elseif%s+(.-):%s*$",  "elseif %1 then")
    b = b:gsub("^else:%s*$",           "else")
    -- generic for first; ` in ` keyword disambiguates from numeric
    b = b:gsub("^for%s+(.-)%s+in%s+(.-):%s*$", function(v,it)
      local i = (it:find"%(" or it:find'"' or it:find"'") and it or "pairs("..it..")"
      return "for "..v.." in "..i.." do" end)
    b = b:gsub("^for%s+(.-)%s+in%s+(.-):%s+(.+)$", function(v,it,bd)
      local i = (it:find"%(" or it:find'"' or it:find"'") and it or "pairs("..it..")"
      return open1("for "..v.." in "..i.." do", bd) end)
    b = b:gsub("^for%s+(.-)%s*=%s*(.-):%s*$", function(v,it)
      return "for "..v.." = "..it.." do" end)
    b = b:gsub("^for%s+(.-)%s*=%s*(.-):%s+(.+)$", function(v,it,bd)
      return open1("for "..v.." = "..it.." do", bd) end)
    -- inline lambda: (args): body end  (anywhere on line; require space after `:`
    -- so we don't match method-call `:method` shapes)
    b = b:gsub("%(([^%(%)]-)%):%s+(.-)%s+end", function(a,bd)
      return openF("function("..a..")", bd) end)
    -- let-named-fn: block-opener (no body) and one-liner (body)
    b = b:gsub("^let%s+(%w+)%s*=%s*%((.-)%):%s*$", function(n,a)
      return "local function "..n.."("..a..")" end)
    b = b:gsub("^let%s+(%w+)%s*=%s*%((.-)%):%s+(.+)$", function(n,a,bd)
      return openF("local function "..n.."("..a..")", bd) end)
    b = b:gsub("^let%s",                            "local ")
    b = b:gsub("^%^%s?",                            "return ")
    -- named-fn: dotted/bracketed LHS allowed. Bracketed (e.g. eg["-h"]) emits
    -- assignment form `lhs = function(...)`; plain/dotted uses `function name(...)`.
    b = b:gsub('^([%w_%.%[%]"\'%-]+)%s*=%s*%((.-)%):%s*$', function(n,a)
      if n:find"%[" then return n.." = function("..a..")" end
      return "function "..n.."("..a..")" end)
    b = b:gsub('^([%w_%.%[%]"\'%-]+)%s*=%s*%((.-)%):%s+(.+)$', function(n,a,bd)
      if n:find"%[" then return openF(n.." = function("..a..")", bd) end
      return openF("function "..n.."("..a..")", bd) end)
    b = b:gsub("^Exports%s*=%s*(.+)$", function(r)
      local n,t = {},{}
      for w in r:gmatch"[%w_]+" do n[#n+1]=w; t[#t+1]=w.."="..w end
      return "local "..table.concat(n,",")
        .."\nlocal Exports = function() return {"..table.concat(t,",").."} end" end)
    return expr(b)
  end

  local function delta(s)
    if s == "end" then return -1 end                           -- bare end: close one
    if s:match"^else" then return 0 end                        -- continuation
    -- count trailing ` end` markers (line may end with multiple)
    local nend, rest = 0, s
    while rest:match" end%s*$" do
      nend = nend + 1
      rest = rest:gsub(" end%s*$", "", 1)
    end
    if nend > 0 then
      -- subtract self-closing producers on the same line
      local self_closed = 0
      if rest:match"^if " or rest:match"^elseif " or rest:match"^for "
        or rest:match"^while " or rest:match"^function "
        or rest:match"^local function " then self_closed = 1 end
      for _ in rest:gmatch"function%(" do self_closed = self_closed + 1 end
      return -(nend - self_closed)
    end
    if s:match" then%s*$" or s:match" do%s*$" then return 1 end
    -- named or anonymous fn block-opener: `function NAME(args)` or `function(args)` at EOL.
    -- Use [^%(%)] to avoid spilling past an inner `function(...) ... end)`.
    if s:match"function%s*[%w_%.]*%s*%([^%(%)]*%)%s*$" then return 1 end
    return 0
  end

  local h = io.open(file); local src = h:read"*a"; h:close()
  if src:sub(1,1) == "#" then src = src:gsub("^[^\n]*\n","",1) end -- strip shebang
  local out = {}
  for para in (src.."\n\n"):gmatch"(.-)\n\n" do
    local f = para:match"^[^\n]*" or ""
    if f:match"^[ \t]" then
      -- whole paragraph is a doc block (first line indented)
      for ln in para:gmatch"[^\n]+" do out[#out+1]="-- "..ln end
    else
      local depth = 0
      for ln in para:gmatch"[^\n]+" do
        local pad, body = ln:match"^( *)(.*)"
        if body:sub(1,1) == "#" then
          out[#out+1] = pad.."-- "..body                       -- line-level comment
        elseif body ~= "" then
          local r = line(body)
          out[#out+1] = pad..r
          depth = depth + delta(r)
        end
      end
      while depth > 0 do out[#out+1]="end"; depth=depth-1 end  -- paragraph closes rest
    end
    out[#out+1] = ""
  end

  local lua    = table.concat(out, "\n")
  local fn,err = load(lua, file)
  if not fn then io.stderr:write(lua,"\n"); error(err) end
  loaded[file] = fn() or true
  return loaded[file], lua
end

return lets
