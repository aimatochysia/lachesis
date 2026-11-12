-- Lachesis: Aseprite snapshot extension entry point.
-- Requires Aseprite 1.3 or newer.

local Config

local function loadModule(plugin, name)
  return dofile(app.fs.joinPath(plugin.path, "src", name .. ".lua"))
end

local function versionSupported()
  return app.apiVersion ~= nil and app.version >= Version("1.3")
end

function init(plugin)
  if not versionSupported() then
    app.alert{
      title = "Lachesis",
      text = "Lachesis needs Aseprite 1.3 or newer. The extension is disabled.",
    }
    return
  end

  Config = loadModule(plugin, "config")
  Config.init(plugin)

  plugin:newMenuGroup{
    id = "lachesis_snapshots",
    title = "Snapshots",
    group = "file_scripts",
  }

  -- No default shortcut: users can bind one in Edit > Keyboard Shortcuts.
  plugin:newCommand{
    id = "LachesisToggleSnapshots",
    title = "Snapshots Enabled",
    group = "lachesis_snapshots",
    onchecked = function() return Config.isEnabled() end,
    onclick = function()
      Config.setEnabled(not Config.isEnabled())
    end,
  }

  plugin:newMenuSeparator{ group = "lachesis_snapshots" }

  plugin:newCommand{
    id = "LachesisSettings",
    title = "Snapshot Settings...",
    group = "lachesis_snapshots",
    onclick = function() Config.showDialog() end,
  }
end

function exit(plugin)
  -- plugin.preferences is saved by Aseprite automatically.
end
