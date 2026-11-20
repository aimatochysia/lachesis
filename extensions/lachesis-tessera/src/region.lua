-- Lachesis Tessera: which part of the sprite is previewed.
--
-- The region follows the selection. When nothing is selected, the last
-- selected region of that sprite is used, and the whole canvas when there
-- never was a selection. Nothing is written to the sprite.

local Region = {}

-- Last non-empty selection per sprite, kept in memory only.
local remembered = {}

local function spriteKey(sprite)
  return sprite.filename or ""
end

local function clip(r, sprite)
  local x1 = math.max(0, r.x)
  local y1 = math.max(0, r.y)
  local x2 = math.min(sprite.width, r.x + r.width)
  local y2 = math.min(sprite.height, r.y + r.height)
  if x2 <= x1 or y2 <= y1 then return nil end
  return Rectangle(x1, y1, x2 - x1, y2 - y1)
end

-- Rectangle to preview for this sprite (never nil for a valid sprite).
function Region.current(sprite)
  local key = spriteKey(sprite)
  local sel = sprite.selection
  if sel and not sel.isEmpty then
    local r = clip(sel.bounds, sprite)
    if r then
      remembered[key] = Rectangle(r)
      return r
    end
  end
  local last = remembered[key]
  if last then
    local r = clip(last, sprite)
    if r then return r end
  end
  return Rectangle(0, 0, sprite.width, sprite.height)
end

function Region.forget()
  remembered = {}
end

return Region
