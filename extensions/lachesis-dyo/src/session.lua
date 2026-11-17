-- Lachesis Dyo: records which sprites are open and reopens them on launch.

local Session = {}

local Config = nil
local timer = nil
local restored = false   -- the launch restore ran (or was skipped) for this run
local frozen = false     -- Aseprite is quitting: keep the last saved list as is
local lastSaved = nil    -- serialized session last written, to skip unchanged saves

local FILE_HEADER = "lachesis-dyo session 1"

local function isWindows()
  return app.fs.pathSeparator == "\\"
end

-- Windows and macOS file systems are case-insensitive by default, so compare
-- paths case-insensitively there to avoid opening the same file twice.
local function caseInsensitive()
  if isWindows() then return true end
  local ok, mac = pcall(function() return app.os and app.os.macos end)
  return ok and mac == true
end

local function normalize(path)
  local p = app.fs.normalizePath(path)
  if isWindows() then p = p:gsub("/", "\\") end
  return p
end

local function pathKey(path)
  local p = normalize(path)
  if caseInsensitive() then p = p:lower() end
  return p
end

local function sessionFilePath()
  return app.fs.joinPath(app.fs.userConfigPath, "lachesis-dyo-session.txt")
end

-- Open sprites that live in a file on disk, in tab order, without duplicates.
local function collect()
  local files, seen = {}, {}
  for _, sprite in ipairs(app.sprites) do
    local name = sprite.filename
    if name and name ~= "" and app.fs.isFile(name) then
      local k = pathKey(name)
      if not seen[k] then
        seen[k] = true
        files[#files + 1] = normalize(name)
      end
    end
  end
  local active = ""
  local current = app.sprite
  if current and current.filename and app.fs.isFile(current.filename) then
    active = normalize(current.filename)
  end
  return files, active
end

local function serialize(files, active)
  return table.concat(files, "\n") .. "\0" .. active
end

local function splitLines(text)
  local out = {}
  for line in (text or ""):gmatch("[^\r\n]+") do out[#out + 1] = line end
  return out
end

local function writeSessionFile(files, active)
  local ok = pcall(function()
    local f = io.open(sessionFilePath(), "w")
    if not f then return end
    f:write(FILE_HEADER, "\n")
    f:write("active\t", active, "\n")
    for _, path in ipairs(files) do f:write("file\t", path, "\n") end
    f:close()
  end)
  if not ok then
    -- Access was refused: turn the option off so Aseprite stops asking.
    -- The session is still kept in the extension preferences.
    Config.set("sessionFile", false)
  end
end

local function readSessionFile()
  local path = sessionFilePath()
  if not app.fs.isFile(path) then return nil end
  local files, active = {}, ""
  local ok = pcall(function()
    local f = io.open(path, "r")
    if not f then return end
    local header = f:read("l")
    if header ~= FILE_HEADER then f:close() return end
    for line in f:lines() do
      local kind, value = line:match("^(%a+)\t(.*)$")
      if kind == "file" and value ~= "" then
        files[#files + 1] = value
      elseif kind == "active" then
        active = value
      end
    end
    f:close()
  end)
  if not ok or #files == 0 then return nil end
  return files, active
end

-- Saves the current list of open files. Skips work when nothing changed.
function Session.save()
  if frozen or not restored or not Config.isEnabled() then return end
  local files, active = collect()
  local serialized = serialize(files, active)
  if serialized == lastSaved then return end
  lastSaved = serialized
  Config.set("session", table.concat(files, "\n"))
  Config.set("active", active)
  if Config.get("sessionFile") then writeSessionFile(files, active) end
end

local function loadSaved()
  if Config.get("sessionFile") then
    local files, active = readSessionFile()
    if files then return files, active end
  end
  return splitLines(Config.get("session")), Config.get("active") or ""
end

-- Reopens the saved files, skipping missing ones and ones already open.
function Session.restore()
  local files, active = loadSaved()
  local open = {}
  for _, sprite in ipairs(app.sprites) do
    if sprite.filename and sprite.filename ~= "" then
      open[pathKey(sprite.filename)] = sprite
    end
  end

  local reopened, missing = 0, 0
  local previous = app.sprite
  for _, path in ipairs(files) do
    local k = pathKey(path)
    if not open[k] then
      if app.fs.isFile(path) then
        local ok, sprite = pcall(app.open, path)
        if ok and sprite then
          open[k] = sprite
          reopened = reopened + 1
        end
      else
        missing = missing + 1
      end
    end
  end

  -- Give focus back to the tab that was active, unless the user opened
  -- something themselves (for example by passing a file on the command line).
  local target = active ~= "" and open[pathKey(active)] or nil
  if previous then target = previous end
  if target then pcall(function() app.sprite = target end) end

  return reopened, missing
end

local function startTimer()
  if timer then timer:stop() end
  timer = Timer{
    interval = Config.get("interval"),
    ontick = function() Session.save() end,
  }
  timer:start()
end

-- Called once from init(). The restore waits for the first UI tick so that
-- Aseprite has finished starting and opened any files given on the command line.
function Session.init(config)
  Config = config

  -- Quitting closes the tabs one by one, so save the full list first and
  -- stop saving until we know whether the quit went through.
  app.events:on("beforecommand", function(ev)
    if ev.name == "Exit" and not frozen then
      Session.save()
      frozen = true
    end
  end)
  -- If the user cancelled the quit (for example in a "save changes?" prompt),
  -- tabs are still open: carry on saving as usual.
  app.events:on("aftercommand", function(ev)
    if ev.name == "Exit" and frozen and #app.sprites > 0 then
      frozen = false
    end
  end)

  local startup
  startup = Timer{
    interval = 0.5,
    ontick = function()
      startup:stop()
      if Config.isEnabled() then
        pcall(Session.restore)
        restored = true
        Session.save()
        startTimer()
      else
        restored = true
      end
    end,
  }
  startup:start()
end

function Session.setEnabled(on)
  Config.set("enabled", on == true)
  if on then
    lastSaved = nil
    Session.save()
    startTimer()
  elseif timer then
    timer:stop()
  end
end

function Session.applySettings()
  lastSaved = nil
  if Config.isEnabled() and restored then
    Session.save()
    startTimer()
  end
end

function Session.shutdown()
  if timer then timer:stop() end
end

return Session
