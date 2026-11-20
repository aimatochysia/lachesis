-- Lachesis Tria: settings, defaults and persistence through plugin.preferences.

local Config = {}

Config.DEFAULTS = {
  libraryPath = "",   -- custom library folder; empty means the default one
  lastGroup = "",     -- group picked in the last capture
  lastGrid = "",      -- "x,y,w,h" used in the last capture, for files with no saved grid
  grids = "",         -- per-file grids, one "path\tx,y,w,h" per line
}

local prefs = nil

function Config.init(plugin)
  prefs = plugin.preferences
  for key, default in pairs(Config.DEFAULTS) do
    if type(prefs[key]) ~= type(default) then
      prefs[key] = default
    end
  end
end

function Config.get(key)
  if prefs == nil then return Config.DEFAULTS[key] end
  return prefs[key]
end

function Config.set(key, value)
  prefs[key] = value
end

-- Default library folder inside Aseprite's own config folder.
function Config.defaultLibraryPath()
  return app.fs.joinPath(app.fs.userConfigPath, "lachesis-tria", "library")
end

function Config.libraryPath()
  local p = Config.get("libraryPath")
  if p == nil or p == "" then return Config.defaultLibraryPath() end
  return p
end

-- Grids are stored as "x,y,w,h" strings.
function Config.encodeGrid(g)
  return string.format("%d,%d,%d,%d", g.x, g.y, g.w, g.h)
end

function Config.decodeGrid(s)
  if type(s) ~= "string" then return nil end
  local x, y, w, h = s:match("^(%d+),(%d+),(%d+),(%d+)$")
  if not x then return nil end
  return { x = tonumber(x), y = tonumber(y), w = tonumber(w), h = tonumber(h) }
end

local function pathKey(path)
  -- Windows and macOS file systems are case-insensitive.
  if app.os.windows or app.os.macos then return path:lower() end
  return path
end

-- Grid last used for a file, or nil.
function Config.gridFor(path)
  if path == nil or path == "" then return nil end
  local key = pathKey(path)
  for line in (Config.get("grids") .. "\n"):gmatch("(.-)\n") do
    local p, g = line:match("^(.*)\t(.*)$")
    if p and pathKey(p) == key then return Config.decodeGrid(g) end
  end
  return nil
end

local MAX_GRIDS = 200

function Config.rememberGrid(path, grid)
  local encoded = Config.encodeGrid(grid)
  Config.set("lastGrid", encoded)
  if path == nil or path == "" then return end
  local key = pathKey(path)
  local lines = { path .. "\t" .. encoded }
  for line in (Config.get("grids") .. "\n"):gmatch("(.-)\n") do
    local p = line:match("^(.*)\t")
    if p and pathKey(p) ~= key and #lines < MAX_GRIDS then
      lines[#lines + 1] = line
    end
  end
  Config.set("grids", table.concat(lines, "\n"))
end

-- Returns true when the user pressed OK and settings changed.
function Config.showDialog()
  local dlg = Dialog{ title = "Tile Library Settings" }
  dlg:separator{ text = "Library folder" }
  dlg:entry{ id = "path", label = "Folder:", text = Config.libraryPath() }
  dlg:label{ text = "Leave empty or press Default to use Aseprite's config folder." }
  dlg:separator()
  dlg:button{ id = "ok", text = "&OK", focus = true }
  dlg:button{ id = "reset", text = "&Default" }
  dlg:button{ id = "cancel", text = "&Cancel" }
  dlg:show()

  local data = dlg.data
  if data.reset then
    Config.set("libraryPath", "")
    return true
  elseif data.ok then
    local p = (data.path or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if p == Config.defaultLibraryPath() then p = "" end
    Config.set("libraryPath", p)
    return true
  end
  return false
end

return Config
