-- Simple Graph Editor in LÖVE2D

local nodes = {}
local edges = {}
local dragging = nil
local selected = nil
local menu = nil
local pendingEdge = nil -- First node when adding an edge
local nextId = 1
local lastClickTime = 0
local clickX, clickY = 0, 0

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function dist(x1,y1,x2,y2)
  return ((x2-x1)^2 + (y2-y1)^2)^0.5
end

local function deleteNode(node)
  for i=#nodes,1,-1 do
    if nodes[i] == node then table.remove(nodes,i) end
  end
  for i=#edges,1,-1 do
    if edges[i].from == node or edges[i].to == node then
      table.remove(edges,i)
    end
  end
end

-------------------------------------------------------------------------------
-- LÖVE callbacks
-------------------------------------------------------------------------------

function love.load()
  love.window.setTitle("Graph Editor")
  love.window.setMode(1200,800)
end

function love.draw()
  love.graphics.clear(0.1, 0.1, 0.1)

  -- draw edges
  for _, e in ipairs(edges) do
    love.graphics.setColor(1,1,1)
    love.graphics.line(e.from.x, e.from.y, e.to.x, e.to.y)
  end

  -- edge preview (if first node selected)
  if pendingEdge then
    local mx,my = love.mouse.getPosition()
    love.graphics.setColor(1,1,1)
    love.graphics.line(pendingEdge.x, pendingEdge.y, mx, my)
  end

  -- draw nodes
  for _, n in ipairs(nodes) do
    if n == selected then
      love.graphics.setColor(0.3,0.6,1)
    else
      love.graphics.setColor(0.8,0.8,0.8)
    end
    love.graphics.circle("fill", n.x, n.y, 20)
    love.graphics.setColor(0,0,0)
    love.graphics.circle("line", n.x, n.y, 20)
    love.graphics.printf(n.id, n.x-20, n.y-8, 40, "center")
  end

  -- right-click menu
  if menu then
    love.graphics.setColor(0.9,0.9,0.9)
    love.graphics.rectangle("fill", menu.x, menu.y, 120, 90)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("line", menu.x, menu.y, 120, 90)
    local items = {"Add Edge","Delete Node","Cancel"}
    for i,item in ipairs(items) do
      love.graphics.print(item, menu.x+10, menu.y+10+(i-1)*20)
    end
  end

  love.graphics.setColor(1,1,1)
  love.graphics.print("Double-click empty = new node | Right-click node = menu | Add Edge = pick 2 nodes",10,10)
end

function love.mousepressed(x,y,button)
  -- If left-click during edge creation, complete edge
  if button == 1 and pendingEdge then
    for _,n in ipairs(nodes) do
      if dist(x,y,n.x,n.y) < 20 and n ~= pendingEdge then
        table.insert(edges, {from = pendingEdge, to = n})
        pendingEdge = nil
        return
      end
    end
    pendingEdge = nil
    return
  end

  if button == 1 then
    -- *** FIXED ***
    -- Only run click/drag logic if the menu is NOT open
    if not menu then
      -- Check for double-click empty → add node
      local now = love.timer.getTime()
      if now - lastClickTime < 0.3 and dist(x,y,clickX,clickY) < 10 then
        local onNode = false
        for _,n in ipairs(nodes) do
          if dist(x,y,n.x,n.y) < 20 then
            onNode = true
            break
          end
        end
        if not onNode then
          table.insert(nodes, {id = tostring(nextId), x = x, y = y})
          nextId = nextId + 1
          lastClickTime = 0
          return
        end
      end
      lastClickTime, clickX, clickY = now, x, y

      -- Check for clicking existing node → select & drag
      for _,n in ipairs(nodes) do
        if dist(x,y,n.x,n.y) < 20 then
          selected = n
          dragging = n
          return
        end
      end
      selected = nil
    end
    -- If the menu IS open, this function does nothing on a left-press,
    -- allowing love.mousereleased to handle the menu selection.
  end

  if button == 2 then
    -- Right-click → open node menu if on node
    for _,n in ipairs(nodes) do
      if dist(x,y,n.x,n.y) < 20 then
        menu = {node = n, x = x, y = y}
        return
      end
    end
    menu = nil
  end
end

function love.mousereleased(x,y,button)
  if dragging then dragging = nil end

  if button == 1 and menu then
    local choice = math.floor((y - menu.y - 10) / 20)
    if x>=menu.x and x<=menu.x+120 and choice>=0 and choice<3 then
      local node = menu.node
      if choice == 0 then
        pendingEdge = node
      elseif choice == 1 then
        deleteNode(node)
      end
    end
    menu = nil
  end
end

function love.mousemoved(x,y)
  if dragging then
    dragging.x, dragging.y = x, y
  end
end

function love.update(dt)
end
