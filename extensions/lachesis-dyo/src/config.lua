-- Lachesis Dyo: settings, defaults and persistence through plugin.preferences.

local Config = {}

Config.DEFAULTS = {
  enabled = true,       -- save the session in the background and restore it on launch
  interval = 120,       -- seconds between background saves
  sessionFile = false,  -- also write the session to a file so it survives a crash
  session = "",         -- last saved list of open files, one path per line
  active = "",          -- the file that had focus when the session was saved
}

local LIMITS = {
  interval = { min = 15, max = 3600 },
}

local prefs = nil

local function clamp(key, value)
  local l = LIMITS[key]
  if not l then return value end
  if value < l.min then return l.min end
  if value > l.max then return l.max end
  return value
end

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

-- Returns true when the user pressed OK and settings changed.
function Config.showDialog()
  local dlg = Dialog{ title = "Lachesis Dyo Session Settings" }
  dlg:separator{ text = "Background save" }
  dlg:number{
    id = "minutes", label = "Save every (min):",
    text = tostring(Config.get("interval") / 60), decimals = 2,
  }
  dlg:check{
    id = "sessionFile", text = "Also keep a crash-safe session file",
    selected = Config.get("sessionFile"),
  }
  dlg:label{ text = "Aseprite asks once for permission to write this file." }
  dlg:label{ text = "Without it, the session is kept when Aseprite closes normally." }
  dlg:separator()
  dlg:button{ id = "ok", text = "&OK", focus = true }
  dlg:button{ id = "reset", text = "&Defaults" }
  dlg:button{ id = "cancel", text = "&Cancel" }
  dlg:show()

  local data = dlg.data
  if data.reset then
    Config.set("interval", Config.DEFAULTS.interval)
    Config.set("sessionFile", Config.DEFAULTS.sessionFile)
    return true
  elseif data.ok then
    Config.set("interval", math.floor((data.minutes or 2) * 60 + 0.5))
    Config.set("sessionFile", data.sessionFile == true)
    return true
  end
  return false
end

return Config
