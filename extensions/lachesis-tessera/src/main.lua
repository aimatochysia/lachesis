-- Lachesis Tessera: tiled preview of a selection.
-- Requires Aseprite 1.3 or newer.

local Config, Preview

local function loadModule(plugin, name)
  return dofile(app.fs.joinPath(plugin.path, "src", name .. ".lua"))
end

local function versionSupported()
  return app.apiVersion ~= nil and app.version >= Version("1.3")
end

function init(plugin)
  if not versionSupported() then
    app.alert{
      title = "Lachesis Tessera",
      text = "Lachesis Tessera needs Aseprite 1.3 or newer. The extension is disabled.",
    }
    return
  end
  -- Everything here is interactive.
  if not app.isUIAvailable then return end

  Config = loadModule(plugin, "config")
  Config.init(plugin)
  local Region = loadModule(plugin, "region")
  local Render = loadModule(plugin, "render")
  Preview = loadModule(plugin, "preview")
  Preview.init(Config, Region, Render)

  plugin:newMenuGroup{
    id = "lachesis_tessera_preview",
    title = "Tiled Preview",
    group = "file_scripts",
  }

  -- No default shortcut: users can bind one in Edit > Keyboard Shortcuts.
  plugin:newCommand{
    id = "LachesisTesseraTiledPreview",
    title = "Tiled Preview",
    group = "lachesis_tessera_preview",
    onchecked = function() return Preview.isWindowOpen() end,
    onclick = function() Preview.command() end,
  }

  plugin:newMenuSeparator{ group = "lachesis_tessera_preview" }

  plugin:newCommand{
    id = "LachesisTesseraSettings",
    title = "Tiled Preview Settings...",
    group = "lachesis_tessera_preview",
    onclick = function()
      Config.showDialog(function(oldMode) Preview.settingsChanged(oldMode) end)
    end,
  }
end

function exit(plugin)
  -- plugin.preferences is saved by Aseprite automatically.
  if Preview then Preview.shutdown() end
end
