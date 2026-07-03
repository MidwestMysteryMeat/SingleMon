-- scenes/select_starter.lua
-- Player picks a name, a run mode, and one of three starter species.
local Creatures = require("engine.creatures")
local SS        = {}

local STARTERS = { "emberfox", "tidelet", "graycub" }
local imgs     = {}

local MODES = {
  { id='normal',   label='Normal',   desc='Standard adventure. No restrictions.' },
  { id='nuzlocke', label='Nuzlocke', desc='Permadeath. One wild encounter per route.' },
  { id='hardcore', label='Hardcore', desc='Permadeath. No items in battle. No legendary catches.' },
  { id='monlocke', label='Monlocke', desc='Permadeath. Solo run — one Riftborn only.' },
}

local cursor    = 1
local modeCursor = 1
local playerName = "Red"
local nameBuffer = ""
local phase      = "name"  -- "name" | "mode" | "pick"
local W, H

local MODE_COLOR = {
  normal   = {0.45, 0.75, 0.45},
  nuzlocke = {0.90, 0.75, 0.25},
  hardcore = {0.90, 0.35, 0.25},
  monlocke = {0.65, 0.35, 0.90},
}

local function loadImg(speciesId)
  if imgs[speciesId] then return end
  local sp = DATA.species[speciesId]
  if not sp then return end
  local ok, img = pcall(love.graphics.newImage, sp.sprite)
  imgs[speciesId] = ok and img or nil
end

function SS.enter()
  W, H         = love.graphics.getDimensions()
  cursor       = 1
  modeCursor   = 1
  phase        = "name"
  nameBuffer   = ""
  for _, sid in ipairs(STARTERS) do loadImg(sid) end
end

local function drawSprite(img, frame, x, y, sc)
  if not img then return end
  local fw = math.floor(img:getWidth() / 3)
  local fh = img:getHeight()
  local q  = love.graphics.newQuad(fw * frame, 0, fw, fh, img:getDimensions())
  love.graphics.draw(img, q, x, y, 0, sc, sc, fw/2, fh/2)
end

function SS.draw()
  W, H = love.graphics.getDimensions()
  love.graphics.setBackgroundColor(0.08, 0.06, 0.18)
  love.graphics.clear()

  -- ── Name entry ────────────────────────────────────────────────────────────
  if phase == "name" then
    love.graphics.setColor(0.90, 0.85, 1.0)
    love.graphics.printf("Enter your name:", 0, H*0.30, W, "center")
    love.graphics.setColor(1, 1, 0.5)
    love.graphics.printf(nameBuffer .. "_", 0, H*0.42, W, "center")
    love.graphics.setColor(0.55, 0.50, 0.70)
    love.graphics.printf("Type your name then press Enter", 0, H*0.60, W, "center")
    return
  end

  -- ── Mode select ───────────────────────────────────────────────────────────
  if phase == "mode" then
    love.graphics.setColor(0.90, 0.85, 1.0)
    love.graphics.printf("Choose your run mode", 0, H*0.08, W, "center")
    love.graphics.setColor(0.45, 0.40, 0.60)
    love.graphics.printf("Tamer "..playerName, 0, H*0.14, W, "center")

    local boxW = math.min(W - 80, 480)
    local boxX = (W - boxW) / 2

    for i, m in ipairs(MODES) do
      local by  = H*0.24 + (i-1) * 70
      local sel = (modeCursor == i)
      local mc  = MODE_COLOR[m.id] or {0.7,0.7,0.7}

      if sel then
        love.graphics.setColor(mc[1]*0.3, mc[2]*0.3, mc[3]*0.3)
        love.graphics.rectangle("fill", boxX, by, boxW, 58, 6,6)
        love.graphics.setColor(mc[1], mc[2], mc[3])
        love.graphics.rectangle("line", boxX, by, boxW, 58, 6,6)
      else
        love.graphics.setColor(0.12, 0.10, 0.22)
        love.graphics.rectangle("fill", boxX, by, boxW, 58, 6,6)
        love.graphics.setColor(0.25, 0.22, 0.40)
        love.graphics.rectangle("line", boxX, by, boxW, 58, 6,6)
      end

      love.graphics.setColor(sel and mc or {0.80, 0.78, 0.95})
      love.graphics.print(m.label, boxX + 14, by + 8)
      love.graphics.setColor(sel and {0.90,0.88,1.0} or {0.50,0.48,0.68})
      love.graphics.print(m.desc, boxX + 14, by + 30)
    end

    love.graphics.setColor(0.55, 0.50, 0.70)
    love.graphics.printf("↑↓ to browse  •  Enter to select", 0, H - 30, W, "center")
    return
  end

  -- ── Starter pick ──────────────────────────────────────────────────────────
  local m = MODES[modeCursor]
  local mc = MODE_COLOR[m.id] or {0.7,0.7,0.7}
  love.graphics.setColor(0.90, 0.85, 1.0)
  love.graphics.printf("Choose your first companion!", 0, H*0.06, W, "center")
  love.graphics.setColor(mc[1], mc[2], mc[3])
  love.graphics.printf(m.label.." Mode", 0, H*0.13, W, "center")

  local spacing = W / (#STARTERS + 1)
  for i, sid in ipairs(STARTERS) do
    local sp  = DATA.species[sid]
    local cx  = spacing * i
    local cy  = H * 0.42
    local sel = (cursor == i)

    if sel then
      love.graphics.setColor(0.95, 0.85, 0.20, 0.18)
      love.graphics.rectangle("fill", cx-58, cy-68, 116, 130, 8, 8)
      love.graphics.setColor(0.95, 0.85, 0.20)
      love.graphics.rectangle("line", cx-58, cy-68, 116, 130, 8, 8)
    end

    love.graphics.setColor(1, 1, 1)
    drawSprite(imgs[sid], DATA.species[sid].spriteFrame or 0, cx, cy, 3)

    love.graphics.setColor(sel and {1,1,0.4} or {0.80,0.78,0.95})
    love.graphics.printf(sp.name, cx-58, cy+56, 116, "center")

    local tc = DATA.typeColor(sp.type)
    love.graphics.setColor(tc[1], tc[2], tc[3])
    love.graphics.printf(DATA.typeLabel(sp.type, sp.type2), cx-58, cy+72, 116, "center")
  end

  love.graphics.setColor(0.55, 0.50, 0.70)
  love.graphics.printf("← → to browse  •  Enter to choose", 0, H - 30, W, "center")
end

function SS.keypressed(k)
  if phase == "name" then
    if k == "return" and #nameBuffer > 0 then
      playerName = nameBuffer
      phase      = "mode"
    elseif k == "backspace" and #nameBuffer > 0 then
      nameBuffer = nameBuffer:sub(1, -2)
    end
    return
  end

  if phase == "mode" then
    if k == "up"   or k == "w" then modeCursor = (modeCursor - 2) % #MODES + 1 end
    if k == "down" or k == "s" then modeCursor = modeCursor % #MODES + 1 end
    if k == "return" or k == "space" then phase = "pick"; cursor = 1 end
    if k == "escape"             then phase = "name" end
    return
  end

  -- pick phase
  if k == "left"  or k == "a" then cursor = (cursor - 2) % #STARTERS + 1 end
  if k == "right" or k == "d" then cursor = cursor % #STARTERS + 1 end
  if k == "return" or k == "space" then
    GS.new(playerName, STARTERS[cursor], MODES[modeCursor].id)
    GS.save()
    gotoScene("overworld")
  end
  if k == "escape" then phase = "mode" end
end

function SS.textinput(t)
  if phase == "name" and #nameBuffer < 12 then
    nameBuffer = nameBuffer .. t
  end
end

function SS.exit()   end
function SS.update() end

return SS
