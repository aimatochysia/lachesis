-- Lachesis Tria: the library browser.
--
-- A small window that stays open beside the canvas, like an asset browser.
-- Pick a group and an entry, click a tile, and it becomes the brush: a ghost
-- of it follows the cursor and each click stamps its pixels on the current
-- layer.
--
-- The window is kept compact so you can draw while it is open: the tile grid
-- fills whatever size you give the window, the buttons are a row of small
-- pixel icons, and nothing in it changes size after it opens (changing a
-- label's text would make Aseprite grow the window back to its full size).

local Browser = {}

local Config, Library, Capture, Stamp, UI

local TITLE = "Tile Library"
local GAP = 4
local ICON_SCALE = 2          -- icon pixels are drawn 2x2
local ICON_SIZE = 7 * ICON_SCALE
local ICON_PAD = 4
local BAR_TEXT_H = 14

local dlg = nil
local cache = {}  -- "group/name" -> loaded entry (with RGB previews)

local view = {
  group = nil,
  entry = nil,     -- entry name
  data = nil,      -- loaded entry
  page = 1,
  selected = nil,  -- tile index in the entry
  cols = 1,        -- grid size from the last paint, for clicks and paging
  rows = 1,
  hover = nil,     -- toolbar button under the mouse
}

function Browser.init(config, library, capture, stamp, ui)
  Config, Library, Capture, Stamp, UI = config, library, capture, stamp, ui
end

local function key(group, name) return group .. "/" .. name end

local function load(group, name)
  local k = key(group, name)
  if cache[k] then return cache[k] end
  local data, err = Library.loadEntry(group, name)
  if not data then return nil, err end
  data.previews = {}
  for i, t in ipairs(data.tiles) do
    data.previews[i] = Capture.toRGB(t, data.palette, data.transparentColor)
  end
  cache[k] = data
  return data
end

local function perPage() return view.cols * view.rows end

local function pages()
  if not view.data then return 1 end
  return math.max(1, (#view.data.tiles + perPage() - 1) // perPage())
end

local function cellSize()
  if not view.data then return UI.cellSize(16, 16) end
  return UI.cellSize(view.data.width, view.data.height)
end

local function emptyText()
  if not view.group then return "Library is empty. Use Capture Tiles From Canvas first." end
  if not view.entry then return "This group has no entries yet." end
  if not view.data then return "Couldn't load this entry." end
  return nil
end

-- Keep the window the size the user gave it while Aseprite re-lays it out.
local function keepBounds(fn)
  local ok, b = pcall(function() return dlg.bounds end)
  fn()
  if ok and b then pcall(function() dlg.bounds = b end) end
end

local function repaint()
  if dlg then dlg:repaint() end
end

-- Called by the rotate and mirror commands so the status line stays current.
function Browser.refreshStamp()
  repaint()
end

local function selectEntry(name)
  view.entry = name
  view.data = nil
  view.page = 1
  view.selected = nil
  if view.group and name then
    local data, err = load(view.group, name)
    view.data = data
    if not data then app.alert{ title = TITLE, text = err or "Couldn't load this entry." } end
  end
end

local function selectGroup(group)
  view.group = group
  local entries = group and Library.entries(group) or {}
  selectEntry(entries[1])
  return entries
end

local function entryOptions(entries)
  if #entries == 0 then return { "(empty)" } end
  return entries
end

local function turnPage(delta)
  local p = math.max(1, math.min(pages(), view.page + delta))
  if p ~= view.page then
    view.page = p
    repaint()
  end
end

local function tileAt(mx, my)
  if not view.data then return nil end
  local cw, ch = cellSize()
  local c = (mx - GAP) // (cw + GAP)
  local r = (my - GAP) // (ch + GAP)
  if c < 0 or c >= view.cols or r < 0 or r >= view.rows then return nil end
  if (mx - GAP) % (cw + GAP) >= cw or (my - GAP) % (ch + GAP) >= ch then return nil end
  local i = (view.page - 1) * perPage() + r * view.cols + c + 1
  if i > #view.data.tiles then return nil end
  return i
end

local function pickTile(i)
  view.selected = i
  local label = string.format("%s / %s #%d", view.group, view.entry, i)
  if not Stamp.pick(view.data.tiles[i], view.data, label) then
    app.alert{ title = TITLE, text = "Open or create a sprite to stamp on, then click the tile again." }
  end
  repaint()
end

-- Tile grid -----------------------------------------------------------------

local function paintTiles(ev)
  local gc = ev.context
  local cw, ch = cellSize()
  view.cols = math.max(1, (gc.width - GAP) // (cw + GAP))
  view.rows = math.max(1, (gc.height - GAP) // (ch + GAP))
  if view.page > pages() then view.page = pages() end

  local msg = emptyText()
  if msg then
    gc.color = app.theme and app.theme.color.text or Color{ r = 0, g = 0, b = 0 }
    gc:fillText(msg, GAP, GAP)
    return
  end

  local first = (view.page - 1) * perPage() + 1
  local last = math.min(#view.data.tiles, view.page * perPage())
  for i = first, last do
    local k = i - first
    local x = GAP + (k % view.cols) * (cw + GAP)
    local y = GAP + (k // view.cols) * (ch + GAP)
    UI.drawChecker(gc, x, y, cw, ch)
    gc:drawImage(view.data.previews[i],
                 Rectangle(0, 0, view.data.width, view.data.height),
                 Rectangle(x, y, cw, ch))
    if i == view.selected then
      gc.color = Color{ r = 60, g = 140, b = 255 }
      gc:strokeRect(Rectangle(x - 2, y - 2, cw + 4, ch + 4))
      gc:strokeRect(Rectangle(x - 1, y - 1, cw + 2, ch + 2))
    end
  end
end

-- Toolbar ---------------------------------------------------------------------

-- 7x7 pixel icons, '#' = pixel.
local ICONS = {
  prev = { "....#..", "...##..", "..###..", ".####..", "..###..", "...##..", "....#.." },
  next = { "..#....", "..##...", "..###..", "..####.", "..###..", "..##...", "..#...." },
  rotL = { "..####.", ".#....#", "#.....#", "###...#", ".#....#", "......#", "..####." },
  rotR = { ".####..", "#....#.", "#.....#", "#...###", "#....#.", "#......", ".####.." },
  mirH = { "...#...", "#..#..#", "##.#.##", "###.###", "##.#.##", "#..#..#", "...#..." },
  mirV = { "#######", ".#####.", "..###..", "#######", "..###..", ".#####.", "#######" },
  reset = { ".#####.", "#.....#", "#.###.#", "#.###.#", "#.###.#", "#.....#", ".#####." },
  edit = { ".....##", "....###", "...###.", "..###..", ".###...", "##.....", "#......" },
  refresh = { "..###.#", ".#...##", "#...###", "#.....#", "###...#", "##...#.", "#.###.." },
}

local BUTTONS -- filled in build(), needs the dialog

local function buttonRect(i)
  local step = ICON_SIZE + ICON_PAD * 2
  return Rectangle((i - 1) * step, 0, step, ICON_SIZE + ICON_PAD * 2)
end

local function buttonAt(mx, my)
  for i, b in ipairs(BUTTONS) do
    local r = buttonRect(i)
    if mx >= r.x and mx < r.x + r.width and my >= r.y and my < r.y + r.height then
      return i, b
    end
  end
  return nil
end

local function isEnabled(b)
  return b.enabled == nil or b.enabled()
end

local function fitText(gc, text, width)
  local ok, size = pcall(function() return gc:measureText(text) end)
  if not ok or not size or size.width <= width then return text end
  while #text > 1 do
    text = text:sub(1, -2)
    if gc:measureText(text .. "..").width <= width then return text .. ".." end
  end
  return text
end

local function statusText()
  if view.hover and BUTTONS[view.hover] then return BUTTONS[view.hover].tip end
  local parts = {}
  if view.data then
    parts[#parts + 1] = string.format("%d tiles, %dx%d, page %d/%d",
      #view.data.tiles, view.data.width, view.data.height, view.page, pages())
  end
  parts[#parts + 1] = Stamp.describe()
  return table.concat(parts, " | ")
end

local function paintBar(ev)
  local gc = ev.context
  local textColor = (app.theme and app.theme.color.text) or Color{ r = 0, g = 0, b = 0 }
  local dim = Color{ r = textColor.red, g = textColor.green, b = textColor.blue, a = 80 }
  for i, b in ipairs(BUTTONS) do
    local r = buttonRect(i)
    if i == view.hover and isEnabled(b) then
      gc.color = Color{ r = 60, g = 140, b = 255, a = 70 }
      gc:fillRect(r)
    end
    gc.color = isEnabled(b) and textColor or dim
    local icon = ICONS[b.icon]
    for y, row in ipairs(icon) do
      for x = 1, #row do
        if row:sub(x, x) == "#" then
          gc:fillRect(Rectangle(r.x + ICON_PAD + (x - 1) * ICON_SCALE,
                                r.y + ICON_PAD + (y - 1) * ICON_SCALE,
                                ICON_SCALE, ICON_SCALE))
        end
      end
    end
  end
  gc.color = textColor
  local y = ICON_SIZE + ICON_PAD * 2 + 1
  gc:fillText(fitText(gc, statusText(), gc.width - 4), 2, y)
end

-- Window ------------------------------------------------------------------------

local function saveBounds()
  pcall(function()
    local b = dlg.bounds
    Config.set("browserBounds", string.format("%d,%d,%d,%d", b.x, b.y, b.width, b.height))
  end)
end

local function savedBounds()
  local s = Config.get("browserBounds")
  if type(s) ~= "string" then return nil end
  local x, y, w, h = s:match("^(-?%d+),(-?%d+),(%d+),(%d+)$")
  if not x then return nil end
  w, h = tonumber(w), tonumber(h)
  if w < 120 or h < 120 then return nil end
  return Rectangle(tonumber(x), tonumber(y), w, h)
end

local function build()
  local groups = Library.groups()
  local remembered = Config.get("lastGroup")
  local startGroup = (remembered ~= "" and Library.findGroup(remembered)) or groups[1]
  local entries = selectGroup(startGroup)

  BUTTONS = {
    { icon = "prev", tip = "Previous page (or scroll the tiles)",
      enabled = function() return view.page > 1 end,
      run = function() turnPage(-1) end },
    { icon = "next", tip = "Next page (or scroll the tiles)",
      enabled = function() return view.page < pages() end,
      run = function() turnPage(1) end },
    { icon = "rotL", tip = "Rotate stamp left",
      enabled = Stamp.hasTile, run = function() Stamp.rotate(-1) end },
    { icon = "rotR", tip = "Rotate stamp right",
      enabled = Stamp.hasTile, run = function() Stamp.rotate(1) end },
    { icon = "mirH", tip = "Mirror stamp horizontally",
      enabled = Stamp.hasTile, run = function() Stamp.mirror(true) end },
    { icon = "mirV", tip = "Mirror stamp vertically",
      enabled = Stamp.hasTile, run = function() Stamp.mirror(false) end },
    { icon = "reset", tip = "Reset rotation and mirroring",
      enabled = Stamp.hasTile, run = function() Stamp.reset() end },
    { icon = "edit", tip = "Edit entry (opens its file)",
      enabled = function() return view.group ~= nil and view.entry ~= nil end,
      run = function() app.open(Library.entryPath(view.group, view.entry)) end },
    { icon = "refresh", tip = "Reload the library from disk",
      run = function()
        cache = {}
        local list = Library.groups()
        local g = view.group and Library.findGroup(view.group) or list[1]
        local es = selectGroup(g)
        keepBounds(function()
          dlg:modify{ id = "group", options = (#list > 0) and list or { "(empty)" }, option = g or "(empty)" }
          dlg:modify{ id = "entry", options = entryOptions(es), option = es[1] or "(empty)" }
        end)
      end },
  }

  -- Small by default: about 3 x 2 tiles. Resize the window for more.
  local maxCell = UI.MAX_CELL
  local canvasW = 3 * (maxCell + GAP) + GAP
  local canvasH = 2 * (maxCell + GAP) + GAP

  dlg = Dialog{
    title = TITLE,
    onclose = function()
      saveBounds()
      dlg = nil
    end,
  }
  dlg:combobox{
    id = "group",
    option = startGroup or "(empty)",
    options = (#groups > 0) and groups or { "(empty)" },
    onchange = function()
      local g = dlg.data.group
      if g == "(empty)" then return end
      local list = selectGroup(g)
      Config.set("lastGroup", g)
      keepBounds(function()
        dlg:modify{ id = "entry", options = entryOptions(list), option = list[1] or "(empty)" }
      end)
      repaint()
    end,
  }
  dlg:combobox{
    id = "entry",
    option = entries[1] or "(empty)",
    options = entryOptions(entries),
    onchange = function()
      local e = dlg.data.entry
      if e == "(empty)" then return end
      selectEntry(e)
      repaint()
    end,
  }
  dlg:newrow()
  dlg:canvas{
    id = "tiles",
    width = canvasW,
    height = canvasH,
    onpaint = paintTiles,
    onmousedown = function(ev)
      local i = tileAt(ev.x, ev.y)
      if i then pickTile(i) end
    end,
    onmousemove = function()
      if view.hover then
        view.hover = nil
        repaint()
      end
    end,
    onwheel = function(ev)
      local d = ev.deltaY or 0
      if d > 0 then turnPage(1) elseif d < 0 then turnPage(-1) end
    end,
  }
  dlg:newrow()
  dlg:canvas{
    id = "bar",
    width = #BUTTONS * (ICON_SIZE + ICON_PAD * 2),
    height = ICON_SIZE + ICON_PAD * 2 + BAR_TEXT_H,
    onpaint = paintBar,
    onmousemove = function(ev)
      local i = buttonAt(ev.x, ev.y)
      if i ~= view.hover then
        view.hover = i
        repaint()
      end
    end,
    onmouseup = function(ev)
      local i, b = buttonAt(ev.x, ev.y)
      if b and isEnabled(b) then
        b.run()
        repaint()
      end
    end,
  }

  local bounds = savedBounds()
  if bounds then
    dlg:show{ wait = false, bounds = bounds }
  else
    dlg:show{ wait = false }
  end
end

function Browser.open()
  if dlg then dlg:close(); dlg = nil end
  cache = {}
  build()
end

-- Forget loaded entries (after a capture adds or replaces one).
function Browser.invalidate()
  cache = {}
end

return Browser
