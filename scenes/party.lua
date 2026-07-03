-- scenes/party.lua
-- View party and box; Tab to switch views. Esc to return.
local Creatures = require("engine.creatures")
local Party     = {}

local viewMode  = 'party'   -- 'party' | 'box'
local cursor    = 1
local boxCursor = 1
local statusMsg = nil
local statusTimer = 0
local imgs = {}

local MODE_COLORS = {
  nuzlocke = {0.90, 0.75, 0.25},
  hardcore = {0.90, 0.35, 0.25},
  monlocke = {0.65, 0.35, 0.90},
}

local function setStatus(txt)
  statusMsg   = txt
  statusTimer = 2.5
end

local function loadImg(speciesId)
  if imgs[speciesId] then return end
  local sp = DATA.species[speciesId]
  if not sp then imgs[speciesId] = false; return end
  local ok, img = pcall(love.graphics.newImage, sp.sprite)
  imgs[speciesId] = ok and img or false
end

local function drawSprite(speciesId, x, y, sc)
  local img = imgs[speciesId]
  if not img then return end
  local sp  = DATA.species[speciesId]
  local fw  = math.floor(img:getWidth() / 3)
  local fh  = img:getHeight()
  local q   = love.graphics.newQuad(fw * (sp.spriteFrame or 0), 0, fw, fh, img:getDimensions())
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, q, x, y, 0, sc, sc, fw/2, fh/2)
end

local function drawHallOfHeroes(hall, W, H)
  if not hall or #hall == 0 then return end
  local stripH = 100
  love.graphics.setColor(0.12, 0.10, 0.22)
  love.graphics.rectangle("fill", 0, H - stripH, W, stripH)
  love.graphics.setColor(0.55, 0.35, 0.75)
  love.graphics.line(0, H - stripH, W, H - stripH)
  love.graphics.setColor(0.65, 0.45, 0.82)
  love.graphics.print("Hall of Heroes", 10, H - stripH + 6)

  local shown = math.min(#hall, 6)
  local colW  = (W - 20) / shown
  for j = 1, shown do
    local entry = hall[#hall - shown + j]
    local ex    = 10 + (j-1) * colW
    love.graphics.setColor(0.50, 0.42, 0.65)
    love.graphics.print(entry.name,             ex, H - stripH + 26)
    love.graphics.setColor(0.38, 0.34, 0.52)
    love.graphics.print("Lv " .. entry.level,   ex, H - stripH + 46)
    love.graphics.print("Bd " .. entry.bondLevel, ex, H - stripH + 62)
  end
end

-- ── Scene lifecycle ───────────────────────────────────────────────────────────

function Party.enter()
  viewMode    = 'party'
  cursor      = 1
  boxCursor   = 1
  statusMsg   = nil
  statusTimer = 0
  local s = GS.get()
  for _, c in ipairs(s.party) do loadImg(c.speciesId) end
  for _, c in ipairs(s.box   or {}) do loadImg(c.speciesId) end
  for _, e in ipairs(s.hallOfHeroes or {}) do loadImg(e.speciesId) end
end

function Party.update(dt)
  if statusTimer > 0 then
    statusTimer = statusTimer - dt
    if statusTimer <= 0 then statusMsg = nil end
  end
end

function Party.exit() end

function Party.keypressed(k)
  local s       = GS.get()
  local partyN  = #s.party
  local boxN    = #(s.box or {})

  -- Toggle view
  if k == 'tab' then
    viewMode  = (viewMode == 'party') and 'box' or 'party'
    cursor    = math.min(cursor,    math.max(1, partyN))
    boxCursor = math.min(boxCursor, math.max(1, boxN))
    return
  end

  if k == 'escape' or k == 'p' then gotoScene("overworld"); return end

  if viewMode == 'party' then
    if k == 'up'   or k == 'w' then cursor = math.max(1, cursor - 1) end
    if k == 'down' or k == 's' then cursor = math.min(partyN, cursor + 1) end

    if k == 'e' then
      -- Use a potion on the selected mon
      local c = s.party[cursor]
      if not c then return end
      if c.stats.hp >= c.stats.maxHp then
        setStatus(Creatures.displayName(c) .. " is already at full HP!"); return
      end
      if not GS.hasItem('potion') then
        setStatus("No Potions left!"); return
      end
      GS.useItem('potion')
      local healed = math.min(30, c.stats.maxHp - c.stats.hp)
      c.stats.hp   = c.stats.hp + healed
      setStatus(Creatures.displayName(c) .. " recovered " .. healed .. " HP!")
      GS.save()
    end

    if k == 'return' or k == 'z' then
      -- Send selected party mon to box
      if GS.isMonlocke() then
        setStatus("Cannot manage party in Monlocke!"); return
      end
      if partyN <= 1 then
        setStatus("Cannot send your last companion!"); return
      end
      local c = s.party[cursor]
      table.remove(s.party, cursor)
      table.insert(s.box, c)
      cursor = math.min(cursor, #s.party)
      setStatus(Creatures.displayName(c) .. " sent to Box.")
      GS.save()
    end

  else -- box view
    if k == 'up'   or k == 'w' then boxCursor = math.max(1, boxCursor - 1) end
    if k == 'down' or k == 's' then boxCursor = math.min(boxN, boxCursor + 1) end

    if k == 'return' or k == 'z' then
      -- Bring box mon to party
      if boxN == 0 then return end
      local maxParty = GS.isMonlocke() and 1 or 6
      if #s.party >= maxParty then
        setStatus(GS.isMonlocke() and "Monlocke: only one companion!" or "Party is full!"); return
      end
      local c = s.box[boxCursor]
      table.remove(s.box, boxCursor)
      table.insert(s.party, c)
      boxCursor = math.min(boxCursor, math.max(1, #s.box))
      loadImg(c.speciesId)
      setStatus(Creatures.displayName(c) .. " added to party.")
      GS.save()
    end
  end
end

-- ── Draw ─────────────────────────────────────────────────────────────────────

local function drawPartyView(s, W, H, usableH)
  local listW = W * 0.38
  local detW  = W - listW

  -- Party list (left)
  for i, c in ipairs(s.party) do
    local y       = 40 + (i-1) * 72
    local fainted = Creatures.isFainted(c)
    local sel     = (cursor == i)

    if sel then
      love.graphics.setColor(0.25, 0.20, 0.45)
      love.graphics.rectangle("fill", 4, y-2, listW-8, 68, 6, 6)
      love.graphics.setColor(0.70, 0.60, 0.90)
      love.graphics.rectangle("line", 4, y-2, listW-8, 68, 6, 6)
    end

    drawSprite(c.speciesId, 42, y+30, 1.2)

    love.graphics.setColor(fainted and {0.40,0.35,0.50} or {0.95,0.90,0.70})
    love.graphics.print(Creatures.displayName(c) .. " Lv" .. c.level, 80, y+4)

    local ratio = c.stats.hp / c.stats.maxHp
    local barW  = listW - 120
    love.graphics.setColor(0.15, 0.15, 0.20)
    love.graphics.rectangle("fill", 80, y+24, barW, 10, 3, 3)
    local hpCol = ratio>0.5 and {0.25,0.85,0.35} or ratio>0.25 and {0.95,0.80,0.15} or {0.90,0.20,0.20}
    love.graphics.setColor(hpCol)
    love.graphics.rectangle("fill", 80, y+24, barW*math.max(0,ratio), 10, 3, 3)
    love.graphics.setColor(0.70, 0.68, 0.85)
    love.graphics.print(c.stats.hp .. "/" .. c.stats.maxHp, 80, y+38)

    if c.status then
      love.graphics.setColor(0.65, 0.25, 0.75)
      love.graphics.printf(c.status:upper():sub(1,3), 4, y+4, 36, "center")
    end
  end

  if #s.party == 0 then
    love.graphics.setColor(0.45, 0.40, 0.60)
    love.graphics.printf("No Riftborn in party.", 4, 60, listW-8, "center")
  end

  -- Detail panel (right)
  local c = s.party[cursor]
  if c then
    local dx = listW + 10
    love.graphics.setColor(0.12, 0.10, 0.22)
    love.graphics.rectangle("fill", dx, 36, detW-10, usableH-44, 6, 6)

    drawSprite(c.speciesId, dx + detW/2 - 10, 110, 4)

    love.graphics.setColor(0.95, 0.90, 0.70)
    love.graphics.printf(Creatures.displayName(c), dx, 150, detW-10, "center")
    local sp = DATA.species[c.speciesId]
    local tc = DATA.typeColor(sp.type)
    love.graphics.setColor(tc[1], tc[2], tc[3])
    love.graphics.printf(DATA.typeLabel(sp.type, sp.type2), dx, 168, detW-10, "center")

    local stats = {
      {"HP",  c.stats.hp .. "/" .. c.stats.maxHp},
      {"ATK", c.stats.attack},
      {"DEF", c.stats.defense},
      {"SPA", c.stats.spAttack},
      {"SPD", c.stats.spDefense},
      {"SPE", c.stats.speed},
    }
    local sx = dx + 14
    for i, row in ipairs(stats) do
      love.graphics.setColor(0.55, 0.52, 0.72)
      love.graphics.print(row[1], sx, 192 + (i-1)*20)
      love.graphics.setColor(0.90, 0.88, 1.0)
      love.graphics.print(tostring(row[2]), sx+46, 192 + (i-1)*20)
    end

    local xpRatio = c.xpToNext > 0 and (c.xp / c.xpToNext) or 0
    local xbW = detW - 28
    love.graphics.setColor(0.15, 0.15, 0.25)
    love.graphics.rectangle("fill", sx, 338, xbW, 8, 3, 3)
    love.graphics.setColor(0.40, 0.70, 0.95)
    love.graphics.rectangle("fill", sx, 338, xbW*math.min(1,xpRatio), 8, 3, 3)
    love.graphics.setColor(0.50, 0.48, 0.68)
    love.graphics.print("XP  " .. c.xp .. "/" .. c.xpToNext, sx, 350)

    love.graphics.setColor(0.70, 0.65, 0.90)
    love.graphics.print("Moves:", sx, 374)
    for i, mid in ipairs(c.moves) do
      local mv = DATA.moves[mid]
      if mv then
        local tc2 = DATA.typeColor(mv.moveType)
        love.graphics.setColor(tc2[1], tc2[2], tc2[3])
        love.graphics.print(mv.name, sx+10, 390 + (i-1)*20)
        love.graphics.setColor(0.55, 0.52, 0.72)
        love.graphics.print("PP " .. c.pp[mid] .. "/" .. mv.pp, sx+180, 390 + (i-1)*20)
      end
    end

    -- Bond level + XP bar
    local bxpNeeded = Creatures.bondXpNeeded(c.bondLevel)
    local bxpRatio   = (c.bondLevel >= 10) and 1 or math.min(1, (c.bondXp or 0) / bxpNeeded)
    local bbW = detW - 28
    love.graphics.setColor(0.15, 0.15, 0.25)
    love.graphics.rectangle("fill", sx, usableH-46, bbW, 8, 3, 3)
    love.graphics.setColor(0.85, 0.70, 0.35)
    love.graphics.rectangle("fill", sx, usableH-46, bbW * bxpRatio, 8, 3, 3)
    love.graphics.setColor(0.85, 0.70, 0.35)
    local bondLabel = c.bondLevel >= 10 and "Bond MAX" or ("Bond Lv " .. c.bondLevel .. "  (" .. (c.bondXp or 0) .. "/" .. bxpNeeded .. ")")
    love.graphics.printf(bondLabel, dx, usableH-32, detW-10, "center")
  end
end

local function drawBoxView(s, W, H, usableH)
  local box  = s.box or {}
  local colW = math.floor((W - 20) / 3)

  if #box == 0 then
    love.graphics.setColor(0.45, 0.40, 0.60)
    love.graphics.printf("Box is empty.", 0, 80, W, "center")
    return
  end

  for i, c in ipairs(box) do
    local col = (i-1) % 3
    local row = math.floor((i-1) / 3)
    local x   = 10 + col * colW
    local y   = 44 + row * 90
    local sel = (boxCursor == i)

    if sel then
      love.graphics.setColor(0.25, 0.20, 0.45)
      love.graphics.rectangle("fill", x, y, colW-6, 84, 6, 6)
      love.graphics.setColor(0.70, 0.60, 0.90)
      love.graphics.rectangle("line", x, y, colW-6, 84, 6, 6)
    else
      love.graphics.setColor(0.12, 0.10, 0.22)
      love.graphics.rectangle("fill", x, y, colW-6, 84, 6, 6)
    end

    loadImg(c.speciesId)
    drawSprite(c.speciesId, x + (colW-6)/2, y + 38, 1.0)

    love.graphics.setColor(Creatures.isFainted(c) and {0.45,0.38,0.55} or {0.95,0.90,0.70})
    love.graphics.printf(Creatures.displayName(c), x, y + 58, colW-6, "center")
    love.graphics.setColor(0.55, 0.52, 0.72)
    love.graphics.printf("Lv " .. c.level, x, y + 70, colW-6, "center")
  end
end

function Party.draw()
  local W, H = love.graphics.getDimensions()
  local s    = GS.get()
  local hall = s.hallOfHeroes or {}
  local hallH = #hall > 0 and 100 or 0
  local usableH = H - hallH

  love.graphics.setBackgroundColor(0.08, 0.06, 0.16)
  love.graphics.clear()

  -- Header
  love.graphics.setColor(0.90, 0.85, 1.0)
  love.graphics.printf(viewMode == 'party' and "PARTY" or "BOX", 0, 10, W, "center")

  -- Mode badge
  local mc = MODE_COLORS[s.mode]
  if mc then
    love.graphics.setColor(mc[1], mc[2], mc[3])
    local label = s.mode:sub(1,1):upper() .. s.mode:sub(2) .. " Mode"
    love.graphics.printf(label, 0, 10, W - 8, "right")
  end

  -- Tab hint
  love.graphics.setColor(0.50, 0.48, 0.70)
  local tabHint = viewMode == 'party' and "[TAB] Box" or "[TAB] Party"
  love.graphics.print(tabHint, 8, 10)

  love.graphics.setColor(0.35, 0.30, 0.50)
  love.graphics.line(0, 30, W, 30)

  if viewMode == 'party' then
    drawPartyView(s, W, H, usableH)
  else
    drawBoxView(s, W, H, usableH)
  end

  drawHallOfHeroes(hall, W, H)

  -- Status message
  if statusMsg and statusTimer > 0 then
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, usableH - 40, W, 28)
    love.graphics.setColor(0.90, 0.88, 0.60)
    love.graphics.printf(statusMsg, 0, usableH - 34, W, "center")
  end

  -- Footer hints
  love.graphics.setColor(0.40, 0.38, 0.58)
  local hint = viewMode == 'party'
    and "E: Use Potion  |  Enter: Send to Box  |  Esc/P: Back"
    or  "Enter: Add to Party  |  Esc/P: Back"
  love.graphics.printf(hint, 0, H - hallH - 14, W, "center")
end

return Party
