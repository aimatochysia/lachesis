-- Lachesis Tessera: turn a region of the sprite into a display tile.
--
-- All visible layers of one frame are flattened into a new image, exactly as
-- the canvas shows them. The result is always RGB so it can be drawn on a
-- dialog canvas. The sprite itself is only read.

local Render = {}

local pc = app.pixelColor

local function toRGB(img, sprite)
  local mode = img.colorMode
  if mode == ColorMode.RGB then return img end
  local out = Image(img.width, img.height, ColorMode.RGB)
  if mode == ColorMode.INDEXED then
    local pal = sprite.palettes[1]
    local tIndex = sprite.transparentColor or 0
    local lut = {}
    for i = 0, #pal - 1 do
      local c = pal:getColor(i)
      lut[i] = pc.rgba(c.red, c.green, c.blue, c.alpha)
    end
    lut[tIndex] = 0
    for it in img:pixels() do
      local v = lut[it()] or 0
      if v ~= 0 then out:drawPixel(it.x, it.y, v) end
    end
  else -- GRAY
    for it in img:pixels() do
      local v = it()
      local a = pc.grayaA(v)
      if a ~= 0 then
        local g = pc.grayaV(v)
        out:drawPixel(it.x, it.y, pc.rgba(g, g, g, a))
      end
    end
  end
  return out
end

-- Flattened RGB image of rect at frameNumber.
function Render.tile(sprite, frameNumber, rect)
  local spec = ImageSpec{
    width = rect.width,
    height = rect.height,
    colorMode = sprite.colorMode,
    transparentColor = sprite.transparentColor,
  }
  local img = Image(spec)
  img:drawSprite(sprite, frameNumber, Point(-rect.x, -rect.y))
  return toRGB(img, sprite)
end

-- Nearest-neighbour scaled copy (scale may be below 1 for big regions).
function Render.scaled(img, scale)
  if scale == 1 then return img end
  local w = math.max(1, math.floor(img.width * scale + 0.5))
  local h = math.max(1, math.floor(img.height * scale + 0.5))
  local out = img:clone()
  out:resize{ width = w, height = h, method = "nearest" }
  return out
end

-- Columns and rows for a repeat mode and tile count.
function Render.grid(repeatMode, tiles)
  if repeatMode == "x" then return tiles, 1 end
  if repeatMode == "y" then return 1, tiles end
  return tiles, tiles
end

-- Scale that makes the whole grid fit in w x h: whole numbers when it fits
-- at 1x or more, a fraction otherwise.
function Render.fitScale(tileW, tileH, cols, rows, w, h)
  local s = math.min(w / (tileW * cols), h / (tileH * rows))
  if s >= 1 then return math.floor(s) end
  return s
end

return Render
