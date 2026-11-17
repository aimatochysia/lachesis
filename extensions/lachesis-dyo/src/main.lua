-- Lachesis Dyo: reopens the sprites from your last Aseprite session.
-- Requires Aseprite 1.3 or newer.

local Config, Session

local function loadModule(plugin, name)
  return dofile(app.fs.joinPath(plugin.path, "src", name .. ".lua"))
end

local function versionSupported()
  return app.apiVersion ~= nil and app.version >= Version("1.3")
end

function init(plugin)
  if not versionSupported() then
    app.alert{
      title = "Lachesis Dyo",
      text = "Lachesis Dyo needs Aseprite 1.3 or newer. The extension is disabled.",
    }
    return
  end
  -- Nothing to restore when Aseprite runs a script in batch mode.
  if not app.isUIAvailable then return end

  Config = loadModule(plugin, "config")
  Config.init(plugin)
  Session = loadModule(plugin, "session")
  Session.init(Config)

  plugin:newMenuGroup{
    id = "lachesis_dyo_session",
    title = "Session Restore",
    group = "file_scripts",
  }

  -- No default shortcut: users can bind one in Edit > Keyboard Shortcuts.
  plugin:newCommand{
    id = "LachesisDyoToggle",
    title = "Restore Last Session on Launch",
    group = "lachesis_dyo_session",
    onchecked = function() return Config.isEnabled() end,
    onclick = function() Session.setEnabled(not Config.isEnabled()) end,
  }

  plugin:newCommand{
    id = "LachesisDyoRestoreNow",
    title = "Reopen Last Session Now",
    group = "lachesis_dyo_session",
    onclick = function()
      local reopened, missing = Session.restore()
      if reopened == 0 and missing == 0 then
        app.alert{ title = "Lachesis Dyo", text = "Everything from the last session is already open." }
      elseif missing > 0 then
        app.alert{
          title = "Lachesis Dyo",
          text = string.format("Reopened %d file(s). %d file(s) no longer exist.", reopened, missing),
        }
      end
    end,
  }

  plugin:newMenuSeparator{ group = "lachesis_dyo_session" }

  plugin:newCommand{
    id = "LachesisDyoSettings",
    title = "Session Restore Settings...",
    group = "lachesis_dyo_session",
    onclick = function()
      if Config.showDialog() then Session.applySettings() end
    end,
  }
end

function exit(plugin)
  -- plugin.preferences is saved by Aseprite automatically.
  if Session then Session.shutdown() end
end
