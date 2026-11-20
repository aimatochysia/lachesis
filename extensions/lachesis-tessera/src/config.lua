-- Lachesis Tessera: settings, defaults and persistence through plugin.preferences.

local Config = {}

Config.MODES = { "peek", "window" }
Config.MODE_LABELS = {
  peek = "Hold to peek (over the canvas)",
  window = "Preview window",
}

Config.REPEATS = { "both", "x", "y" }
Config.REPEAT_LABELS = {
  both = "Both",
  x = "Horizontal",
  y = "Vertical",
}

Config.TILE_COUNTS = { 2, 3, 4, 5, 6, 7 }
Config.ZOOMS = { 0, 1, 2, 3, 4, 6, 8 }   -- 0 = fit to window

Config.DEFAULTS = {
  mode = "peek",
  repeatMode = "both",
  tiles = 3,
  zoom = 0,
  windowBounds = "",   -- "x,y,w,h" of the preview window when it was last closed
}

local prefs = nil

function Config.init(plugin)
  prefs = plugin.preferences
  for key, default in pairs(Config.DEFAULTS) do
    if type(prefs[key]) ~= type(default) then
      prefs[key] = default
    end
  end
  -- Drop values a newer or older version may have left behind.
  if not Config.MODE_LABELS[prefs.mode] then prefs.mode = Config.DEFAULTS.mode end
  if not Config.REPEAT_LABELS[prefs.repeatMode] then prefs.repeatMode = Config.DEFAULTS.repeatMode end
  if prefs.tiles < 2 or prefs.tiles > 7 then prefs.tiles = Config.DEFAULTS.tiles end
  if prefs.zoom < 0 or prefs.zoom > 8 then prefs.zoom = Config.DEFAULTS.zoom end
end

function Config.get(key)
  if prefs == nil then return Config.DEFAULTS[key] end
  return prefs[key]
end

function Config.set(key, value)
  if prefs then prefs[key] = value end
end

function Config.zoomLabel(z)
  if z == 0 then return "Fit" end
  return z .. "x"
end

function Config.tilesLabel(n)
  return n .. "x" .. n
end

-- Label lists and reverse lookups for combobox widgets.
function Config.options(values, labelOf)
  local labels, byLabel = {}, {}
  for i, v in ipairs(values) do
    local l = labelOf(v)
    labels[i] = l
    byLabel[l] = v
  end
  return labels, byLabel
end

function Config.decodeBounds(s)
  if type(s) ~= "string" then return nil end
  local x, y, w, h = s:match("^(-?%d+),(-?%d+),(%d+),(%d+)$")
  if not x then return nil end
  x, y, w, h = tonumber(x), tonumber(y), tonumber(w), tonumber(h)
  if w < 80 or h < 80 then return nil end
  return Rectangle(x, y, w, h)
end

function Config.encodeBounds(r)
  return string.format("%d,%d,%d,%d", r.x, r.y, r.width, r.height)
end

-- Settings dialog. onChange(oldMode) is called after OK.
function Config.showDialog(onChange)
  local modeLabels, modeBy = Config.options(Config.MODES, function(v) return Config.MODE_LABELS[v] end)
  local repLabels, repBy = Config.options(Config.REPEATS, function(v) return Config.REPEAT_LABELS[v] end)
  local tileLabels, tileBy = Config.options(Config.TILE_COUNTS, Config.tilesLabel)
  local zoomLabels, zoomBy = Config.options(Config.ZOOMS, Config.zoomLabel)

  local dlg = Dialog{ title = "Tiled Preview Settings" }
  dlg:combobox{ id = "mode", label = "Show as:", option = Config.MODE_LABELS[Config.get("mode")], options = modeLabels }
  dlg:label{ text = "Peek: hold the shortcut to see the tiles, let go to hide them." }
  dlg:newrow()
  dlg:label{ text = "Window: the shortcut opens and closes a live preview window." }
  dlg:separator{ text = "Tiles" }
  dlg:combobox{ id = "repeatMode", label = "Repeat:", option = Config.REPEAT_LABELS[Config.get("repeatMode")], options = repLabels }
  dlg:combobox{ id = "tiles", label = "Tiles:", option = Config.tilesLabel(Config.get("tiles")), options = tileLabels }
  dlg:combobox{ id = "zoom", label = "Zoom:", option = Config.zoomLabel(Config.get("zoom")), options = zoomLabels }
  dlg:separator()
  dlg:button{ id = "ok", text = "&OK", focus = true }
  dlg:button{ id = "reset", text = "&Default" }
  dlg:button{ id = "cancel", text = "&Cancel" }
  dlg:show()

  local data = dlg.data
  local oldMode = Config.get("mode")
  if data.reset then
    for _, key in ipairs({ "mode", "repeatMode", "tiles", "zoom" }) do
      Config.set(key, Config.DEFAULTS[key])
    end
  elseif data.ok then
    Config.set("mode", modeBy[data.mode] or Config.DEFAULTS.mode)
    Config.set("repeatMode", repBy[data.repeatMode] or Config.DEFAULTS.repeatMode)
    Config.set("tiles", tileBy[data.tiles] or Config.DEFAULTS.tiles)
    Config.set("zoom", zoomBy[data.zoom] or Config.DEFAULTS.zoom)
  else
    return
  end
  if onChange then onChange(oldMode) end
end

return Config
