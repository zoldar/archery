local li = love.image
local lg = love.graphics
local lk = love.keyboard
local lm = love.math
local lw = love.window
local push = require("lib/push/push")
local b = require("lib/batteries")
local d = require("lib/drawing")
local Crosshair = require("crosshair")

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
    score = 0,
    lastHit = 0
  },
  player2 = {
    type = "cpu",
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

local time
local timer
local assets
local colors
local areas
local targets
local game
local crosshair
local bus

push:setupScreen(
  GAME_WIDTH, GAME_HEIGHT,
  WINDOW_SIDE * 0.4, WINDOW_SIDE * 0.4,
  {
    fullscreen = false,
    resizable = true,
    pixelperfect = true
  }
)

local function color(br, bg, bb)
  local red, green, blue = lm.colorFromBytes(br, bg, bb)
  return { red, green, blue }
end

local function reset()
  time = 0
  timer = b.timer(nil, nil)
  game = b.table.deep_copy(NEW_GAME)
  game.state = "starting_game"

  crosshair = Crosshair:new(colors, GAME_WIDTH, GAME_HEIGHT)
end

function love.load()
  bus = b.pubsub()

  assets = {
    font = lg.newImageFont("assets/tinyfontsheet.png",
      " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ:;.,=+-/\\\"*^%><?()[]&_|'!{}$#@"
    ),
    title = lg.newImage("assets/title.png"),
    track = lg.newImage("assets/track.png"),
    player = lg.newImage("assets/player.png"),
    cpu = lg.newImage("assets/cpu.png"),
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

  colors = {
    dark = color(50, 60, 57),
    light = color(238, 195, 154),
    hit1 = color(17, 17, 17),
    hit2 = color(34, 34, 34),
    hit3 = color(51, 51, 51),
    hit4 = color(68, 68, 68),
    hit5 = color(85, 85, 85),
    hit6 = color(102, 102, 102),
  }

  areas = {
    hit1 = { points = 10 },
    hit2 = { points = 9 },
    hit3 = { points = 7 },
    hit4 = { points = 5 },
    hit5 = { points = 3 },
    hit6 = { points = 1 },
    miss = { points = 0 },
  }

  bus:subscribe("arrow_shot", function(position, area)
    crosshair:setTarget(nil)
    game.state = "shooting"
    game.hitPosition = position
    local points = areas[area].points
    game[game.turn].score = game[game.turn].score + points
    game[game.turn].lastHit = points
    game.arrows = game.arrows - 1
  end)

  reset()
  game.state = "intro"
end

local function setWind()
  game.wind.angle = lm.random(360)
  game.wind.strength = b.math.to_precision(lm.random(10, MAX_WIND) / 10, 1)
  local angle = math.rad(game.wind.angle)
  local windVector = b.vec2():polar(game.wind.strength, angle)
  crosshair:setWind(windVector)
end

function love.update(dt)
  if game.paused then
    return
  end

  time = time + dt

  timer:update(dt)

  crosshair:update(dt, time, bus)

  if game.state == "starting_round" and timer:expired() then
    timer = b.timer(1, nil, function()
      game.state = "starting_turn"
      game.target = targets[game.round]
    end)
  end

  if game.state == "starting_turn" and timer:expired() then
    timer = b.timer(1, nil, function()
      setWind()
      game.state = "aiming"
      crosshair:setTarget(targets[game.round])
      crosshair:spawn()
    end)
  end

  if game.state == "shooting" and game.arrows > 0 and timer:expired() then
    timer = b.timer(1, nil, function()
      setWind()
      game.hitPosition = nil
      game.state = "aiming"
      crosshair:setTarget(targets[game.round])
      crosshair:spawn()
    end)
  end

  if game.state == "shooting" and game.arrows == 0 and timer:expired() then
    timer = b.timer(1, nil, function()
      game.hitPosition = nil
      game.arrows = ARROWS
      game.turn = game.turn == "player1" and "player2" or "player1"
      if game.turn == "player1" then
        if game.round == ROUNDS then
          game.state = "showing_final_score"
        else
          game.state = "starting_round"
          game.round = game.round + 1
          game.target = targets[game.round]
        end
      else
        game.state = "starting_turn"
      end
    end)
  end
end

function love.keypressed(key)
  if game.state == "showing_final_score" and key == "space" then
    reset()
    return
  end

  if game.state == "intro" and key == "space" then
    game.state = "help"
    return
  end

  if game.state == "help" and key == "space" then
    game.state = "starting_round"
    return
  end

  if game.state == "starting_game" and key == "space" then
    game.state = "starting_round"
    return
  end

  if game.paused and (key == "esc" or key == "q") then
    reset()
    game.state = "intro"
    return
  elseif game.paused and (key == "p" or key == "space") then
    game.paused = false
    return
  end

  if not game.paused and (key == "p" or key == "esc" or key == "q") then
    game.paused = true
    return
  end

  crosshair:keypressed(bus, key)
end

function love.resize(w, h)
  push:resize(w, h)
end

local function drawDialog(text, x, y, padding)
  padding = padding or 2
  local textWidth = assets.font:getWidth(text)
  local textHeight = assets.font:getHeight(text)
  x = x == "center" and 40 - (textWidth / 2) or x + padding
  lg.setColor(colors.light)
  d.rectangle(
    "fill",
    x - padding,
    y,
    textWidth + 2 * padding,
    textHeight + 2 * padding + 1
  )
  lg.setColor(colors.dark)
  d.rectangle(
    "line",
    x - padding,
    y,
    textWidth + 2 * padding,
    textHeight + 2 * padding + 1
  )
  lg.print(text, x, y + padding)
end

function love.draw()
  local w, h = push:getDimensions()
  push:start()

  lg.setColor(colors.light)
  lg.rectangle("fill", 0, 0, w, h)
  lg.setColor(1, 1, 1)

  if game.state == "intro" then
    lg.draw(assets.title, 2, 2)
    local text = "PRESS SPACE"
    local textWidth = assets.font:getWidth(text)
    lg.setColor(colors.dark)
    lg.print(text, 40 - textWidth / 2, 35)
  elseif game.state == "help" then
    lg.setColor(colors.dark)
    lg.print("* ARROWS OR WASD", 7, 3)
    lg.print("TO MOVE", 14, 3 + 7)
    lg.print("* SPACE TO SHOOT", 7, 3 + 2 * 7)
    lg.print("* P TO PAUSE", 7, 3 + 3 * 7)
    lg.print("* MIND THE WIND!", 7, 3 + 4 * 7)

    local text = "PRESS SPACE"
    local textWidth = assets.font:getWidth(text)
    lg.setColor(colors.dark)
    lg.print(text, 40 - textWidth / 2, 40)
  else
    -- scene
    lg.draw(assets.track, 0, 13)
    -- target
    if game.target then
      lg.draw(game.target.sprite, game.target.position.x, game.target.position.y)
    end

    if game.hitPosition then
      lg.setColor(colors.light)
      d.circle("fill", game.hitPosition.x, game.hitPosition.y, 2)
      lg.setColor(colors.dark)
      d.circle("line", game.hitPosition.x, game.hitPosition.y, 2)
    end

    -- state independent UI
    lg.setColor(1, 1, 1)
    lg.draw(assets[game.player1.type], 1, 1)
    lg.setColor(colors.dark)
    lg.print(game.player1.score, 9, 1)

    lg.setColor(colors.dark)
    lg.print(game.round .. "/" .. ROUNDS, 23, 1)

    lg.setColor(colors.dark)
    lg.print(game.player2.score, 44, 1)
    lg.setColor(1, 1, 1)
    lg.draw(assets[game.player2.type], 53, 1)

    lg.setColor(colors.dark)
    d.circle("line", 72, 8, 7)
    d.circle("fill", 72, 8, 2)

    if game.arrows > 0 then
      lg.setColor(1, 1, 1)
      for i = 1, game.arrows do
        lg.draw(assets.arrow, 72 - (i - 1) * 7, 40)
      end
    end

    -- state-dependent UI
    if game.state == "starting_game" then
      drawDialog("SPACE TO START", "center", 20)
    end

    if game.state == "aiming" or game.state == "shooting" then
      lg.setColor(1, 1, 1)
      if game.turn == "player1" then
        lg.draw(assets.marker, 18, 1)
      else
        lg.draw(assets.marker, 39, 1, 0, -1, 1)
      end
      lg.setColor(colors.dark)
      lg.print(string.format("%5.1f", game.wind.strength), 61, 16)

      local angle = math.rad(game.wind.angle + lm.random(-6, 6))
      local windIndicator = b.vec2(72, 8) + b.vec2():polar(6, angle)
      lg.setColor(colors.light)
      d.circle("fill", windIndicator.x, windIndicator.y, 2)
      lg.setColor(colors.dark)
      d.circle("line", windIndicator.x, windIndicator.y, 2)
    end

    if game.state == "shooting" then
      local lastHit = game[game.turn].lastHit
      lg.setColor(colors.dark)
      if lastHit == 10 then
        drawDialog("BULLSEYE!", "center", 39, 1)
      elseif lastHit > 0 then
        drawDialog("SCORED " .. lastHit, "center", 39, 1)
      else
        drawDialog("MISSED", "center", 39, 1)
      end
    end

    if game.state == "starting_round" then
      drawDialog("ROUND " .. game.round, "center", 20)
    end

    if game.state == "starting_turn" then
      local playerType = string.upper(game[game.turn].type)
      drawDialog(playerType .. " TURN", "center", 20)
    end

    if game.state == "showing_final_score" then
      if game.player1.score > game.player2.score then
        drawDialog(string.upper(game.player1.type) .. " WON", "center", 20)
      elseif game.player1.score < game.player2.score then
        drawDialog(string.upper(game.player2.type) .. " WON", "center", 20)
      else
        drawDialog("TIE!", "center", 20)
      end
    end

    -- crosshair
    crosshair:draw()

    if game.paused then
      drawDialog("GAME PAUSED", "center", 13)
      drawDialog("PRESS Q TO RESTART", "center", 25)
    end
  end

  push:finish()
end
