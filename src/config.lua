-- Lachesis: settings, defaults and persistence through plugin.preferences.

local Config = {}

Config.DEFAULTS = {
  enabled = false,          -- snapshot toggle, off until the user turns it on
  idleDelay = 1.5,          -- seconds without edits before a snapshot is taken
  maxWait = 10,             -- seconds of continuous editing before a forced snapshot
  maxSnapshotKB = 1024,     -- size cap per snapshot file (1 MB)
}

-- Bounds used by the settings dialog and when reading stored values.
local LIMITS = {
  idleDelay = { min = 0.25, max = 60 },
  maxWait = { min = 1, max = 600 },
  maxSnapshotKB = { min = 16, max = 65536 },
}

local prefs = nil

local function clamp(key, value)
  local l = LIMITS[key]
  if not l then return value end
  if value < l.min then return l.min end
  if value > l.max then return l.max end
  return value
end

-- Bind to plugin.preferences and fill in any missing or invalid keys.
function Config.init(plugin)
  prefs = plugin.preferences
  for key, default in pairs(Config.DEFAULTS) do
    local v = prefs[key]
    if type(v) ~= type(default) then
      prefs[key] = default
    elseif type(v) == "number" then
      prefs[key] = clamp(key, v)
    end
  end
end

function Config.get(key)
  if prefs == nil then return Config.DEFAULTS[key] end
  return prefs[key]
end

function Config.set(key, value)
  if type(value) == "number" then value = clamp(key, value) end
  prefs[key] = value
end

function Config.isEnabled()
  return Config.get("enabled") == true
end

function Config.setEnabled(on)
  Config.set("enabled", on == true)
end

function Config.showDialog()
  local dlg = Dialog{ title = "Lachesis Snapshot Settings" }
  dlg:separator{ text = "Capture" }
  dlg:number{
    id = "idleDelay", label = "Idle delay (s):",
    text = tostring(Config.get("idleDelay")), decimals = 2,
  }
  dlg:number{
    id = "maxWait", label = "Max wait (s):",
    text = tostring(Config.get("maxWait")), decimals = 1,
  }
  dlg:number{
    id = "maxSnapshotKB", label = "Max size (KB):",
    text = tostring(Config.get("maxSnapshotKB")), decimals = 0,
  }
  dlg:label{ text = "Snapshots are taken after you pause editing." }
  dlg:separator()
  dlg:button{ id = "ok", text = "&OK", focus = true }
  dlg:button{ id = "reset", text = "&Defaults" }
  dlg:button{ id = "cancel", text = "&Cancel" }
  dlg:show()

  local data = dlg.data
  if data.reset then
    for key, default in pairs(Config.DEFAULTS) do
      if key ~= "enabled" then Config.set(key, default) end
    end
  elseif data.ok then
    Config.set("idleDelay", data.idleDelay)
    Config.set("maxWait", data.maxWait)
    Config.set("maxSnapshotKB", math.floor(data.maxSnapshotKB))
  end
end

return Config
