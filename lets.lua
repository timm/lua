-- lets.lua : tiny "let" -> Lua. Explicit `end` everywhere. No paragraph magic.
local lets, loaded = nil, {}

lets = function(file)
  if loaded[file] then return loaded[file] end

  local function expr(s)
    s = s:gsub("%[(.-) for (.-) in (.-) if (.-)%]",
      "(function() local _r={} for %2 in pairs(%3) do if %4 then _r[#_r+1]=%1 end end return _r end)()")
    s = s:gsub("%[(.-) for (.-) in (.-)%]",
      "(function() local _r={} for %2 in pairs(%3) do _r[#_r+1]=%1 end return _r end)()")
    s = s:gsub("%*%*","\0"):gsub("\0","^")                     -- ** -> ^
    return s
  end

  local function ret(bd)
    bd = bd:gsub("^%^%s?", "return ")
    bd = bd:gsub(";%s*%^%s?", "; return ")
    return bd
  end

  local function line(b)
    b = b:gsub("^(%w+)%s*%?=%s*(.+)$",  "if %1 == nil then %1 = %2 end")
    b = b:gsub("^(%w+)%s*([%+%-%*/])=%s*(.+)$", "%1 = %1 %2 %3")
    b = b:gsub("^if%s+(.-):%s*$",      "if %1 then")
    b = b:gsub("^elseif%s+(.-):%s*$",  "elseif %1 then")
    b = b:gsub("^else:%s*$",           "else")
    b = b:gsub("^for%s+(.-)%s+in%s+(.-):%s*$", function(v,it)
      local i = (it:find"%(" or it:find'"' or it:find"'") and it or "pairs("..it..")"
      return "for "..v.." in "..i.." do" end)
    b = b:gsub("^for%s+(.-)%s*=%s*(.-):%s*$", function(v,it)
      return "for "..v.." = "..it.." do" end)
    -- inline lambda: (args): body end   (single-statement bodies; no nested inline lambdas)
    b = b:gsub("%(([^%(%)]-)%):%s+(.-)%s+end", function(a,bd)
      return "function("..a..") "..ret(bd).." end" end)
    -- let-named-fn block opener
    b = b:gsub("^let%s+(%w+)%s*=%s*%((.-)%):%s*$", function(n,a)
      return "local function "..n.."("..a..")" end)
    b = b:gsub("^let%s",  "local ")
    b = b:gsub("^%^%s?",  "return ")
    -- named-fn block opener: bracket-LHS uses assignment form, dotted/plain uses function form
    b = b:gsub('^([%w_%.%[%]"\'%-]+)%s*=%s*%((.-)%):%s*$', function(n,a)
      if n:find"%[" then return n.." = function("..a..")" end
      return "function "..n.."("..a..")" end)
    return expr(b)
  end

  local function delta(s)
    s = s:gsub('"[^"]*"', ""):gsub("'[^']*'", "")
    s = s:gsub("%-%-.*$", "")
    local d = 0
    for _ in s:gmatch"%f[%w]then%f[%W]"     do d = d + 1 end
    for _ in s:gmatch"%f[%w]do%f[%W]"       do d = d + 1 end
    for _ in s:gmatch"%f[%w]function%f[%W]" do d = d + 1 end
    for _ in s:gmatch"%f[%w]end%f[%W]"      do d = d - 1 end
    for _ in s:gmatch"%f[%w]elseif%f[%W]"   do d = d - 1 end
    return d
  end

  local h = io.open(file); local src = h:read"*a"; h:close()
  if src:sub(1,2) == "#!" then src = "--"..src:sub(3) end          -- shebang -> comment
  local out, depth = {}, 0
  for ln in (src.."\n"):gmatch"([^\n]*)\n" do
    local pad, body = ln:match"^( *)(.*)"
    body = body:gsub("^\f+", "")
    if body:sub(1,2) == "--" then
      out[#out+1] = pad..body
    elseif body == "" then
      out[#out+1] = ""
    else
      local r = line(body)
      out[#out+1] = pad..r
      depth = depth + delta(r)
    end
  end

  if depth ~= 0 then
    io.stderr:write(("let: block balance off by %d in %s\n"):format(depth, file))
  end

  local lua = table.concat(out, "\n")
  local fn, err = load(lua, file)
  if not fn then
    local n = tonumber((err or ""):match":(%d+):")
    if n then
      local lines = {}
      for s in lua:gmatch"[^\n]*" do lines[#lines+1] = s end
      local lo, hi = math.max(1, n-2), math.min(#lines, n+2)
      for i = lo, hi do
        io.stderr:write(("%4d %s %s\n"):format(i, i==n and ">>" or "  ", lines[i] or ""))
      end
    end
    error(err)
  end
  loaded[file] = fn() or true
  return loaded[file], lua
end

return lets
