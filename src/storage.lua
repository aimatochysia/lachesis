-- Lachesis: where snapshots live and how they are named.
--
-- Layout: <project dir>/snapshots/<project name>/
-- File name: <index>_<yyyymmdd-hhmmss>_f<frame>[_s<downscale>].png
-- Metadata is kept in the file name so no extra files need writing.

local Storage = {}

local FOLDER = "snapshots"
local nextIndexCache = {}  -- dir -> next free index

-- Folder for a sprite's snapshots, or nil if the sprite was never saved.
function Storage.dirFor(sprite)
  local filename = sprite.filename
  if filename == nil or filename == "" or not app.fs.isFile(filename) then
    return nil
  end
  local dir = app.fs.filePath(filename)
  local name = app.fs.fileTitle(filename)
  return app.fs.joinPath(dir, FOLDER, name)
end

-- Parse a snapshot file name. Returns a table or nil.
function Storage.parse(name)
  local index, stamp, frame, rest = name:match("^(%d+)_(%d+%-%d+)_f(%d+)(.-)%.png$")
  if not index then return nil end
  local scale = tonumber(rest:match("^_s(%d+)$") or "1")
  return {
    index = tonumber(index),
    stamp = stamp,
    frame = tonumber(frame),
    scale = scale,
    name = name,
  }
end

-- All snapshots in a folder, oldest first.
function Storage.list(dir)
  local out = {}
  if not app.fs.isDirectory(dir) then return out end
  for _, name in ipairs(app.fs.listFiles(dir)) do
    local s = Storage.parse(name)
    if s then
      s.path = app.fs.joinPath(dir, name)
      out[#out + 1] = s
    end
  end
  table.sort(out, function(a, b) return a.index < b.index end)
  return out
end

local function scanNextIndex(dir)
  local maxIndex = 0
  if app.fs.isDirectory(dir) then
    for _, name in ipairs(app.fs.listFiles(dir)) do
      local s = Storage.parse(name)
      if s and s.index > maxIndex then maxIndex = s.index end
    end
  end
  return maxIndex + 1
end

-- Reserve the next file path in dir. Creates the folder if needed.
function Storage.nextPath(dir, frame, scale)
  if not app.fs.isDirectory(dir) then
    app.fs.makeAllDirectories(dir)
  end
  local index = nextIndexCache[dir] or scanNextIndex(dir)
  nextIndexCache[dir] = index + 1
  local name = string.format("%06d_%s_f%d", index, os.date("%Y%m%d-%H%M%S"), frame)
  if scale and scale > 1 then
    name = name .. "_s" .. scale
  end
  return app.fs.joinPath(dir, name .. ".png")
end

-- Forget cached indexes (after a folder is moved or renamed).
function Storage.invalidate(dir)
  if dir then nextIndexCache[dir] = nil else nextIndexCache = {} end
end

return Storage
