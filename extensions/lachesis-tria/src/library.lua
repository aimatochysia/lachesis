-- Lachesis Tria: groups and entries on disk.
--
-- Layout: <library>/<group>/<entry>.aseprite plus <entry>.preview.png
-- An entry file holds one frame per tile. Where the tiles came from is kept
-- in the sprite's properties under PROPS_KEY, so the file carries its own
-- metadata and no extra files need writing.

local Library = {}

Library.PROPS_KEY = "lachesis-tria"
Library.EXT = ".aseprite"
Library.PREVIEW_EXT = ".preview.png"
Library.PREVIEW_COLUMNS = 8

local Config = nil

function Library.init(config)
  Config = config
end

function Library.root()
  return Config.libraryPath()
end

local RESERVED = {
  CON = true, PRN = true, AUX = true, NUL = true,
  COM1 = true, COM2 = true, COM3 = true, COM4 = true, COM5 = true,
  COM6 = true, COM7 = true, COM8 = true, COM9 = true,
  LPT1 = true, LPT2 = true, LPT3 = true, LPT4 = true, LPT5 = true,
  LPT6 = true, LPT7 = true, LPT8 = true, LPT9 = true,
}

-- A name that is safe as a file or folder name on every OS, or nil.
function Library.sanitize(name)
  if type(name) ~= "string" then return nil end
  local s = name:gsub("[%c\\/:%*%?\"<>|]", "_")
  s = s:gsub("^%s+", ""):gsub("[%s%.]+$", "")
  if s == "" or s == "." or s == ".." then return nil end
  if RESERVED[s:upper()] then s = s .. "_" end
  if #s > 100 then s = s:sub(1, 100):gsub("[%s%.]+$", "") end
  return s
end

local function sortNames(list)
  table.sort(list, function(a, b)
    local la, lb = a:lower(), b:lower()
    if la == lb then return a < b end
    return la < lb
  end)
  return list
end

-- Group names, sorted.
function Library.groups()
  local root = Library.root()
  local out = {}
  if not app.fs.isDirectory(root) then return out end
  for _, name in ipairs(app.fs.listFiles(root)) do
    if app.fs.isDirectory(app.fs.joinPath(root, name)) then
      out[#out + 1] = name
    end
  end
  return sortNames(out)
end

function Library.groupPath(group)
  return app.fs.joinPath(Library.root(), group)
end

-- Entry names in a group, sorted.
function Library.entries(group)
  local dir = Library.groupPath(group)
  local out = {}
  if not app.fs.isDirectory(dir) then return out end
  for _, name in ipairs(app.fs.listFiles(dir)) do
    if name:lower():sub(-#Library.EXT) == Library.EXT then
      out[#out + 1] = name:sub(1, -#Library.EXT - 1)
    end
  end
  return sortNames(out)
end

function Library.entryPath(group, name)
  return app.fs.joinPath(Library.groupPath(group), name .. Library.EXT)
end

function Library.previewPath(group, name)
  return app.fs.joinPath(Library.groupPath(group), name .. Library.PREVIEW_EXT)
end

-- Existing name in a list that matches ignoring case, or nil. Names are
-- compared this way so a library behaves the same on Windows, macOS and Linux.
local function findName(list, name)
  local l = name:lower()
  for _, n in ipairs(list) do
    if n:lower() == l then return n end
  end
  return nil
end

function Library.findGroup(name)
  return findName(Library.groups(), name)
end

function Library.findEntry(group, name)
  return findName(Library.entries(group), name)
end

-- First free "<name> 2", "<name> 3", ... in a group.
function Library.freeName(group, name)
  local entries = Library.entries(group)
  if not findName(entries, name) then return name end
  local i = 2
  while findName(entries, name .. " " .. i) do i = i + 1 end
  return name .. " " .. i
end

-- One sheet with every tile, PREVIEW_COLUMNS per row, for the browser.
local function buildPreview(tiles, w, h, colorMode, tIndex)
  local n = #tiles
  local cols = math.min(n, Library.PREVIEW_COLUMNS)
  local rows = (n + cols - 1) // cols
  local sheet = Image(cols * w, rows * h, colorMode)
  if colorMode == ColorMode.INDEXED then sheet:clear(tIndex) end
  for i, t in ipairs(tiles) do
    local c = (i - 1) % cols
    local r = (i - 1) // cols
    local img = t.image
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        sheet:drawPixel(c * w + x, r * h + y, img:getPixel(x, y))
      end
    end
  end
  return sheet
end

-- Save tiles as an entry. opts:
--   group, name      already sanitized
--   tiles            list of { image, col, row }, all the same size
--   colorMode, palette, transparentColor
--   source           { path, frame, grid = { x, y, w, h } }
-- Returns the entry path, or nil and an error message.
function Library.saveEntry(opts)
  local tiles = opts.tiles
  if #tiles == 0 then return nil, "There are no tiles to save." end
  local w, h = tiles[1].image.width, tiles[1].image.height
  local dir = Library.groupPath(opts.group)
  if not app.fs.isDirectory(dir) then app.fs.makeAllDirectories(dir) end
  if not app.fs.isDirectory(dir) then
    return nil, "Couldn't create the folder " .. dir
  end

  local previous = app.sprite
  local tIndex = opts.transparentColor or 0
  local spec = ImageSpec{
    width = w, height = h,
    colorMode = opts.colorMode,
    transparentColor = tIndex,
  }
  local entry = Sprite(spec)
  local ok, err = pcall(function()
    if opts.palette then entry:setPalette(opts.palette) end
    local layer = entry.layers[1]
    layer.name = "Tiles"
    for i, t in ipairs(tiles) do
      if i > 1 then entry:newEmptyFrame(i) end
      entry:newCel(layer, i, t.image, Point(0, 0))
    end

    local positions = {}
    for i, t in ipairs(tiles) do positions[i] = t.col .. "," .. t.row end
    local props = entry.properties(Library.PROPS_KEY)
    props.version = 1
    props.kind = "tiles"
    props.tileWidth = w
    props.tileHeight = h
    props.tileCount = #tiles
    props.created = os.date("%Y-%m-%d %H:%M:%S")
    if opts.source then
      local g = opts.source.grid
      props.sourcePath = opts.source.path or ""
      props.sourceFrame = opts.source.frame or 1
      props.grid = string.format("%d,%d,%d,%d", g.x, g.y, g.w, g.h)
      -- Grid cell of each tile, in frame order, for updating from the source later.
      props.positions = table.concat(positions, ";")
    end

    entry:saveAs(Library.entryPath(opts.group, opts.name))
  end)
  entry:close()
  if previous then app.sprite = previous end
  if not ok then return nil, tostring(err) end

  local sheet = buildPreview(tiles, w, h, opts.colorMode, tIndex)
  local previewPath = Library.previewPath(opts.group, opts.name)
  if opts.colorMode == ColorMode.INDEXED and opts.palette then
    sheet:saveAs{ filename = previewPath, palette = opts.palette }
  else
    sheet:saveAs(previewPath)
  end
  return Library.entryPath(opts.group, opts.name)
end

return Library
