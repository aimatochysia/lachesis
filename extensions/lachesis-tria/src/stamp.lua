-- Lachesis Tria: turn a library tile into the active brush, so a ghost of it
-- follows the cursor and each click paints its pixels on the current layer.
--
-- Rotation is in quarter turns only (0, 90, 180, 270 degrees) and mirroring
-- is horizontal or vertical, so pixels are moved, never resampled.

local Stamp = {}

local Capture = nil

-- Current stamp: the tile as stored plus how it is turned.
local state = {
  tile = nil,          -- Image as stored in the library
  current = nil,       -- the tile as turned and mirrored now
  palette = nil,       -- palette of the entry (for indexed tiles)
  tIndex = 0,          -- transparent index of the entry
  rotation = 0,        -- quarter turns clockwise, 0..3
  flipH = false,
  flipV = false,
  label = "",
}

function Stamp.init(capture)
  Capture = capture
end

function Stamp.hasTile()
  return state.tile ~= nil
end

function Stamp.describe()
  if not state.tile then return "No tile picked" end
  local parts = { state.label, (state.rotation * 90) .. " deg" }
  if state.flipH then parts[#parts + 1] = "mirrored H" end
  if state.flipV then parts[#parts + 1] = "mirrored V" end
  return table.concat(parts, ", ")
end

-- Pure pixel transforms (also used by the tests).

-- Rotate a quarter turn clockwise.
function Stamp.rotateCW(img)
  local w, h = img.width, img.height
  local out = Image(h, w, img.colorMode)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      out:drawPixel(h - 1 - y, x, img:getPixel(x, y))
    end
  end
  return out
end

function Stamp.mirrorH(img)
  local w, h = img.width, img.height
  local out = Image(w, h, img.colorMode)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      out:drawPixel(w - 1 - x, y, img:getPixel(x, y))
    end
  end
  return out
end

function Stamp.mirrorV(img)
  local w, h = img.width, img.height
  local out = Image(w, h, img.colorMode)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      out:drawPixel(x, h - 1 - y, img:getPixel(x, y))
    end
  end
  return out
end

-- Color conversion into the target sprite's color mode.

local function nearestIndex(palette, rgba, cache, tIndex)
  local pc = app.pixelColor
  if pc.rgbaA(rgba) == 0 then return tIndex end
  local hit = cache[rgba]
  if hit then return hit end
  local r, g, b = pc.rgbaR(rgba), pc.rgbaG(rgba), pc.rgbaB(rgba)
  local best, bestD = 0, math.huge
  for i = 0, #palette - 1 do
    if i ~= tIndex then
      local c = palette:getColor(i)
      local dr, dg, db = c.red - r, c.green - g, c.blue - b
      local d = dr * dr + dg * dg + db * db
      if d < bestD then best, bestD = i, d end
      if d == 0 then break end
    end
  end
  cache[rgba] = best
  return best
end

-- An image in the sprite's color mode, mapping colors to the nearest palette
-- entry for indexed sprites.
function Stamp.forSprite(img, sourcePalette, sourceTIndex, sprite)
  local rgb = Capture.toRGB(img, sourcePalette, sourceTIndex)
  local mode = sprite.colorMode
  if mode == ColorMode.RGB then return rgb end

  local pc = app.pixelColor
  local out = Image(rgb.width, rgb.height, mode)
  if mode == ColorMode.INDEXED then
    local palette = sprite.palettes[1]
    local tIndex = sprite.transparentColor or 0
    local cache = {}
    for y = 0, rgb.height - 1 do
      for x = 0, rgb.width - 1 do
        out:drawPixel(x, y, nearestIndex(palette, rgb:getPixel(x, y), cache, tIndex))
      end
    end
  else -- grayscale
    for y = 0, rgb.height - 1 do
      for x = 0, rgb.width - 1 do
        local v = rgb:getPixel(x, y)
        local l = (pc.rgbaR(v) * 299 + pc.rgbaG(v) * 587 + pc.rgbaB(v) * 114) // 1000
        out:drawPixel(x, y, pc.graya(l, pc.rgbaA(v)))
      end
    end
  end
  return out
end

-- Put the current stamp on the brush and pick the pencil.
function Stamp.apply()
  if not state.current then return false end
  local sprite = app.sprite
  if not sprite then return false end
  local img = Stamp.forSprite(state.current, state.palette, state.tIndex, sprite)
  app.brush = Brush{ image = img }
  app.tool = "pencil"
  app.refresh()
  return true
end

-- Pick a tile from the library. Resets rotation and mirroring.
function Stamp.pick(tile, entry, label)
  state.tile = tile
  state.current = tile
  state.palette = entry.palette
  state.tIndex = entry.transparentColor or 0
  state.rotation = 0
  state.flipH = false
  state.flipV = false
  state.label = label or ""
  return Stamp.apply()
end

-- Quarter turns: 1 = 90 degrees clockwise (right), -1 = counterclockwise (left).
function Stamp.rotate(quarterTurns)
  if not state.current then return false end
  for _ = 1, quarterTurns % 4 do state.current = Stamp.rotateCW(state.current) end
  state.rotation = (state.rotation + quarterTurns) % 4
  return Stamp.apply()
end

-- Mirror on the screen axes, as the ghost under the cursor looks now.
function Stamp.mirror(horizontal)
  if not state.current then return false end
  if horizontal then
    state.current = Stamp.mirrorH(state.current)
    state.flipH = not state.flipH
  else
    state.current = Stamp.mirrorV(state.current)
    state.flipV = not state.flipV
  end
  return Stamp.apply()
end

-- Back to the tile as stored.
function Stamp.reset()
  if not state.tile then return false end
  state.current = state.tile
  state.rotation, state.flipH, state.flipV = 0, false, false
  return Stamp.apply()
end

function Stamp.clear()
  state.tile, state.current = nil, nil
end

return Stamp
