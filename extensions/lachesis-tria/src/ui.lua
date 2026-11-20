-- Lachesis Tria: small drawing helpers shared by the dialogs.

local UI = {}

UI.MAX_CELL = 64

-- Size of one tile cell on screen, keeping pixels square.
function UI.cellSize(w, h)
  local zoom = math.max(1, math.min(4, 40 // math.max(w, h)))
  local cw, ch = w * zoom, h * zoom
  local biggest = math.max(cw, ch)
  if biggest > UI.MAX_CELL then
    cw = math.max(1, cw * UI.MAX_CELL // biggest)
    ch = math.max(1, ch * UI.MAX_CELL // biggest)
  end
  return cw, ch
end

-- Gray checkerboard behind transparent pixels.
function UI.drawChecker(gc, x, y, w, h)
  gc.color = Color{ r = 204, g = 204, b = 204 }
  gc:fillRect(Rectangle(x, y, w, h))
  gc.color = Color{ r = 153, g = 153, b = 153 }
  local s = 8
  for cy = 0, h - 1, s do
    for cx = 0, w - 1, s do
      if ((cx // s) + (cy // s)) % 2 == 1 then
        gc:fillRect(Rectangle(x + cx, y + cy, math.min(s, w - cx), math.min(s, h - cy)))
      end
    end
  end
end

return UI
