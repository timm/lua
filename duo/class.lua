-- class.lua
-- Compatible with Lua 5.1 (not 5.0).
function class(base, init)
   local c = {}    -- a new class instance
   if not init and type(base) == 'function' then
      init = base
      base = nil
   elseif type(base) == 'table' then
    -- our new class is a shallow copy of the base class!
      for i,v in pairs(base) do
         c[i] = v
      end
      c._base = base
   end
   -- the class will be the metatable for all its objects,
   -- and they will look up their methods in it.
   c.__index = c

   -- expose a constructor which can be called by <classname>(<args>)
   local mt = {}
    mt.__tostring = function(self)
     local s, sep, lst, t = "", "", {}, self or {}
     for k,v in pairs(t) do
       if  k ~= "class" and k ~= "super" then
         if "_" ~= string.sub(k, 1, 1) then
           lst[#lst+1] = k end end end
     table.sort(lst)
     for k=1,#lst do
       s = s .. sep .. lst[k] .. "=" .. tostring(t[lst[k]]) 
       sep=", " 
     end 
     return "{{" .. s .. "}}"
    end
 
   mt.__call = function(class_tbl, ...)
   local obj = {}
   setmetatable(obj,c)
   if class_tbl.init then
      class_tbl.init(obj,...)
   else 
      -- make sure that any stuff from the base class is initialized!
      if base and base.init then
      base.init(obj, ...)
      end
   end
   return obj
   end
   c.init = init
   c.is_a = function(self, klass)
      local m = getmetatable(self)
      while m do 
         if m == klass then return true end
         m = m._base
      end
      return false
   end
   setmetatable(c, mt)
   return c
end

A = class()
function A:init(x)
  self.x = x
end
function A:test()
  print(self.x)
end

B = class(A)
function B:cap(x,y)
  print(x+y)
end
function B:init(x,y)
  A.init(self,x)
  self.y = y
  return self
end

print(B:init(10,20))
function A:__add(b)
  return A(self.x + b.x)
end
