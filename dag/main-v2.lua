#!/usr/bin/env lua
-- Graph Editor in "Timm-style" Lua

local g,m,t,w = love.graphics,love.mouse,love.timer,love.window

local the = {
  radius = 20,    -- node radius
  menuW  = 120,   -- context menu width
  menuH  = 90,    -- context menu height
  dclick = 0.3,   -- double-click time window
  drad   = 10     -- double-click distance window
}

-- module state
local nodes,edges = {},{}
local drag,sel,menu,pend = nil,nil,nil,nil
local nid = 1
local ltime,cx,cy = 0,0,0

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local l = {}
function l.dist(x1,y1,x2,y2) return ((x2-x1)^2+(y2-y1)^2)^0.5 end

function l.delNode(node)
  for i=#nodes,1,-1 do
    if nodes[i] == node then table.remove(nodes,i) end end
  for i=#edges,1,-1 do
    if edges[i].from == node or edges[i].to == node then
      table.remove(edges,i) end end end

-------------------------------------------------------------------------------
-- LÖVE callbacks
-------------------------------------------------------------------------------

function love.load()
  w.setTitle("Graph Editor")
  w.setMode(1200,800) end

function love.draw()
  g.clear(0.1, 0.1, 0.1)

  for _, e in ipairs(edges) do
    g.setColor(1,1,1); g.line(e.from.x, e.from.y, e.to.x, e.to.y) end

  if pend then
    local mx,my = m.getPosition()
    g.setColor(1,1,1); g.line(pend.x, pend.y, mx, my) end

  for _, n in ipairs(nodes) do
    if n == sel then g.setColor(0.3,0.6,1) else g.setColor(0.8,0.8,0.8) end
    g.circle("fill", n.x, n.y, the.radius)
    g.setColor(0,0,0)
    g.circle("line", n.x, n.y, the.radius)
    g.printf(n.id, n.x-the.radius, n.y-8, the.radius*2, "center") end

  if menu then
    g.setColor(0.9,0.9,0.9)
    g.rectangle("fill", menu.x, menu.y, the.menuW, the.menuH)
    g.setColor(0,0,0)
    g.rectangle("line", menu.x, menu.y, the.menuW, the.menuH)
    local items = {"Add Edge","Delete Node","Cancel"}
    for i,item in ipairs(items) do
      g.print(item, menu.x+10, menu.y+10+(i-1)*20) end end

  g.setColor(1,1,1)
  g.print("Double-click empty = new node | Right-click node = menu",10,10) end

function love.mousepressed(x,y,button)
  if button == 1 and pend then
    for _,n in ipairs(nodes) do
      if l.dist(x,y,n.x,n.y)<the.radius and n~=pend then
        table.insert(edges, {from = pend, to = n}); pend = nil; return end end
    pend = nil; return end

  if button == 1 then
    if not menu then
      local now = t.getTime()
      if now - ltime < the.dclick and l.dist(x,y,cx,cy) < the.drad then
        local onNode = false
        for _,n in ipairs(nodes) do
          if l.dist(x,y,n.x,n.y) < the.radius then onNode=true; break end end
        if not onNode then
          table.insert(nodes, {id = tostring(nid), x = x, y = y})
          nid = nid + 1; ltime = 0; return end
      end
      ltime, cx, cy = now, x, y
      for _,n in ipairs(nodes) do
        if l.dist(x,y,n.x,n.y) < the.radius then
          sel = n; drag = n; return end end
      sel = nil end
  end

  if button == 2 then
    for _,n in ipairs(nodes) do
      if l.dist(x,y,n.x,n.y) < the.radius then
        menu = {node = n, x = x, y = y}; return end end
    menu = nil end
end

function love.mousereleased(x,y,button)
  if drag then drag = nil end
  if button == 1 and menu then
    local choice = math.floor((y - menu.y - 10) / 20)
    if x>=menu.x and x<=menu.x+the.menuW and choice>=0 and choice<3 then
      local node = menu.node
      if choice == 0 then pend = node
      elseif choice == 1 then l.delNode(node) end end
    menu = nil end end

function love.mousemoved(x,y) if drag then drag.x,drag.y = x,y end end

function love.update(dt) end
