local b = require("lib/batteries")

CPUPlayer = {}

function CPUPlayer:new()
  local state = {
    targetCenters = {
      b.vec2(39, 23),
      b.vec2(16, 17),
      b.vec2(56, 14)
    },
    time = 0
  }
  self.__index = self
  return setmetatable(state, self)
end

function CPUPlayer:update(dt, game, crosshair)
  self.time = self.time + dt

  if game[game.turn].type == "cpu" and crosshair.target then
    self:_aimAndShoot(game, crosshair)
  else
    crosshair:release("left")
    crosshair:release("right")
    crosshair:release("up")
    crosshair:release("down")
    crosshair:release("shoot")
    self.time = 0
  end
end

function CPUPlayer:_aimAndShoot(game, crosshair)
  local target = self.targetCenters[game.round]
  local windVector = b.vec2():polar(game.wind.strength, math.rad(game.wind.angle))
  local correctTarget = target - windVector

  local direction = correctTarget - crosshair.position

  if direction.x > 0 then
    crosshair:push("right")
    crosshair:release("left")
  elseif direction.x < 0 then
    crosshair:release("right")
    crosshair:push("left")
  else
    crosshair:release("right")
    crosshair:release("left")
  end

  if direction.y > 0 then
    crosshair:release("up")
    crosshair:push("down")
  elseif direction.y < 0 then
    crosshair:push("up")
    crosshair:release("down")
  else
    crosshair:release("up")
    crosshair:release("down")
  end

  if direction:length() < 1 then
    crosshair:push("shoot")
  end
end

return CPUPlayer
