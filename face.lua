local lg = love.graphics
local lm = love.math
local b = require("lib/batteries")

STATES = {
  idling = {
    frames = { "left", "front", "right" },
    duration = { 1000, 1600 },
  },
  neutral = {
    frames = { "neutral" },
    duration = 1000,
  },
  surprised = {
    frames = { "ooh" },
    duration = 1000
  },
  smiling = {
    frames = { "smile" },
    duration = 1000
  },
  sad = {
    frames = { "sad" },
    duration = 1000
  }
}

local function createState(state, name, frames, duration)
  state.machine:add_state(name, {
    enter = function()
      state.time = 0
      state.frame = state.type .. "_" .. b.table.pick_random(frames)
      if type(duration) == "table" then
        state.duration = lm.random(duration[1], duration[2])
      else
        state.duration = duration
      end
    end,
    update = function()
      if state.time >= state.duration / 1000 then
        return "idling"
      end
    end,
    draw = function(_states)
      lg.draw(state.assets[state.frame], state.position.x, state.position.y)
    end
  })

  return state
end

local function setupMachine(state)
  for name, params in pairs(STATES) do
    createState(state, name, params.frames, params.duration)
  end
end

local Face = {}

function Face:new(assets, player, type)
  local position = player == "player1" and b.vec2(1, 1) or b.vec2(53, 1)
  local state = {
    position = position,
    assets = assets,
    type = type,
    time = 0,
    duration = 800,
    frame = type .. "_front",
    machine = b.state_machine()
  }
  setupMachine(state)
  state.machine:set_state("idling")
  self.__index = self
  return setmetatable(state, self)
end

function Face:update(dt)
  self.time = self.time + dt

  self.machine:update()
end

function Face:draw()
  lg.setColor(1, 1, 1)
  self.machine:draw()
end

function Face:set(mood)
  self.machine:set_state(mood)
end

return Face
