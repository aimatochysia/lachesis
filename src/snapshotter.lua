-- Lachesis: watch sprites for edits and snapshot after the user pauses.
--
-- An edit marks the sprite dirty. A single timer checks dirty sprites and
-- captures once the user has been idle for idleDelay seconds, or after
-- maxWait seconds of continuous editing. No edits means no snapshots.

local Snapshotter = {}

local Config, Storage, Capture
local TICK = 0.25

local timer = nil
local clock = 0            -- seconds since the timer started, advanced per tick
local states = {}          -- sprite -> state
local siteListener = nil

local function isAlive(sprite)
  local ok = pcall(function() return sprite.width end)
  return ok
end

local function stateFor(sprite)
  local st = states[sprite]
  if st == nil then
    st = { dirty = false, firstDirtyAt = 0, lastChangeAt = 0, frame = 1, lastImage = nil }
    states[sprite] = st
  end
  return st
end

local function activeFrameOf(sprite)
  if app.sprite == sprite and app.frame then
    return app.frame.frameNumber
  end
  return stateFor(sprite).frame
end

-- Take a snapshot of a sprite now. Skips unsaved sprites and unchanged images.
function Snapshotter.capture(sprite)
  local st = stateFor(sprite)
  st.dirty = false

  local dir = Storage.dirFor(sprite)
  if dir == nil then return end

  local frame = math.min(activeFrameOf(sprite), #sprite.frames)
  local img = Capture.flatten(sprite, frame)
  if Capture.same(img, st.lastImage) then return end
  st.lastImage = img

  local maxBytes = Config.get("maxSnapshotKB") * 1024
  local palette = sprite.palettes[1]
  local ok, err = pcall(Capture.write, img,
    function(scale) return Storage.nextPath(dir, frame, scale) end,
    maxBytes, palette)
  if not ok then
    print("Lachesis: could not save snapshot: " .. tostring(err))
  end
end

local function onChange(sprite)
  if not Config.isEnabled() then return end
  local st = stateFor(sprite)
  if not st.dirty then
    st.dirty = true
    st.firstDirtyAt = clock
  end
  st.lastChangeAt = clock
  if app.sprite == sprite and app.frame then
    st.frame = app.frame.frameNumber
  end
end

local function attach(sprite)
  local st = stateFor(sprite)
  if st.changeListener then return end
  st.changeListener = sprite.events:on("change", function() onChange(sprite) end)
  st.renameListener = sprite.events:on("filenamechange", function()
    -- A first save or Save As changes the folder. Rename following comes later.
    Storage.invalidate()
  end)
end

local function detach(sprite, st)
  if isAlive(sprite) then
    if st.changeListener then sprite.events:off(st.changeListener) end
    if st.renameListener then sprite.events:off(st.renameListener) end
  end
  st.changeListener, st.renameListener = nil, nil
end

local function prune()
  for sprite, st in pairs(states) do
    if not isAlive(sprite) then states[sprite] = nil end
  end
end

local function attachOpenSprites()
  for _, sprite in ipairs(app.sprites) do attach(sprite) end
end

local function tick()
  clock = clock + TICK
  local idle = Config.get("idleDelay")
  local maxWait = Config.get("maxWait")
  for sprite, st in pairs(states) do
    if st.dirty then
      if not isAlive(sprite) then
        states[sprite] = nil
      elseif clock - st.lastChangeAt >= idle or clock - st.firstDirtyAt >= maxWait then
        Snapshotter.capture(sprite)
      end
    end
  end
end

local function onSiteChange()
  prune()
  if app.sprite then attach(app.sprite) end
end

function Snapshotter.init(config, storage, capture)
  Config, Storage, Capture = config, storage, capture
  siteListener = app.events:on("sitechange", onSiteChange)
  timer = Timer{ interval = TICK, ontick = tick }
  if Config.isEnabled() then Snapshotter.start() end
end

function Snapshotter.start()
  attachOpenSprites()
  if not timer.isRunning then timer:start() end
  -- Baseline so the timelapse starts from the current state.
  if app.sprite then Snapshotter.capture(app.sprite) end
end

function Snapshotter.stop()
  if timer and timer.isRunning then timer:stop() end
  -- Flush pending edits so nothing made before turning off is lost.
  for sprite, st in pairs(states) do
    if st.dirty and isAlive(sprite) then Snapshotter.capture(sprite) end
  end
end

function Snapshotter.shutdown()
  Snapshotter.stop()
  for sprite, st in pairs(states) do detach(sprite, st) end
  states = {}
  if siteListener then app.events:off(siteListener) end
  siteListener = nil
end

return Snapshotter
