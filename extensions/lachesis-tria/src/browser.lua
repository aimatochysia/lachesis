-- Lachesis Tria: the library browser.
--
-- A window that stays open beside the canvas, like an asset browser. Pick a
-- group and an entry, click a tile, and it becomes the brush: a ghost of it
-- follows the cursor and each click stamps its pixels on the current layer.

local Browser = {}

local Config, Library, Capture, Stamp, UI

local TITLE = "Tile Library"
local COLUMNS = 8
local ROWS_PER_PAGE = 4
local GAP = 4

local dlg = nil
local cache = {}  -- "group/name" -> loaded entry (with RGB previews)

local view = {
  group = nil,
  entry = nil,     -- entry name
  data = nil,      -- loaded entry
  page = 1,
  selected = nil,  -- tile index in the entry
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

local function pages()
  if not view.data then return 1 end
  local per = COLUMNS * ROWS_PER_PAGE
  return math.max(1, (#view.data.tiles + per - 1) // per)
end

local function cellSize()
  if not view.data then return UI.cellSize(16, 16) end
  return UI.cellSize(view.data.width, view.data.height)
end

local function info()
  if not view.group then return "Library is empty. Use Capture Tiles From Canvas first." end
  if not view.entry then return "This group has no entries yet." end
  if not view.data then return "Couldn't load this entry." end
  return string.format("%d tile(s), %dx%d px. Click a tile to stamp it.",
                       #view.data.tiles, view.data.width, view.data.height)
end

local function refreshLabels()
  if not dlg then return end
  dlg:modify{ id = "info", text = info() }
  dlg:modify{ id = "page", text = string.format("Page %d of %d", view.page, pages()) }
  dlg:modify{ id = "prev", enabled = view.page > 1 }
  dlg:modify{ id = "next", enabled = view.page < pages() }
  dlg:modify{ id = "stamp", text = Stamp.describe() }
  dlg:repaint()
end

-- Called by the rotate and mirror commands so the label stays current.
function Browser.refreshStamp()
  if dlg then dlg:modify{ id = "stamp", text = Stamp.describe() } end
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

local function tileAt(mx, my)
  if not view.data then return nil end
  local cw, ch = cellSize()
  local c = (mx - GAP) // (cw + GAP)
  local r = (my - GAP) // (ch + GAP)
  if c < 0 or c >= COLUMNS or r < 0 or r >= ROWS_PER_PAGE then return nil end
  if (mx - GAP) % (cw + GAP) >= cw or (my - GAP) % (ch + GAP) >= ch then return nil end
  local i = (view.page - 1) * COLUMNS * ROWS_PER_PAGE + r * COLUMNS + c + 1
  if i > #view.data.tiles then return nil end
  return i
end

local function pickTile(i)
  view.selected = i
  local label = string.format("%s / %s #%d", view.group, view.entry, i)
  if not Stamp.pick(view.data.tiles[i], view.data, label) then
    app.alert{ title = TITLE, text = "Open or create a sprite to stamp on, then click the tile again." }
  end
  refreshLabels()
end

local function build()
  local groups = Library.groups()
  local remembered = Config.get("lastGroup")
  local startGroup = (remembered ~= "" and Library.findGroup(remembered)) or groups[1]
  local entries = selectGroup(startGroup)

  -- The canvas is sized for the largest tile cell the browser draws.
  local maxCell = UI.MAX_CELL
  local canvasW = COLUMNS * (maxCell + GAP) + GAP
  local canvasH = ROWS_PER_PAGE * (maxCell + GAP) + GAP

  dlg = Dialog{
    title = TITLE,
    onclose = function() dlg = nil end,
  }
  dlg:combobox{
    id = "group", label = "Group:",
    option = startGroup or "(empty)",
    options = (#groups > 0) and groups or { "(empty)" },
    onchange = function()
      local g = dlg.data.group
      if g == "(empty)" then return end
      local list = selectGroup(g)
      Config.set("lastGroup", g)
      dlg:modify{ id = "entry", options = entryOptions(list), option = list[1] or "(empty)" }
      refreshLabels()
    end,
  }
  dlg:combobox{
    id = "entry", label = "Entry:",
    option = entries[1] or "(empty)",
    options = entryOptions(entries),
    onchange = function()
      local e = dlg.data.entry
      if e == "(empty)" then return end
      selectEntry(e)
      refreshLabels()
    end,
  }
  dlg:label{ id = "info", text = info() }
  dlg:canvas{
    id = "tiles",
    width = canvasW,
    height = canvasH,
    onpaint = function(ev)
      if not view.data then return end
      local gc = ev.context
      local cw, ch = cellSize()
      local per = COLUMNS * ROWS_PER_PAGE
      local first = (view.page - 1) * per + 1
      local last = math.min(#view.data.tiles, view.page * per)
      for i = first, last do
        local k = i - first
        local x = GAP + (k % COLUMNS) * (cw + GAP)
        local y = GAP + (k // COLUMNS) * (ch + GAP)
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
    end,
    onmousedown = function(ev)
      local i = tileAt(ev.x, ev.y)
      if i then pickTile(i) end
    end,
  }
  dlg:button{ id = "prev", text = "< Prev", enabled = false,
    onclick = function() view.page = math.max(1, view.page - 1); refreshLabels() end }
  dlg:label{ id = "page", text = "" }
  dlg:button{ id = "next", text = "Next >", enabled = false,
    onclick = function() view.page = math.min(pages(), view.page + 1); refreshLabels() end }

  dlg:separator{ text = "Stamp" }
  dlg:label{ id = "stamp", text = Stamp.describe() }
  dlg:button{ text = "Rotate &Left", onclick = function() Stamp.rotate(-1); Browser.refreshStamp() end }
  dlg:button{ text = "Rotate &Right", onclick = function() Stamp.rotate(1); Browser.refreshStamp() end }
  dlg:newrow()
  dlg:button{ text = "Mirror &H", onclick = function() Stamp.mirror(true); Browser.refreshStamp() end }
  dlg:button{ text = "Mirror &V", onclick = function() Stamp.mirror(false); Browser.refreshStamp() end }
  dlg:button{ text = "Rese&t", onclick = function() Stamp.reset(); Browser.refreshStamp() end }

  dlg:separator()
  dlg:button{
    text = "&Edit Entry",
    onclick = function()
      if view.group and view.entry then
        app.open(Library.entryPath(view.group, view.entry))
      end
    end,
  }
  dlg:button{
    text = "Re&fresh",
    onclick = function()
      cache = {}
      local list = Library.groups()
      local g = view.group and Library.findGroup(view.group) or list[1]
      dlg:modify{ id = "group", options = (#list > 0) and list or { "(empty)" }, option = g or "(empty)" }
      local es = selectGroup(g)
      dlg:modify{ id = "entry", options = entryOptions(es), option = es[1] or "(empty)" }
      refreshLabels()
    end,
  }
  dlg:button{ text = "&Close", onclick = function() dlg:close() end }

  dlg:show{ wait = false }
  refreshLabels()
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
