#!/usr/bin/env lua
-- Graph Editor in "Timm-style" Lua (Final Refactor)

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
  for i=#nodes,1,-1 do if nodes[i]==node then table.remove(nodes,i) end end
  for i=#edges,1,-1 do
    if edges[i].from==node or edges[i].to==node then table.remove(edges,i) end
  end end

-- Drawing Helpers
function l.draw_edges(g, edges)
  for _, e in ipairs(edges) do
    g.setColor(1,1,1); g.line(e.from.x, e.from.y, e.to.x, e.to.y) end end

function l.draw_preview(g, m, pend)
  if not pend then return end
  local mx,my = m.getPosition()
  g.setColor(1,1,1); g.line(pend.x, pend.y, mx, my) end

function l.draw_nodes(g, nodes, sel, rad)
  for _, n in ipairs(nodes) do
    if n == sel then g.setColor(0.3,0.6,1) else g.setColor(0.8,0.8,0.8) end
    g.circle("fill", n.x, n.y, rad)
    g.setColor(0,0,0)
    g.circle("line", n.x, n.y, rad)
    g.printf(n.id, n.x-rad, n.y-8, rad*2, "center") end end

function l.draw_menu(g, menu, w, h)
  if not menu then return end
  g.setColor(0.9,0.9,0.9); g.rectangle("fill", menu.x, menu.y, w, h)
  g.setColor(0,0,0); g.rectangle("line", menu.x, menu.y, w, h)
  local items = {"Add Edge","Delete Node","Cancel"}
  for i,item in ipairs(items) do
    g.print(item, menu.x+10, menu.y+10+(i-1)*20) end end

function l.draw_help(g)
  g.setColor(1,1,1)
  g.print("Double-click empty = new node | Right-click node = menu",10,10) end

-- MousePress Helpers
function l.press_pend(l, nodes, edges, pend, rad, x, y)
  for _,n in ipairs(nodes) do
    if l.dist(x,y,n.x,n.y)<rad and n~=pend then
      table.insert(edges, {from = pend, to = n}); return nil end end
  return nil end

function l.press_add(l, t, nodes, nid, ltime, cx, cy, c, x, y)
  local now = t.getTime()
  if now-ltime < c.dclick and l.dist(x,y,cx,cy) < c.drad then
    local onNode = false
    for _,n in ipairs(nodes) do
      if l.dist(x,y,n.x,n.y) < c.radius then onNode=true; break end end
    if not onNode then
      table.insert(nodes, {id = tostring(nid), x = x, y = y})
      return nid + 1, 0, cx, cy, true end end
  return nid, now, x, y, false end

function l.press_drag(l, nodes, sel, drag, rad, x, y)
  for _,n in ipairs(nodes) do
    if l.dist(x,y,n.x,n.y) < rad then return n, n end end
  return nil, nil end

function l.press_menu(l, nodes, menu, rad, x, y)
  for _,n in ipairs(nodes) do
    if l.dist(x,y,n.x,n.y) < rad then
      return {node = n, x = x, y = y} end end
  return nil end

function l.press_b1(x, y)
  if menu then return nid, ltime, cx, cy, sel, drag end
  local added
  local new_nid, new_ltime, new_cx, new_cy
  new_nid, new_ltime, new_cx, new_cy, added = l.press_add(l, t, nodes, nid,
                                            ltime, cx, cy, the, x, y)
  if added then return new_nid, new_ltime, new_cx, new_cy, sel, drag end
  local new_sel, new_drag = l.press_drag(l, nodes, sel, drag, the.radius, x, y)
  return new_nid, new_ltime, new_cx, new_cy, new_sel, new_drag end

function l.press_b2(x, y)
  return l.press_menu(l, nodes, menu, the.radius, x, y) end

-------------------------------------------------------------------------------
-- LÖVE callbacks
-------------------------------------------------------------------------------

function love.load()
  w.setTitle("Graph Editor"); w.setMode(1200,800) end

function love.draw()
  g.clear(0.1, 0.1, 0.1)
  l.draw_edges(g, edges)
  l.draw_preview(g, m, pend)
  l.draw_nodes(g, nodes, sel, the.radius)
  l.draw_menu(g, menu, the.menuW, the.menuH)
  l.draw_help(g) end

function love.mousepressed(x,y,button)
  if button == 1 and pend then
    pend = l.press_pend(l, nodes, edges, pend, the.radius, x, y); return
  elseif button == 1 then
    nid, ltime, cx, cy, sel, drag = l.press_b1(x, y)
  elseif button == 2 then
    menu = l.press_b2(x, y) end end

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
