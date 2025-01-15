local li = love.image
local lg = love.graphics
local lm = love.math
local lw = love.window
local push = require("lib/push/push")
local b = require("lib/batteries")
local d = require("lib/drawing")
local Crosshair = require("crosshair")
local CPUPlayer = require("cpu")
local Face = require("face")

lg.setDefaultFilter("nearest", "nearest")

GAME_WIDTH, GAME_HEIGHT = 80, 48
WINDOW_SIDE = math.min(lw.getDesktopDimensions())

ARROWS = 3
ROUNDS = 3
MAX_WIND = 60

-- states:
-- * intro
-- * help
-- * starting_game
-- * starting_round
-- * starting_turn
-- * aiming
-- * shooting
-- * showing_final_score
NEW_GAME = {
  state = "intro",
  paused = false,
  turn = "player1",
  target = nil,
  player1 = {
    type = "player",
    face = nil,
    score = 0,
    lastHit = 0
  },
  player2 = {
    type = "cpu",
    face = nil,
    score = 0,
    lastHit = 0
  },
  wind = {
    angle = 0,
    strength = 0
  },
  hitPosition = nil,
  arrows = ARROWS,
  round = 1
}

COLORS = {
  dark = d.color(50, 60, 57),
  light = d.color(238, 195, 154),
  hit1 = d.color(17, 17, 17),
  hit2 = d.color(34, 34, 34),
  hit3 = d.color(51, 51, 51),
  hit4 = d.color(68, 68, 68),
  hit5 = d.color(85, 85, 85),
  hit6 = d.color(102, 102, 102),
}

AREAS = {
  hit1 = { points = 10 },
  hit2 = { points = 9 },
  hit3 = { points = 7 },
  hit4 = { points = 5 },
  hit5 = { points = 3 },
  hit6 = { points = 1 },
  miss = { points = 0 },
}

local time
local timer
local assets
local targets
local game
local crosshair
local bus
local cpu

push:setupScreen(
  GAME_WIDTH, GAME_HEIGHT,
  WINDOW_SIDE * 0.4, WINDOW_SIDE * 0.4,
  {
    fullscreen = false,
    resizable = true,
    pixelperfect = true
  }
)

local function loadAssets()
  assets = {
    font = lg.newImageFont("assets/tinyfontsheet.png",
      " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ:;.,=+-/\\\"*^%><?()[]&_|'!{}$#@"
    ),
    title = lg.newImage("assets/title.png"),
    track = lg.newImage("assets/track.png"),
    player_front = lg.newImage("assets/player-front.png"),
    player_left = lg.newImage("assets/player-left.png"),
    player_right = lg.newImage("assets/player-right.png"),
    player_neutral = lg.newImage("assets/player-neutral.png"),
    player_ooh = lg.newImage("assets/player-ooh.png"),
    player_smile = lg.newImage("assets/player-smile.png"),
    player_sad = lg.newImage("assets/player-sad.png"),
    cpu_front = lg.newImage("assets/cpu-front.png"),
    cpu_left = lg.newImage("assets/cpu-left.png"),
    cpu_right = lg.newImage("assets/cpu-right.png"),
    cpu_neutral = lg.newImage("assets/cpu-neutral.png"),
    cpu_ooh = lg.newImage("assets/cpu-ooh.png"),
    cpu_smile = lg.newImage("assets/cpu-smile.png"),
    cpu_sad = lg.newImage("assets/cpu-sad.png"),
    arrow = lg.newImage("assets/arrow.png"),
    marker = lg.newImage("assets/marker.png"),
    target1_full = lg.newImage("assets/target1_full.png"),
    target1_data = li.newImageData("assets/target1.png"),
    target2_full = lg.newImage("assets/target2_full.png"),
    target2_data = li.newImageData("assets/target2.png"),
    target3_full = lg.newImage("assets/target3_full.png"),
    target3_data = li.newImageData("assets/target3.png"),
  }

  lg.setFont(assets.font)
end

local function setupTargets()
  targets = {
    {
      position = b.vec2(25, 9),
      offset = b.vec2(3, 3),
      sprite = assets.target1_full,
      data = assets.target1_data,
      spawnBoxes = {
        { position = b.vec2(1, 8),   width = 7, height = 40 },
        { position = b.vec2(70, 21), width = 7, height = 18 }
      }
    },
    {
      position = b.vec2(8, 8),
      offset = b.vec2(1, 2),
      sprite = assets.target2_full,
      data = assets.target2_data,
      spawnBoxes = {
        { position = b.vec2(70, 21), width = 7, height = 18 }
      }
    },
    {
      position = b.vec2(51, 8),
      offset = b.vec2(1, 2),
      sprite = assets.target3_full,
      data = assets.target3_data,
      spawnBoxes = {
        { position = b.vec2(1, 8), width = 7, height = 40 },
      }
    }
  }
end

local function setWind()
  game.wind.angle = lm.random(360)
  game.wind.strength = b.math.to_precision(lm.random(20, MAX_WIND) / 10, 1)
  local angle = math.rad(game.wind.angle)
  local windVector = b.vec2():polar(game.wind.strength, angle)
  crosshair:setWind(windVector)
end

local function drawScene()
  -- background
  lg.draw(assets.track, 0, 13)
  -- target
  if game.target then
    lg.draw(game.target.sprite, game.target.position.x, game.target.position.y)
  end

  if game.hitPosition then
    lg.setColor(COLORS.light)
    d.circle("fill", game.hitPosition.x, game.hitPosition.y, 2)
    lg.setColor(COLORS.dark)
    d.circle("line", game.hitPosition.x, game.hitPosition.y, 2)
  end

  -- state-machine independent UI
  game.player1.face:draw()
  lg.setColor(COLORS.dark)
  lg.print(game.player1.score, 9, 1)

  lg.setColor(COLORS.dark)
  lg.print(game.round .. "/" .. ROUNDS, 23, 1)

  lg.setColor(COLORS.dark)
  lg.print(game.player2.score, 44, 1)
  game.player2.face:draw()

  lg.setColor(COLORS.dark)
  d.circle("line", 72, 8, 7)
  d.circle("fill", 72, 8, 2)

  if game.arrows > 0 then
    lg.setColor(1, 1, 1)
    for i = 1, game.arrows do
      lg.draw(assets.arrow, 72 - (i - 1) * 7, 40)
    end
  end
end

local function drawDialog(text, x, y, padding)
  padding = padding or 2
  local textWidth = assets.font:getWidth(text)
  local textHeight = assets.font:getHeight(text)
  x = x == "center" and 40 - (textWidth / 2) or x + padding
  lg.setColor(COLORS.light)
  d.rectangle(
    "fill",
    x - padding,
    y,
    textWidth + 2 * padding,
    textHeight + 2 * padding + 1
  )
  lg.setColor(COLORS.dark)
  d.rectangle(
    "line",
    x - padding,
    y,
    textWidth + 2 * padding,
    textHeight + 2 * padding + 1
  )
  lg.print(text, x, y + padding)
end

local function drawMarker()
  lg.setColor(1, 1, 1)
  if game.turn == "player1" then
    lg.draw(assets.marker, 18, 1)
  else
    lg.draw(assets.marker, 39, 1, 0, -1, 1)
  end
end

local function drawWind()
  lg.setColor(COLORS.dark)
  lg.print(string.format("%5.1f", game.wind.strength), 61, 16)

  local angle = math.rad(game.wind.angle + lm.random(-6, 6))
  local windIndicator = b.vec2(72, 8) + b.vec2():polar(6, angle)
  lg.setColor(COLORS.light)
  d.circle("fill", windIndicator.x, windIndicator.y, 2)
  lg.setColor(COLORS.dark)
  d.circle("line", windIndicator.x, windIndicator.y, 2)
end

local function schedule(seconds, func)
  timer = b.timer(seconds, nil, func)
end

-- main state machine

local machine = b.state_machine()

machine:add_state("intro", {
  draw = function()
    lg.draw(assets.title, 2, 2)
    local text = "PRESS SPACE"
    local textWidth = assets.font:getWidth(text)
    lg.setColor(COLORS.dark)
    lg.print(text, 40 - textWidth / 2, 35)
  end
})

machine:add_state("help", {
  draw = function()
    lg.setColor(COLORS.dark)
    lg.print("* ARROWS OR WASD", 7, 3)
    lg.print("TO MOVE", 14, 3 + 7)
    lg.print("* SPACE TO SHOOT", 7, 3 + 2 * 7)
    lg.print("* P TO PAUSE", 7, 3 + 3 * 7)
    lg.print("* MIND THE WIND!", 7, 3 + 4 * 7)

    local text = "PRESS SPACE"
    local textWidth = assets.font:getWidth(text)
    lg.setColor(COLORS.dark)
    lg.print(text, 40 - textWidth / 2, 40)
  end
})

machine:add_state("starting_game", {
  draw = function()
    drawScene()
    drawDialog("SPACE TO START", "center", 20)
  end
})

machine:add_state("starting_round", {
  enter = function()
    game.target = targets[game.round]
    schedule(1, function()
      machine:set_state("starting_turn")
    end)
  end,
  draw = function()
    drawScene()
    drawDialog("ROUND " .. game.round, "center", 20)
  end,
})

machine:add_state("starting_turn", {
  enter = function()
    game.arrows = ARROWS
    schedule(1, function()
      machine:set_state("aiming")
    end)
  end,
  draw = function()
    drawScene()
    drawMarker()
    local playerType = string.upper(game[game.turn].type)
    drawDialog(playerType .. " TURN", "center", 20)
  end
})

machine:add_state("aiming", {
  enter = function()
    setWind()
    crosshair:setTarget(targets[game.round])
    local controlType = game[game.turn].type == "cpu" and "external" or "input"
    crosshair:setControl(controlType)
    crosshair:spawn()

    bus:subscribe_once("arrow_shot", function(position, area)
      game.hitPosition = position
      local points = AREAS[area].points
      game[game.turn].score = game[game.turn].score + points
      game[game.turn].lastHit = points
      game.arrows = game.arrows - 1
      machine:set_state("shooting")
    end)
  end,
  exit = function()
    crosshair:setTarget(nil)
  end,
  draw = function()
    drawScene()
    drawMarker()
    drawWind()
    crosshair:draw()
  end,
  update = function(_states, dt)
    cpu:update(dt, game, crosshair)
  end
})

machine:add_state("shooting", {
  enter = function()
    local nextState = "aiming"

    -- set faces
    local opponent = game.turn == "player1" and "player2" or "player1"
    local shooterMood = "neutral"
    local opponentMood = "idling"
    if game[game.turn].lastHit >= 7 then
      shooterMood = "smiling"
      if game[game.turn].lastHit == 10 then
        opponentMood = "surprised"
      end
    elseif game[game.turn].lastHit <= 2 then
      shooterMood = "sad"
    end

    game[game.turn].face:set(shooterMood)
    game[opponent].face:set(opponentMood)

    if game.arrows == 0 then
      if game.turn == "player2" then
        if game.round == ROUNDS then
          nextState = "showing_final_score"
        else
          nextState = "starting_round"
        end
      else
        nextState = "starting_turn"
      end
    end

    schedule(1, function()
      machine:set_state(nextState)
    end)
  end,
  exit = function()
    game.hitPosition = nil

    if game.arrows == 0 then
      if game.turn == "player2" and game.round < ROUNDS then
        game.round = game.round + 1
      end
      game.turn = game.turn == "player1" and "player2" or "player1"
    end
  end,
  draw = function()
    drawScene()
    drawMarker()
    drawWind()

    local lastHit = game[game.turn].lastHit
    lg.setColor(COLORS.dark)
    if lastHit == 10 then
      drawDialog("BULLSEYE!", "center", 39, 1)
    elseif lastHit > 0 then
      drawDialog("SCORED " .. lastHit, "center", 39, 1)
    else
      drawDialog("MISSED", "center", 39, 1)
    end
  end,
  update = function(_states, dt)
    cpu:update(dt, game, crosshair)
  end
})

machine:add_state("showing_final_score", {
  enter = function()
    -- set faces
    local player1Mood, player2Mood
    if game.player1.score > game.player2.score then
      player1Mood = "smiling"
      player2Mood = "sad"
    elseif game.player1.score < game.player2.score then
      player1Mood = "sad"
      player2Mood = "smiling"
    else
      player1Mood = "surprised"
      player1Mood = "surprised"
    end
    game.player1.face:set(player1Mood)
    game.player2.face:set(player2Mood)
  end,
  draw = function()
    drawScene()

    if game.player1.score > game.player2.score then
      drawDialog(string.upper(game.player1.type) .. " WON", "center", 13)
    elseif game.player1.score < game.player2.score then
      drawDialog(string.upper(game.player2.type) .. " WON", "center", 13)
    else
      drawDialog("TIE!", "center", 13)
    end

    drawDialog("SPACE TO TRY AGAIN", "center", 25)
  end
})

local function reset(starting_state)
  time = 0
  timer = b.timer(nil, nil)
  game = b.table.deep_copy(NEW_GAME)
  machine:set_state(starting_state)

  crosshair = Crosshair:new(COLORS, GAME_WIDTH, GAME_HEIGHT)
  cpu = CPUPlayer:new()
  game.player1.face = Face:new(assets, "player1", game.player1.type)
  game.player2.face = Face:new(assets, "player2", game.player2.type)
end

-- core gameloop

function love.load()
  bus = b.pubsub()

  loadAssets()
  setupTargets()

  reset("intro")
end

function love.update(dt)
  if game.paused then
    return
  end

  time = time + dt

  timer:update(dt)

  crosshair:update(dt, time, bus)

  machine:update(dt)
  game.player1.face:update(dt)
  game.player2.face:update(dt)
end

function love.keypressed(key)
  if machine:in_state("showing_final_score") and key == "space" then
    reset("starting_game")
  elseif machine:in_state("intro") and key == "space" then
    machine:set_state("help")
  elseif machine:in_state("help") and key == "space" then
    machine:set_state("starting_round")
  elseif machine:in_state("starting_game") and key == "space" then
    machine:set_state("starting_round")
  elseif game.paused and (key == "esc" or key == "q") then
    reset("intro")
  elseif game.paused and (key == "p" or key == "space") then
    game.paused = false
  elseif not game.paused and (key == "p" or key == "esc" or key == "q") then
    game.paused = true
  else
    crosshair:keypressed(bus, key)
  end
end

function love.resize(w, h)
  push:resize(w, h)
end

function love.draw()
  local w, h = push:getDimensions()
  push:start()

  lg.setColor(COLORS.light)
  lg.rectangle("fill", 0, 0, w, h)
  lg.setColor(1, 1, 1)

  machine:draw()

  if game.paused then
    drawDialog("GAME PAUSED", "center", 13)
    drawDialog("PRESS Q TO RESTART", "center", 25)
  end

  push:finish()
end
