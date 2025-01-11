local lg = love.graphics
local lk = love.keyboard
local lm = love.math
local b = require("lib/batteries")
local push = require("lib/push/push")

START_JIGGLE = 2
AIM_TIME = 15
MAX_SPEED = 30
ACCELERATION = 30

Crosshair = {}

function Crosshair:new(colors, viewWidth, viewHeight)
  local state = {
    bounds = b.vec2(viewWidth, viewHeight),
    colors = colors,
    position = nil,
    direction = b.vec2(),
    realPosition = b.vec2(),
    wind = b.vec2(),
    target = nil,
    speed = 0,
    jiggle = START_JIGGLE,
    timer = AIM_TIME,
    controlMode = "input", -- input, external
    controls = {
      up = false,
      down = false,
      left = false,
      right = false,
      shoot = false
    }
  }
  self.__index = self
  return setmetatable(state, self)
end

function Crosshair:setTarget(target)
  self.speed = 0
  self.target = target
end

function Crosshair:spawn()
  self.jiggle = START_JIGGLE
  self.timer = AIM_TIME
  local box = b.table.pick_random(self.target.spawnBoxes)
  self.position = box.position + b.vec2(lm.random(box.width), lm.random(box.height))
  self.realPosition = b.vec2(self.position.x, self.position.y)
end

function Crosshair:shoot(bus)
  local position = self.realPosition + self.wind
  local targetPosition = position - self.target.position - self.target.offset
  local x, y = targetPosition.x, targetPosition.y
  local area = "miss"

  if x >= 0 and x < self.target.data:getWidth() and
      y >= 0 and y < self.target.data:getHeight() then
    local _, _, blue, _ = self.target.data:getPixel(targetPosition.x, targetPosition.y)

    for i = 1, 6 do
      if b.math.to_precision(blue, 3) == b.math.to_precision(self.colors["hit" .. i][3], 3) then
        area = "hit" .. i
      end
    end
  end

  bus:publish("arrow_shot", position, area)
end

function Crosshair:setWind(wind)
  self.wind = wind
end

function Crosshair:setControl(mode)
  self.controlMode = mode
end

function Crosshair:push(control)
  self.controls[control] = true
end

function Crosshair:release(control)
  self.controls[control] = false
end

function Crosshair:_pressed(control)
  if self.controlMode == "external" then
    return self.controls[control]
  end

  if control == "up" then
    return lk.isDown("up") or lk.isDown("w")
  end

  if control == "down" then
    return lk.isDown("down") or lk.isDown("s")
  end

  if control == "left" then
    return lk.isDown("left") or lk.isDown("a")
  end

  if control == "right" then
    return lk.isDown("right") or lk.isDown("d")
  end

  if control == "shoot" then
    return lk.isDown("space") or lk.isDown("z")
  end
end

function Crosshair:update(dt, time, bus)
  if not self.position or not self.target then
    return
  end

  self.timer = self.timer - dt

  self.jiggle = START_JIGGLE + (AIM_TIME - self.timer) / 3

  local direction = b.vec2()

  if self:_pressed("up") then
    direction.y = direction.y - 1
  end

  if self:_pressed("down") then
    direction.y = direction.y + 1
  end

  if self:_pressed("left") then
    direction.x = direction.x - 1
  end

  if self:_pressed("right") then
    direction.x = direction.x + 1
  end

  if self:_pressed("shoot") or self.timer < 0 then
    self:shoot(bus)
  end

  direction:normalise_inplace()

  if direction:length() > 0 then
    self.direction = direction
  end

  local sign = direction:length() > 0 and 1 or -1

  self.speed = b.math.clamp(self.speed + sign * ACCELERATION * dt, 0, MAX_SPEED)

  self.position = (
    self.position +
    self.direction * self.speed * dt
  ):clamp_inplace(b.vec2(), self.bounds)

  if math.sin(math.pi * time * 15) > 0 then
    local jiggleVector = self.position + b.vec2(
      lm.random(-self.jiggle, self.jiggle),
      lm.random(-self.jiggle, self.jiggle)
    )
    self.realPosition:lerp_inplace(jiggleVector, 0.2)
  else
    self.realPosition:lerp_inplace(self.position, 0.2)
  end
end

function Crosshair:keypressed(bus, key)
  if not self.position or not self.target then
    return
  end

  if self:_pressed("shoot") then
    self:shoot(bus)
  end
end

local function toImage(image, x, y)
  local scaled = {
    x = image:getWidth() * x / push:getWidth(),
    y = image:getHeight() * y / push:getHeight()
  }
  return scaled.x, scaled.y
end

local function getPixel(x, y)
  local canvas = push:getCanvasTable(nil).canvas
  lg.setCanvas()
  local canvasImage = canvas:newImageData()
  lg.setCanvas(canvas)
  local rx, ry = toImage(canvasImage, x, y)

  if rx >= 0 and rx < canvasImage:getWidth() and
      ry >= 0 and ry < canvasImage:getHeight() then
    return canvasImage:getPixel(rx, ry)
  else
    return 0, 0, 0, 0
  end
end

local function swapColor(colors, x, y)
  local _, _, blue, _ = getPixel(x, y)
  local color
  if b.math.to_precision(blue, 1) == b.math.to_precision(colors.dark[3], 1) then
    color = colors.light
  else
    color = colors.dark
  end

  lg.points({ { x, y, color[1], color[2], color[3] } })
end

function Crosshair:draw()
  if not self.position or not self.target then
    return
  end

  local drawPosition = self.realPosition
  for dx = -3, 3 do
    if dx == 0 then
      lg.setColor(self.colors.light)
      swapColor(
        self.colors,
        drawPosition.x + dx,
        drawPosition.y
      )
    else
      lg.setColor(self.colors.dark)
      lg.points(
        drawPosition.x + dx,
        drawPosition.y
      )
    end
  end
  for dy = -3, 3 do
    if dy ~= 0 then
      lg.setColor(self.colors.dark)
      lg.points(
        drawPosition.x,
        drawPosition.y + dy
      )
    end
  end

  lg.print("" .. math.ceil(self.timer), self.position.x + 3, self.position.y + 3)
end

return Crosshair
