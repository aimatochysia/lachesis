-- Lachesis: flatten a frame into an image and write it as a PNG,
-- keeping each file under the configured size cap.

local Capture = {}

-- Flattened image of the visible layers of one frame.
function Capture.flatten(sprite, frameNumber)
  local img = Image(sprite.spec)
  img:drawSprite(sprite, frameNumber)
  return img
end

function Capture.same(a, b)
  if a == nil or b == nil then return false end
  if a.width ~= b.width or a.height ~= b.height or a.colorMode ~= b.colorMode then
    return false
  end
  return a:isEqual(b)
end

-- Nearest-neighbor downscale by a whole number, keeps pixel art crisp.
local function downscale(img, k)
  local w = math.max(1, img.width // k)
  local h = math.max(1, img.height // k)
  local ok, out = pcall(function()
    local c = img:clone()
    c:resize{ width = w, height = h, method = "nearest" }
    return c
  end)
  if ok and out and out.width == w then return out end

  out = Image(w, h, img.colorMode)
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      out:drawPixel(x, y, img:getPixel(x * k, y * k))
    end
  end
  return out
end

local function bytesPerPixel(img)
  if img.colorMode == ColorMode.RGB then return 4 end
  if img.colorMode == ColorMode.GRAY then return 2 end
  return 1
end

local function save(img, path, palette)
  if palette and img.colorMode == ColorMode.INDEXED then
    img:saveAs{ filename = path, palette = palette }
  else
    img:saveAs(path)
  end
end

-- Pick the smallest whole-number downscale whose PNG fits in maxBytes.
-- Images whose raw pixels already fit can't exceed it, so they skip the probe.
local function chooseScale(img, maxBytes, palette)
  if img.width * img.height * bytesPerPixel(img) <= maxBytes then
    return 1, img
  end
  local probe = app.fs.joinPath(app.fs.tempPath, "lachesis-probe.png")
  local k = 1
  local candidate = img
  while true do
    save(candidate, probe, palette)
    local size = app.fs.fileSize(probe) or 0
    if size <= maxBytes or candidate.width <= 1 or candidate.height <= 1 then
      return k, candidate
    end
    k = k + 1
    candidate = downscale(img, k)
  end
end

-- Write img into the snapshot folder. pathFor(scale) returns the file path.
-- Returns the path written and the downscale used.
function Capture.write(img, pathFor, maxBytes, palette)
  local k, final = chooseScale(img, maxBytes, palette)
  local path = pathFor(k)
  save(final, path, palette)
  return path, k
end

return Capture
