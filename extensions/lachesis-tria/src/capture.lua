-- Lachesis Tria: turn what is visible on the canvas into a list of tiles.
--
-- The visible layers of one frame are flattened, then cut on a grid that
-- starts at (x, y). Partial tiles at the right and bottom edges, fully
-- transparent tiles and exact duplicates are left out.

local Capture = {}

-- Flattened image of the visible layers of one frame, as the canvas shows it.
function Capture.flatten(sprite, frameNumber)
  local img = Image(sprite.spec)
  img:drawSprite(sprite, frameNumber)
  return img
end

-- The pixel value that means "transparent" for an image of this sprite.
function Capture.transparentIndex(sprite)
  if sprite.colorMode == ColorMode.INDEXED then
    return sprite.transparentColor or 0
  end
  return 0
end

-- True when every pixel is transparent.
function Capture.isEmpty(img, tIndex)
  local mode = img.colorMode
  local pc = app.pixelColor
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local v = img:getPixel(x, y)
      if mode == ColorMode.RGB then
        if pc.rgbaA(v) ~= 0 then return false end
      elseif mode == ColorMode.GRAY then
        if pc.grayaA(v) ~= 0 then return false end
      elseif v ~= tIndex then
        return false
      end
    end
  end
  return true
end

-- Copy of a rectangle of img, pixel for pixel (no blending).
function Capture.crop(img, x, y, w, h, tIndex)
  local ok, out = pcall(function() return Image(img, Rectangle(x, y, w, h)) end)
  if ok and out and out.width == w and out.height == h then return out end

  out = Image(w, h, img.colorMode)
  if img.colorMode == ColorMode.INDEXED then out:clear(tIndex) end
  for ty = 0, h - 1 do
    for tx = 0, w - 1 do
      out:drawPixel(tx, ty, img:getPixel(x + tx, y + ty))
    end
  end
  return out
end

-- Number of whole tiles that fit from (x, y) in an image of this size.
function Capture.gridSize(width, height, grid)
  local cols = math.max(0, (width - grid.x) // grid.w)
  local rows = math.max(0, (height - grid.y) // grid.h)
  return cols, rows
end

-- Grid values that make sense for an image of this size, or nil and a reason.
function Capture.validateGrid(width, height, grid)
  if grid.w < 1 or grid.h < 1 then
    return nil, "Tile width and height must be at least 1 pixel."
  end
  if grid.x < 0 or grid.y < 0 then
    return nil, "x and y can't be negative."
  end
  local cols, rows = Capture.gridSize(width, height, grid)
  if cols < 1 or rows < 1 then
    return nil, string.format(
      "No whole %dx%d tile fits in the %dx%d canvas starting at (%d, %d).",
      grid.w, grid.h, width, height, grid.x, grid.y)
  end
  return true
end

-- Cut img into tiles. Returns the kept tiles (each { image, col, row },
-- in reading order) and counts { cells, empty, duplicate }.
function Capture.slice(img, grid, tIndex)
  local cols, rows = Capture.gridSize(img.width, img.height, grid)
  local tiles = {}
  local seen = {}
  local stats = { cells = cols * rows, empty = 0, duplicate = 0 }
  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      local tile = Capture.crop(img, grid.x + col * grid.w, grid.y + row * grid.h,
                                grid.w, grid.h, tIndex)
      if Capture.isEmpty(tile, tIndex) then
        stats.empty = stats.empty + 1
      else
        local key = tile.bytes
        if seen[key] then
          stats.duplicate = stats.duplicate + 1
        else
          seen[key] = true
          tiles[#tiles + 1] = { image = tile, col = col, row = row }
        end
      end
    end
  end
  return tiles, stats
end

-- RGB copy of a tile, for drawing previews of indexed and grayscale tiles.
function Capture.toRGB(img, palette, tIndex)
  if img.colorMode == ColorMode.RGB then return img end
  local pc = app.pixelColor
  local out = Image(img.width, img.height, ColorMode.RGB)
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local v = img:getPixel(x, y)
      local rgba = 0
      if img.colorMode == ColorMode.GRAY then
        local g, a = pc.grayaV(v), pc.grayaA(v)
        rgba = pc.rgba(g, g, g, a)
      elseif v ~= tIndex and palette and v < #palette then
        rgba = palette:getColor(v).rgbaPixel
      end
      out:drawPixel(x, y, rgba)
    end
  end
  return out
end

return Capture
