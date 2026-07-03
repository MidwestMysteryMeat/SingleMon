-- main.lua  SingleMon entry point.
local cfg = require("config")

-- Mount an optional external sprite directory as 'assets/' in our virtual filesystem.
-- If the path is wrong, update config.lua → assetPath.
if not love.filesystem.mount(cfg.assetPath, "assets") then
  print("[WARN] Could not mount assets from: " .. cfg.assetPath)
end

-- Globals: set before any scene requires engine modules
DATA    = require("engine.data")
GS      = require("engine.game_state")
BATTLE  = require("engine.battle")
SAVE    = require("engine.save")

-- Scene router (simple replace, no stack — add a stack if needed later)
local scenes = {
  title          = require("scenes.title"),
  select_starter = require("scenes.select_starter"),
  overworld      = require("scenes.overworld"),
  battle         = require("scenes.battle"),
  party          = require("scenes.party"),
}

local _current = nil

function gotoScene(name, params)
  if _current and _current.exit then _current.exit() end
  _current = scenes[name]
  assert(_current, "Unknown scene: " .. name)
  if _current.enter then _current.enter(params or {}) end
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  gotoScene("title")
end

function love.update(dt)
  if _current and _current.update then _current.update(dt) end
end

function love.draw()
  if _current and _current.draw then _current.draw() end
end

function love.keypressed(k, sc, rep)
  if _current and _current.keypressed then _current.keypressed(k, sc, rep) end
end

function love.keyreleased(k)
  if _current and _current.keyreleased then _current.keyreleased(k) end
end

function love.textinput(t)
  if _current and _current.textinput then _current.textinput(t) end
end

function love.mousepressed(x, y, btn)
  if _current and _current.mousepressed then _current.mousepressed(x, y, btn) end
end
