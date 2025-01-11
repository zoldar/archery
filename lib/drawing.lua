local _M = {}

local lg = love.graphics

function _M.line(x0, y0, x1, y1)
  local dx = math.abs(x1 - x0)
  local sx = x0 < x1 and 1 or -1
  local dy = -math.abs(y1 - y0)
  local sy = y0 < y1 and 1 or -1
  local error = dx + dy

  while true do
    lg.points(x0, y0)

    if x0 == x1 and y0 == y1 then
      break
    end

    local e2 = 2 * error

    if e2 >= dy then
      error = error + dy
      x0 = x0 + sx
    end
    if e2 <= dx then
      error = error + dx
      y0 = y0 + sy
    end
  end
end

function _M.circle(type, mx, my, r)
  r = r - 1
  local x, y = r, 0
  local t1 = r / 16
  while x >= y do
    local points = {
      { mx + x, my - y },
      { mx + x, my + y },

      { mx - x, my - y },
      { mx - x, my + y },

      { mx + y, my - x },
      { mx + y, my + x },

      { mx - y, my - x },
      { mx - y, my + x }
    }

    if type == "fill" then
      local n = 1
      while n < #points do
        local px = points[n][1]
        local py1 = points[n][2]
        local py2 = points[n + 1][2]

        for py = py1, py2 do
          lg.points(px, py)
        end

        n = n + 2
      end
    else
      lg.points(points)
    end
    y = y + 1
    t1 = t1 + y
    local t2 = t1 - x
    if t2 >= 0 then
      t1 = t2
      x = x - 1
    end
  end
end

function _M.rectangle(type, x, y, w, h)
  for cy = y, y + h do
    if cy == y or cy == y + h or type == "fill" then
      for cx = x, x + w do
        lg.points(cx, cy)
      end
    else
      lg.points(x, cy, x + w, cy)
    end
  end
end

return _M
