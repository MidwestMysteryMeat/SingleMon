-- scenes/title.lua  Title screen with New Game / Continue / Quit.
local Title = {}

local options   = { "New Game", "Continue", "Quit" }
local cursor    = 1
local hasSave   = false
local W, H

local function menuY(i) return H * 0.55 + (i-1) * 38 end

function Title.enter()
  W, H = love.graphics.getDimensions()
  hasSave = SAVE.exists()
end

function Title.draw()
  W, H = love.graphics.getDimensions()
  love.graphics.setBackgroundColor(0.08, 0.04, 0.14)
  love.graphics.clear()

  -- Title
  love.graphics.setColor(0.95, 0.85, 0.30)
  love.graphics.printf("S I N G L E M O N", 0, H * 0.22, W, "center")
  love.graphics.setColor(0.70, 0.60, 0.90)
  love.graphics.printf("Catch. Bond. Evolve.", 0, H * 0.34, W, "center")

  -- Menu
  for i, label in ipairs(options) do
    local grayed = (label == "Continue" and not hasSave)
    if grayed then
      love.graphics.setColor(0.35, 0.30, 0.45)
    elseif cursor == i then
      love.graphics.setColor(1, 1, 0.4)
    else
      love.graphics.setColor(0.80, 0.80, 0.90)
    end
    local prefix = cursor == i and "> " or "  "
    love.graphics.printf(prefix .. label, 0, menuY(i), W, "center")
  end

  -- Footer
  love.graphics.setColor(0.40, 0.35, 0.55)
  love.graphics.printf("Arrow keys / WASD to navigate  •  Enter to select", 0, H - 30, W, "center")
end

function Title.keypressed(k)
  if k == "up" or k == "w" then
    cursor = (cursor - 2) % #options + 1
  elseif k == "down" or k == "s" then
    cursor = cursor % #options + 1
  elseif k == "return" or k == "space" then
    local choice = options[cursor]
    if choice == "New Game" then
      gotoScene("select_starter")
    elseif choice == "Continue" then
      if hasSave then
        local ok, err = GS.load()
        if ok then gotoScene("overworld") else
          -- corrupted save — fall through to new game
          print("[title] Load failed:", err)
          gotoScene("select_starter")
        end
      end
    elseif choice == "Quit" then
      love.event.quit()
    end
  end
end

function Title.exit() end
function Title.update() end

return Title
