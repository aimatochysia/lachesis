-- Lachesis Tria: the "Capture Tiles From Canvas" flow.
--
-- 1. Ask for the grid (x, y, tile width, tile height).
-- 2. Flatten the visible layers of the current frame and slice them.
-- 3. Show the tiles; the user unticks the ones to leave out.
-- 4. Save the ticked tiles as an entry in a group.

local Capturer = {}

local Config, Library, Capture

local TITLE = "Tile Library"
local NEW_GROUP = "(new group)"
local DEFAULT_GROUP = "General"

-- Preview layout.
local COLUMNS = 8
local ROWS_PER_PAGE = 5
local GAP = 4
local MAX_CELL = 64

function Capturer.init(config, library, capture)
  Config, Library, Capture = config, library, capture
end

local function alert(text)
  app.alert{ title = TITLE, text = text }
end

-- Starting grid: the one used last time for this file, else the sprite's
-- grid settings, else the last grid used anywhere, else 16x16 at (0, 0).
local function initialGrid(sprite)
  local g = Config.gridFor(sprite.filename)
  if g then return g end
  local ok, gb = pcall(function() return sprite.gridBounds end)
  if ok and gb and gb.width > 1 and gb.height > 1 then
    return {
      x = gb.x % gb.width, y = gb.y % gb.height,
      w = gb.width, h = gb.height,
    }
  end
  return Config.decodeGrid(Config.get("lastGrid")) or { x = 0, y = 0, w = 16, h = 16 }
end

local function readGrid(data)
  local function int(v) return math.floor((tonumber(v) or 0) + 0.5) end
  return { x = int(data.x), y = int(data.y), w = int(data.w), h = int(data.h) }
end

local function gridSummary(sprite, grid)
  local ok, why = Capture.validateGrid(sprite.width, sprite.height, grid)
  if not ok then return why end
  local cols, rows = Capture.gridSize(sprite.width, sprite.height, grid)
  return string.format("%d x %d = %d cells", cols, rows, cols * rows)
end

-- Returns the grid, or nil if cancelled.
local function askGrid(sprite)
  local grid = initialGrid(sprite)
  while true do
    local dlg = Dialog{ title = "Capture Tiles From Canvas" }
    local function refresh()
      dlg:modify{ id = "summary", text = gridSummary(sprite, readGrid(dlg.data)) }
    end
    dlg:label{
      text = string.format("Canvas %dx%d, frame %d, visible layers only.",
                           sprite.width, sprite.height, app.frame.frameNumber),
    }
    dlg:separator{ text = "Where the first tile starts" }
    dlg:number{ id = "x", label = "x:", text = tostring(grid.x), decimals = 0, onchange = refresh }
    dlg:number{ id = "y", label = "y:", text = tostring(grid.y), decimals = 0, onchange = refresh }
    dlg:separator{ text = "Tile size (pixels)" }
    dlg:number{ id = "w", label = "Width:", text = tostring(grid.w), decimals = 0, onchange = refresh }
    dlg:number{ id = "h", label = "Height:", text = tostring(grid.h), decimals = 0, onchange = refresh }
    dlg:label{ id = "summary", text = gridSummary(sprite, grid) }
    dlg:separator()
    dlg:button{ id = "ok", text = "&Next", focus = true }
    dlg:button{ id = "cancel", text = "&Cancel" }
    dlg:show()

    local data = dlg.data
    if not data.ok then return nil end
    grid = readGrid(data)
    local ok, why = Capture.validateGrid(sprite.width, sprite.height, grid)
    if ok then return grid end
    alert(why)
  end
end

-- Size of one preview cell on screen, keeping pixels square.
local function cellSize(w, h)
  local zoom = math.max(1, math.min(4, 40 // math.max(w, h)))
  local cw, ch = w * zoom, h * zoom
  local biggest = math.max(cw, ch)
  if biggest > MAX_CELL then
    cw = math.max(1, cw * MAX_CELL // biggest)
    ch = math.max(1, ch * MAX_CELL // biggest)
  end
  return cw, ch
end

local function drawChecker(gc, x, y, w, h)
  gc.color = Color{ r = 204, g = 204, b = 204 }
  gc:fillRect(Rectangle(x, y, w, h))
  gc.color = Color{ r = 153, g = 153, b = 153 }
  local s = 8
  for cy = 0, h - 1, s do
    for cx = 0, w - 1, s do
      if ((cx // s) + (cy // s)) % 2 == 1 then
        gc:fillRect(Rectangle(x + cx, y + cy, math.min(s, w - cx), math.min(s, h - cy)))
      end
    end
  end
end

-- Show the tiles and let the user pick which to keep and where to save.
-- Returns { picked = {tiles}, group, name } or nil if cancelled.
local function pickAndName(sprite, tiles, stats, grid)
  local w, h = grid.w, grid.h
  local cw, ch = cellSize(w, h)
  local perPage = COLUMNS * ROWS_PER_PAGE
  local pages = math.max(1, (#tiles + perPage - 1) // perPage)
  local page = 1
  local ticked = {}
  for i = 1, #tiles do ticked[i] = true end

  -- RGB copies so indexed and grayscale tiles draw with the right colors.
  local palette = sprite.palettes[1]
  local tIndex = Capture.transparentIndex(sprite)
  local shown = {}
  for i, t in ipairs(tiles) do shown[i] = Capture.toRGB(t.image, palette, tIndex) end

  local canvasW = COLUMNS * (cw + GAP) + GAP
  local canvasH = math.min(ROWS_PER_PAGE, (#tiles + COLUMNS - 1) // COLUMNS) * (ch + GAP) + GAP

  local groups = Library.groups()
  local options = {}
  for _, g in ipairs(groups) do options[#options + 1] = g end
  options[#options + 1] = NEW_GROUP
  local lastGroup = Config.get("lastGroup")
  local selectedGroup = (lastGroup ~= "" and Library.findGroup(lastGroup)) or groups[1] or NEW_GROUP

  local dlg = Dialog{ title = "Capture Tiles From Canvas" }

  local function countTicked()
    local n = 0
    for i = 1, #tiles do if ticked[i] then n = n + 1 end end
    return n
  end

  local function summary()
    local parts = { string.format("%d of %d tiles ticked", countTicked(), #tiles) }
    if stats.empty > 0 then parts[#parts + 1] = stats.empty .. " empty skipped" end
    if stats.duplicate > 0 then parts[#parts + 1] = stats.duplicate .. " duplicates skipped" end
    return table.concat(parts, ", ")
  end

  local function refresh()
    dlg:modify{ id = "summary", text = summary() }
    dlg:modify{ id = "page", text = string.format("Page %d of %d", page, pages) }
    dlg:modify{ id = "prev", enabled = page > 1 }
    dlg:modify{ id = "next", enabled = page < pages }
    dlg:repaint()
  end

  local function tileAt(mx, my)
    local c = (mx - GAP) // (cw + GAP)
    local r = (my - GAP) // (ch + GAP)
    if c < 0 or c >= COLUMNS or r < 0 or r >= ROWS_PER_PAGE then return nil end
    local inX = (mx - GAP) % (cw + GAP) < cw
    local inY = (my - GAP) % (ch + GAP) < ch
    if not (inX and inY) then return nil end
    local i = (page - 1) * perPage + r * COLUMNS + c + 1
    if i > #tiles then return nil end
    return i
  end

  dlg:label{ id = "summary", text = summary() }
  dlg:label{ text = "Click a tile to leave it out or put it back." }
  dlg:canvas{
    id = "tiles",
    width = canvasW,
    height = canvasH,
    onpaint = function(ev)
      local gc = ev.context
      local first = (page - 1) * perPage + 1
      local last = math.min(#tiles, page * perPage)
      for i = first, last do
        local k = i - first
        local x = GAP + (k % COLUMNS) * (cw + GAP)
        local y = GAP + (k // COLUMNS) * (ch + GAP)
        drawChecker(gc, x, y, cw, ch)
        gc:drawImage(shown[i], Rectangle(0, 0, w, h), Rectangle(x, y, cw, ch))
        if ticked[i] then
          gc.color = Color{ r = 60, g = 140, b = 255 }
          gc:strokeRect(Rectangle(x - 2, y - 2, cw + 4, ch + 4))
        else
          gc.opacity = 170
          gc.color = Color{ r = 0, g = 0, b = 0 }
          gc:fillRect(Rectangle(x, y, cw, ch))
          gc.opacity = 255
          gc.color = Color{ r = 230, g = 80, b = 80 }
          gc:beginPath()
          gc:moveTo(x + 3, y + 3)
          gc:lineTo(x + cw - 3, y + ch - 3)
          gc:moveTo(x + cw - 3, y + 3)
          gc:lineTo(x + 3, y + ch - 3)
          gc:stroke()
        end
      end
    end,
    onmousedown = function(ev)
      local i = tileAt(ev.x, ev.y)
      if i then
        ticked[i] = not ticked[i]
        refresh()
      end
    end,
  }
  dlg:button{ id = "prev", text = "< Prev", enabled = false,
    onclick = function() page = math.max(1, page - 1); refresh() end }
  dlg:label{ id = "page", text = string.format("Page %d of %d", page, pages) }
  dlg:button{ id = "next", text = "Next >", enabled = pages > 1,
    onclick = function() page = math.min(pages, page + 1); refresh() end }
  dlg:newrow()
  dlg:button{ text = "Tick &All",
    onclick = function() for i = 1, #tiles do ticked[i] = true end; refresh() end }
  dlg:button{ text = "Tick &None",
    onclick = function() for i = 1, #tiles do ticked[i] = false end; refresh() end }

  dlg:separator{ text = "Save to library" }
  dlg:combobox{
    id = "group", label = "Group:", option = selectedGroup, options = options,
    onchange = function()
      dlg:modify{ id = "newGroup", visible = dlg.data.group == NEW_GROUP }
    end,
  }
  dlg:entry{
    id = "newGroup", label = "New group:",
    text = (#groups == 0) and DEFAULT_GROUP or "",
    visible = selectedGroup == NEW_GROUP,
  }
  dlg:entry{ id = "name", label = "Name:", text = app.fs.fileTitle(sprite.filename) }
  dlg:separator()
  dlg:button{ id = "ok", text = "&Save", focus = true }
  dlg:button{ id = "cancel", text = "&Cancel" }

  while true do
    dlg:show()
    local data = dlg.data
    if not data.ok then return nil end

    local picked = {}
    for i, t in ipairs(tiles) do
      if ticked[i] then picked[#picked + 1] = t end
    end

    local rawGroup = data.group
    if rawGroup == NEW_GROUP then rawGroup = data.newGroup end
    local group = Library.sanitize(rawGroup)
    local name = Library.sanitize(data.name)

    if #picked == 0 then
      alert("Tick at least one tile to save.")
    elseif not group then
      alert("Type a name for the new group.")
    elseif not name then
      alert("Type a name for this entry.")
    else
      -- Reuse an existing group whose name differs only in case.
      group = Library.findGroup(group) or group
      return { picked = picked, group = group, name = name }
    end
  end
end

-- Asks what to do when the name is taken. Returns the name to use, or nil.
local function resolveName(group, name)
  local existing = Library.findEntry(group, name)
  if not existing then return name end
  local choice = app.alert{
    title = TITLE,
    text = string.format("\"%s\" already exists in %s.", existing, group),
    buttons = { "&Replace", "&Keep Both", "&Cancel" },
  }
  if choice == 1 then return existing end
  if choice == 2 then return Library.freeName(group, name) end
  return nil
end

function Capturer.run()
  local sprite = app.sprite
  if not sprite then
    alert("Open a sprite first, then capture tiles from its canvas.")
    return
  end

  local grid = askGrid(sprite)
  if not grid then return end

  local frame = app.frame.frameNumber
  local tIndex = Capture.transparentIndex(sprite)
  local flat = Capture.flatten(sprite, frame)
  local tiles, stats = Capture.slice(flat, grid, tIndex)
  Config.rememberGrid(sprite.filename, grid)

  if #tiles == 0 then
    alert(string.format("All %d cells are empty on the visible layers of frame %d.",
                        stats.cells, frame))
    return
  end

  local choice = pickAndName(sprite, tiles, stats, grid)
  if not choice then return end

  local name = resolveName(choice.group, choice.name)
  if not name then return end

  local path, err = Library.saveEntry{
    group = choice.group,
    name = name,
    tiles = choice.picked,
    colorMode = sprite.colorMode,
    palette = sprite.colorMode == ColorMode.INDEXED and sprite.palettes[1] or nil,
    transparentColor = tIndex,
    source = { path = sprite.filename, frame = frame, grid = grid },
  }
  if not path then
    alert("Couldn't save the tiles: " .. (err or "unknown error"))
    return
  end
  Config.set("lastGroup", choice.group)
  alert(string.format("Saved %d tile(s) to %s / %s.", #choice.picked, choice.group, name))
end

return Capturer
