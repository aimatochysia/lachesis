-- Lachesis Tessera: the tiled preview itself.
--
-- Two ways to show it, picked in the settings:
--   peek    a window over the canvas that is shown while the shortcut is held
--           and closes when it is released;
--   window  a floating live preview window that the shortcut opens and closes.
--
-- Both follow the active sprite, its current frame and its selection, and
-- redraw shortly after anything changes. Nothing is ever written to the
-- sprite: no layers, cels, properties or undo steps.

local Preview = {}

local Config, Region, Render

local TICK = 0.05          -- seconds between checks for changes
local RELEASE_TICKS = 5    -- no key repeat for this long = key released (fallback)
local REPEAT_TICKS = 14    -- a second press sooner than this is the key repeating

local timer = nil
local ticks = 0

-- What is on screen, so we only re-render when something changed.
local state = {
  sprite = nil,
  listenerId = nil,
  dirty = true,
  signature = nil,
  tile = nil,        -- RGB image of the region at 1x
  scaled = nil,      -- tile scaled for the current canvas size
  scaledKey = nil,
  message = nil,     -- shown instead of tiles when there is nothing to show
}

local win = nil      -- the preview window, when open
local peek = nil     -- the peek window, when open
local peekState = nil

-- Change tracking ----------------------------------------------------------

local function unlisten()
  if state.sprite and state.listenerId then
    pcall(function() state.sprite.events:off(state.listenerId) end)
  end
  state.sprite = nil
  state.listenerId = nil
end

local function listen(sprite)
  if sprite == state.sprite then return end
  unlisten()
  state.sprite = sprite
  state.dirty = true
  if sprite then
    local ok, id = pcall(function()
      return sprite.events:on("change", function() state.dirty = true end)
    end)
    if ok then state.listenerId = id end
  end
end

local function signatureOf(sprite, frameNumber, r)
  return table.concat({
    sprite.filename or "", sprite.width, sprite.height, sprite.colorMode,
    frameNumber, r.x, r.y, r.width, r.height,
  }, ",")
end

-- Re-render the tile if needed. Returns true when the picture changed.
local function refresh()
  local sprite = app.sprite
  listen(sprite)
  if not sprite then
    local changed = state.message == nil
    state.tile, state.scaled, state.scaledKey, state.signature = nil, nil, nil, nil
    state.message = "Open a sprite to see its tiled preview."
    return changed
  end
  local frame = app.frame
  local frameNumber = frame and frame.frameNumber or 1
  local r = Region.current(sprite)
  local sig = signatureOf(sprite, frameNumber, r)
  if not state.dirty and sig == state.signature and state.tile then
    return false
  end
  local ok, img = pcall(Render.tile, sprite, frameNumber, r)
  state.dirty = false
  state.signature = sig
  state.scaled, state.scaledKey = nil, nil
  if ok then
    state.tile = img
    state.message = nil
  else
    state.tile = nil
    state.message = "Could not render the preview."
  end
  return true
end

-- Drawing --------------------------------------------------------------------

local BG = Color{ r = 45, g = 45, b = 45 }
local CHECK_LIGHT = Color{ r = 200, g = 200, b = 200 }
local CHECK_DARK = Color{ r = 150, g = 150, b = 150 }
local TEXT = Color{ r = 230, g = 230, b = 230 }
local CHECK = 8

local function paint(ev)
  local gc = ev.context
  local cw, ch = gc.width, gc.height
  gc.color = BG
  gc:fillRect(Rectangle(0, 0, cw, ch))

  if not state.tile then
    if state.message then
      gc.color = TEXT
      gc:fillText(state.message, 8, 8)
    end
    return
  end

  local cols, rows = Render.grid(Config.get("repeatMode"), Config.get("tiles"))
  local tw, th = state.tile.width, state.tile.height
  local scale = Config.get("zoom")
  if scale == 0 then scale = Render.fitScale(tw, th, cols, rows, cw, ch) end

  local key = scale
  if state.scaledKey ~= key or not state.scaled then
    state.scaled = Render.scaled(state.tile, scale)
    state.scaledKey = key
  end
  local img = state.scaled
  local sw, sh = img.width, img.height
  local totalW, totalH = sw * cols, sh * rows
  local ox = math.floor((cw - totalW) / 2)
  local oy = math.floor((ch - totalH) / 2)

  -- Checkerboard behind the tiles, in screen space so it never fakes a seam.
  local x1, y1 = math.max(0, ox), math.max(0, oy)
  local x2, y2 = math.min(cw, ox + totalW), math.min(ch, oy + totalH)
  if x2 > x1 and y2 > y1 then
    gc.color = CHECK_LIGHT
    gc:fillRect(Rectangle(x1, y1, x2 - x1, y2 - y1))
    gc.color = CHECK_DARK
    for y = y1, y2 - 1, CHECK do
      local start = x1 + ((((y - y1) // CHECK) % 2) * CHECK)
      for x = start, x2 - 1, CHECK * 2 do
        gc:fillRect(Rectangle(x, y, math.min(CHECK, x2 - x), math.min(CHECK, y2 - y)))
      end
    end
  end

  for j = 0, rows - 1 do
    for i = 0, cols - 1 do
      gc:drawImage(img, ox + i * sw, oy + j * sh)
    end
  end
end

local function repaint()
  if win then pcall(function() win:repaint() end) end
  if peek then pcall(function() peek:repaint() end) end
end

-- Timer ----------------------------------------------------------------------

local closePeek -- forward declaration

local windowTitle -- forward declaration
local shownTitle = nil

local function onTick()
  ticks = ticks + 1
  if not win and not peek then return end
  if refresh() then repaint() end

  if win then
    local t = windowTitle()
    if t ~= shownTitle then
      shownTitle = t
      pcall(function() win:modify{ title = t } end)
    end
  end

  -- Fallback release detection for setups where the peek window does not get
  -- the key-up: while the key is held Aseprite keeps repeating the command,
  -- so once the repeats stop the key was let go.
  if peek and peekState and peekState.repeating and not peekState.gotKeys
     and ticks - peekState.lastSignal > RELEASE_TICKS then
    closePeek()
  end
end

local function ensureTimer()
  if not timer then
    timer = Timer{ interval = TICK, ontick = onTick }
  end
  if not timer.isRunning then timer:start() end
end

local function maybeStopTimer()
  if timer and not win and not peek then
    timer:stop()
    unlisten()
  end
end

-- Preview window -------------------------------------------------------------

windowTitle = function()
  local s = app.sprite
  if s then return "Tiled Preview: " .. app.fs.fileName(s.filename) end
  return "Tiled Preview"
end

local function saveWindowBounds()
  if not win then return end
  pcall(function() Config.set("windowBounds", Config.encodeBounds(win.bounds)) end)
end

function Preview.isWindowOpen()
  return win ~= nil
end

function Preview.closeWindow()
  if not win then return end
  saveWindowBounds()
  local w = win
  win = nil
  pcall(function() w:close() end)
  maybeStopTimer()
end

function Preview.openWindow()
  if win then return end
  local repLabels, repBy = Config.options(Config.REPEATS, function(v) return Config.REPEAT_LABELS[v] end)
  local tileLabels, tileBy = Config.options(Config.TILE_COUNTS, Config.tilesLabel)
  local zoomLabels, zoomBy = Config.options(Config.ZOOMS, Config.zoomLabel)

  local dlg
  dlg = Dialog{
    title = windowTitle(),
    onclose = function()
      if win == dlg then
        saveWindowBounds()
        win = nil
        maybeStopTimer()
      end
    end,
  }
  dlg:canvas{ id = "canvas", width = 320, height = 320, onpaint = paint }
  dlg:newrow()
  dlg:combobox{
    id = "repeatMode", option = Config.REPEAT_LABELS[Config.get("repeatMode")], options = repLabels,
    onchange = function()
      Config.set("repeatMode", repBy[dlg.data.repeatMode] or "both")
      state.scaled = nil
      dlg:repaint()
    end,
  }
  dlg:combobox{
    id = "tiles", option = Config.tilesLabel(Config.get("tiles")), options = tileLabels,
    onchange = function()
      Config.set("tiles", tileBy[dlg.data.tiles] or 3)
      state.scaled = nil
      dlg:repaint()
    end,
  }
  dlg:combobox{
    id = "zoom", option = Config.zoomLabel(Config.get("zoom")), options = zoomLabels,
    onchange = function()
      Config.set("zoom", zoomBy[dlg.data.zoom] or 0)
      state.scaled = nil
      dlg:repaint()
    end,
  }

  win = dlg
  shownTitle = windowTitle()
  state.dirty = true
  refresh()
  local bounds = Config.decodeBounds(Config.get("windowBounds"))
  if bounds then
    dlg:show{ wait = false, bounds = bounds }
  else
    dlg:show{ wait = false }
  end
  ensureTimer()
end

function Preview.toggleWindow()
  if win then Preview.closeWindow() else Preview.openWindow() end
end

-- Peek -----------------------------------------------------------------------

-- Size of the peek canvas: most of the main window when Aseprite tells us
-- its size, a fixed size otherwise.
local function peekSize()
  local ok, w, h = pcall(function() return app.window.width, app.window.height end)
  local scale = 1
  pcall(function() scale = app.preferences.general.ui_scale or 1 end)
  if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
    return math.max(200, math.floor(w * 0.85 / scale)), math.max(150, math.floor(h * 0.8 / scale))
  end
  return 640, 480
end

closePeek = function()
  if not peek then return end
  local p = peek
  peek = nil
  peekState = nil
  pcall(function() p:close() end)
  maybeStopTimer()
end

local function stop(ev)
  pcall(function() ev:stopPropagation() end)
end

local function openPeek()
  local w, h = peekSize()
  local dlg
  dlg = Dialog{
    title = "Tiled Preview (let go to close)",
    notitlebar = true,
    onclose = function()
      if peek == dlg then
        peek = nil
        peekState = nil
        maybeStopTimer()
      end
    end,
  }
  dlg:canvas{
    id = "canvas", width = w, height = h, focus = true,
    onpaint = paint,
    onkeydown = function(ev)
      if peekState then peekState.gotKeys = true end
      stop(ev)
      if ev.key == "Escape" then closePeek() end
    end,
    onkeyup = function(ev)
      stop(ev)
      closePeek()
    end,
    onmousedown = function() closePeek() end,
  }
  peek = dlg
  peekState = { opened = ticks, lastSignal = ticks, repeating = false, gotKeys = false }
  state.dirty = true
  refresh()
  dlg:show{ wait = false }
  ensureTimer()
end

-- Called each time the shortcut fires in peek mode. Holding a key makes the
-- command fire again and again, so a repeat keeps the peek open and only a
-- real second press (after a pause) closes it.
function Preview.peekPressed()
  if not peek then
    openPeek()
    return
  end
  if peekState.gotKeys then return end -- the peek sees the key itself
  local gap = ticks - peekState.lastSignal
  peekState.lastSignal = ticks
  if peekState.repeating or gap < REPEAT_TICKS then
    peekState.repeating = true
  else
    closePeek()
  end
end

-- Shared -----------------------------------------------------------------------

function Preview.init(config, region, render)
  Config, Region, Render = config, region, render
end

-- The menu command: peek or toggle the window, depending on the settings.
function Preview.command()
  if Config.get("mode") == "window" then
    Preview.toggleWindow()
  else
    Preview.peekPressed()
  end
end

function Preview.settingsChanged(oldMode)
  if oldMode == "window" and Config.get("mode") ~= "window" then
    Preview.closeWindow()
  end
  state.scaled = nil
  repaint()
end

function Preview.shutdown()
  closePeek()
  Preview.closeWindow()
  if timer then timer:stop() end
  unlisten()
  Region.forget()
end

return Preview
