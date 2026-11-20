-- Lachesis Tria: a tile library for pixel art.
-- Requires Aseprite 1.3 or newer.

local Config, Capturer

local function loadModule(plugin, name)
  return dofile(app.fs.joinPath(plugin.path, "src", name .. ".lua"))
end

local function versionSupported()
  return app.apiVersion ~= nil and app.version >= Version("1.3")
end

function init(plugin)
  if not versionSupported() then
    app.alert{
      title = "Lachesis Tria",
      text = "Lachesis Tria needs Aseprite 1.3 or newer. The extension is disabled.",
    }
    return
  end
  -- Everything here is interactive.
  if not app.isUIAvailable then return end

  Config = loadModule(plugin, "config")
  Config.init(plugin)
  local Library = loadModule(plugin, "library")
  Library.init(Config)
  local Capture = loadModule(plugin, "capture")
  Capturer = loadModule(plugin, "capturer")
  Capturer.init(Config, Library, Capture)

  plugin:newMenuGroup{
    id = "lachesis_tria_library",
    title = "Tile Library",
    group = "file_scripts",
  }

  -- No default shortcuts: users can bind them in Edit > Keyboard Shortcuts.
  plugin:newCommand{
    id = "LachesisTriaCapture",
    title = "Capture Tiles From Canvas...",
    group = "lachesis_tria_library",
    onenabled = function() return app.sprite ~= nil end,
    onclick = function() Capturer.run() end,
  }

  plugin:newMenuSeparator{ group = "lachesis_tria_library" }

  plugin:newCommand{
    id = "LachesisTriaSettings",
    title = "Tile Library Settings...",
    group = "lachesis_tria_library",
    onclick = function() Config.showDialog() end,
  }
end

function exit(plugin)
  -- plugin.preferences is saved by Aseprite automatically.
end
