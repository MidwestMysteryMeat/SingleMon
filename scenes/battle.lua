-- scenes/battle.lua
-- Classic Pokemon-style turn-based battle screen.
-- Wild battles: FIGHT | BAG (stones + potions) | SWITCH | RUN
-- Trainer battles: FIGHT | BAG (potions only) | SWITCH | (RUN grayed)
local Creatures = require("engine.creatures")
local PRNG      = require("lib.prng")
local Battle    = {}

-- ── State ────────────────────────────────────────────────────────────────────
local bstate       -- engine battle state {player, enemy, pStages, eStages, turn}
local rng          -- PRNG instance
local events       -- queue of events to display
local eventIdx     -- index of current event being shown
local eventTimer   -- time remaining on current event display
local phase          -- 'menu' | 'move_select' | 'bag' | 'switch_pick' | 'resolving' | 'result'
local menu_cursor    -- top-level menu cursor (1-4)
local move_cursor    -- move submenu cursor
local bag_cursor     -- bag item cursor
local switch_cursor  -- party slot cursor for switch picker
local bag_items    -- list of {id, name, qty, tier} for current bag context
local isWild       -- bool: is this a wild encounter?
local trainerParty -- list of creature tables (trainer battles only)
local trainerIdx   -- which trainer mon we're currently fighting
local trainerNpc   -- the npc table from overworld (so we can mark defeated)
local trainerName  -- display name for trainer
local result_text  -- final result text
local result_timer
local imgs         -- sprite image cache
local W, H

-- Colors
local HP_GREEN  = {0.25, 0.85, 0.35}
local HP_YELLOW = {0.95, 0.80, 0.15}
local HP_RED    = {0.90, 0.20, 0.20}

local MENU_LABELS = {"FIGHT", "BAG", "SWITCH", "RUN"}

-- ── Helpers ──────────────────────────────────────────────────────────────────
local function loadImg(speciesId)
  if imgs[speciesId] then return end
  local sp = DATA.species[speciesId]
  if not sp then imgs[speciesId] = false; return end
  local ok, img = pcall(love.graphics.newImage, sp.sprite)
  imgs[speciesId] = ok and img or false
end

-- Draw a sprite frame (144×48 strip; frame 0/1/2 = stage1/2/3)
local function drawSprite(speciesId, x, y, sc, frame)
  local img = imgs[speciesId]
  if not img then return end
  frame = frame or DATA.species[speciesId].spriteFrame or 0
  local fw = math.floor(img:getWidth() / 3)
  local fh = img:getHeight()
  local q  = love.graphics.newQuad(fw * frame, 0, fw, fh, img:getDimensions())
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(img, q, x, y, 0, sc, sc, fw/2, fh/2)
end

local function hpColor(ratio)
  return ratio > 0.5 and HP_GREEN or ratio > 0.25 and HP_YELLOW or HP_RED
end

local function drawHpBar(c, x, y, barW)
  local ratio = c.stats.hp / c.stats.maxHp
  love.graphics.setColor(0.15, 0.15, 0.15)
  love.graphics.rectangle("fill", x, y, barW, 12, 3,3)
  local col = hpColor(ratio)
  love.graphics.setColor(col)
  love.graphics.rectangle("fill", x, y, barW * math.max(0, ratio), 12, 3,3)
  love.graphics.setColor(0.90, 0.90, 0.90)
  love.graphics.print(c.stats.hp.."/"..c.stats.maxHp, x + barW + 6, y - 2)
end

local STATUS_COLOR = {
  poison    = {0.65,0.25,0.75},
  bad_poison= {0.50,0.10,0.60},
  burn      = {0.85,0.30,0.10},
  paralyze  = {0.90,0.80,0.10},
  sleep     = {0.40,0.40,0.70},
  freeze    = {0.50,0.85,0.95},
  blind     = {0.30,0.30,0.30},
}
local STATUS_LABEL = {
  poison="PSN", bad_poison="BDN", burn="BRN",
  paralyze="PAR", sleep="SLP", freeze="FRZ", blind="BLN",
}
local function drawStatus(c, x, y)
  if not c.status then return end
  local col = STATUS_COLOR[c.status] or {0.5,0.5,0.5}
  love.graphics.setColor(col)
  love.graphics.rectangle("fill", x, y, 36, 14, 3,3)
  love.graphics.setColor(1,1,1)
  love.graphics.printf(STATUS_LABEL[c.status] or "???", x, y+1, 36, "center")
end

-- Build the bag item list based on inventory and battle type
local function buildBagItems()
  local inv  = GS.get().inventory
  local list = {}
  if isWild then
    local stones = inv.bind_stone or 0
    if stones > 0 then
      list[#list+1] = { id="bind_stone", name="Bind Stone", qty=stones, tier=1 }
    end
    local sstones = inv.super_stone or 0
    if sstones > 0 then
      list[#list+1] = { id="super_stone", name="Super Stone", qty=sstones, tier=2 }
    end
  end
  local pots = inv.potion or 0
  if pots > 0 then
    list[#list+1] = { id="potion", name="Potion  (+30 HP)", qty=pots, tier=0 }
  end
  return list
end

-- ── Event processing ─────────────────────────────────────────────────────────
local EVENT_DURATION = 1.2
local EVENT_MSG = {
  damage         = function(e) return (e.typeM == 0 and "No effect!" or e.typeM >= 2 and "Super effective!  -"..e.amount or e.typeM < 1 and "Not very effective...  -"..e.amount or e.moveName.."!  -"..e.amount) end,
  miss           = function(e) return "Missed!" end,
  heal           = function(e) return "Recovered "..e.amount.." HP!" end,
  recoil         = function(e) return "Recoil! -"..e.amount end,
  status_applied = function(e) return e.target.." is "..e.status.."!" end,
  status_damage  = function(e) return "Hurt by "..e.status.."! -"..e.amount end,
  stat_change    = function(e) return e.target.." "..e.stat..(e.stages>0 and " rose!" or " fell!") end,
  cant_act       = function(e) return e.target.." is "..e.reason.."!" end,
  wake           = function(e) return e.target.." woke up!" end,
  thaw           = function(e) return e.target.." thawed out!" end,
  fled           = function(e) return "Got away safely!" end,
}

local currentMsg = ""

local function nextEvent()
  eventIdx = (eventIdx or 0) + 1
  local ev = events[eventIdx]
  if not ev then
    -- All events consumed — check outcome
    if bstate.outcome == 'fled' then
      phase = 'result'; result_text = "Got away safely!"; result_timer = 1.5

    elseif bstate.outcome == 'player_won' then
      if not isWild and trainerParty then
        -- Check if trainer has more mons
        trainerIdx = trainerIdx + 1
        local nextMon = trainerParty[trainerIdx]
        if nextMon then
          -- Send out next trainer mon
          loadImg(nextMon.speciesId)
          bstate.enemy   = nextMon
          bstate.eStages = {}
          bstate.outcome = 'ongoing'
          currentMsg = trainerName.." sent out "..nextMon.name.."!"
          eventTimer = EVENT_DURATION
          phase = 'resolving'
          -- Fake an event so the message shows before returning to menu
          events    = {{ type='trainer_next', msg=currentMsg }}
          eventIdx  = 0
          nextEvent()
          return
        else
          -- All trainer mons defeated — award XP from each defeated mon
          local winner = bstate.player
          local totalXp = 0
          for _, mon in ipairs(trainerParty) do
            local ep = DATA.species[mon.speciesId]
            totalXp = totalXp + (ep and ep.baseXpYield or 50)
          end
          totalXp = math.floor(totalXp * 1.5)  -- trainer XP bonus
          local oldLevel = winner.level
          local leveled = Creatures.grantXp(winner, totalXp)
          if leveled then
            local sp = DATA.species[winner.speciesId]
            for _, entry in ipairs(sp and sp.baseMoveset or {}) do
              if entry.learnLevel > oldLevel and entry.learnLevel <= winner.level then
                Creatures.learnMove(winner, entry.moveId)
              end
            end
          end
          -- Bond XP: trainer battles grant 15 per defeated mon
          local bondGain    = 15 * #trainerParty
          local bondLeveled = Creatures.grantBondXp(winner, bondGain)
          local newSp = Creatures.checkEvolution(winner)
          local evoLine = ""
          if newSp then
            local oldName = winner.name
            Creatures.evolve(winner, newSp)
            evoLine = "\n"..oldName.." evolved into "..winner.name.."!"
          elseif bondLeveled then
            evoLine = "\nBond Lv "..winner.bondLevel.."!"
          end
          result_text = trainerName.." defeated!\n+"..totalXp.." XP!"..(leveled and "  Level up! Lv "..winner.level or "")..evoLine
          phase = 'result'; result_timer = 3.0
        end
      else
        -- Wild battle win — award XP and bond XP from this mon
        local winner  = bstate.player
        local ep      = DATA.species[bstate.enemy.speciesId]
        local xpGain  = ep and ep.baseXpYield or 50
        local oldLevel = winner.level
        local leveled = Creatures.grantXp(winner, xpGain)
        if leveled then
          local sp = DATA.species[winner.speciesId]
          for _, entry in ipairs(sp and sp.baseMoveset or {}) do
            if entry.learnLevel > oldLevel and entry.learnLevel <= winner.level then
              Creatures.learnMove(winner, entry.moveId)
            end
          end
        end
        local bondLeveled = Creatures.grantBondXp(winner, 10)
        local newSp = Creatures.checkEvolution(winner)
        local evoLine = ""
        if newSp then
          local oldName = winner.name
          Creatures.evolve(winner, newSp)
          evoLine = "\n"..oldName.." evolved into "..winner.name.."!"
        elseif bondLeveled then
          evoLine = "\nBond Lv "..winner.bondLevel.."!"
        end
        result_text = "+"..xpGain.." XP!"..(leveled and "  Level up! Lv "..winner.level or "")..evoLine
        phase = 'result'; result_timer = 2.5
      end

    elseif bstate.outcome == 'player_lost' then
      phase = 'result'; result_text = "Your party was defeated!\nThey were healed."; result_timer = 2.5

    else
      -- Still ongoing — back to menu
      phase = 'menu'
    end
    currentMsg = ""
    return
  end

  -- trainer_next is a synthetic event — just show the msg then go to menu
  if ev.type == 'trainer_next' then
    currentMsg = ev.msg
    eventTimer = EVENT_DURATION
    return
  end

  local fn = EVENT_MSG[ev.type]
  currentMsg = fn and fn(ev) or ""
  eventTimer = EVENT_DURATION
end

-- ── Scene entry ───────────────────────────────────────────────────────────────
function Battle.enter(params)
  W, H      = love.graphics.getDimensions()
  isWild    = params.isWild ~= false  -- default true unless explicitly false
  rng       = BATTLE.newRng()
  imgs      = {}
  events    = {}
  eventIdx  = 0
  eventTimer = 0
  phase         = 'menu'
  menu_cursor   = 1
  move_cursor   = 1
  bag_cursor    = 1
  switch_cursor = 1
  result_text  = nil
  result_timer = 0
  currentMsg   = ""

  -- Trainer setup
  trainerParty = params.trainerParty  -- nil for wild
  trainerNpc   = params.npc           -- nil for wild
  trainerName  = params.trainerName or "Trainer"
  trainerIdx   = 1

  -- Build initial battle state
  local lead = GS.firstAlive()
  assert(lead, "Battle entered with no alive party member")

  local enemy = isWild and params.wild or trainerParty[1]
  assert(enemy, "Battle entered with no enemy")

  bstate = {
    player  = lead,
    enemy   = enemy,
    pStages = {},
    eStages = {},
    turn    = 0,
    outcome = 'ongoing',
  }
  loadImg(lead.speciesId)
  loadImg(enemy.speciesId)
  if not isWild then
    for _, mon in ipairs(trainerParty) do loadImg(mon.speciesId) end
  end

  bag_items = buildBagItems()
end

-- ── Update ────────────────────────────────────────────────────────────────────
function Battle.update(dt)
  W, H = love.graphics.getDimensions()

  if phase == 'resolving' then
    eventTimer = eventTimer - dt
    if eventTimer <= 0 then nextEvent() end
    return
  end

  if phase == 'result' then
    result_timer = result_timer - dt
    if result_timer <= 0 then
      -- Sync bstate.player (authoritative post-battle state) back into GS party
      local sp = GS.get().party
      for i, c in ipairs(sp) do
        if c.uid == bstate.player.uid then sp[i] = bstate.player; break end
      end
      if bstate.outcome == 'player_lost' then
        if GS.isPermadeath() then
          GS.killFainted()  -- fainted mons archived to hall of heroes, removed from party
        else
          GS.healAll()
        end
      end
      GS.save()
      if not isWild and trainerNpc then
        gotoScene("overworld", { trainerDefeated=true, npc=trainerNpc })
      else
        gotoScene("overworld")
      end
    end
  end
end

-- ── Input ─────────────────────────────────────────────────────────────────────
function Battle.keypressed(k)
  if phase ~= 'menu' and phase ~= 'move_select' and phase ~= 'bag' and phase ~= 'switch_pick' then return end

  -- ── Top menu ──────────────────────────────────────────────────────────────
  if phase == 'menu' then
    if k == 'up'    or k == 'w' then menu_cursor = (menu_cursor-2)%4+1 end
    if k == 'down'  or k == 's' then menu_cursor = menu_cursor%4+1 end
    if k == 'left'  or k == 'a' then menu_cursor = (menu_cursor-2)%4+1 end
    if k == 'right' or k == 'd' then menu_cursor = menu_cursor%4+1 end
    if k == 'return' or k == 'space' then
      local choice = MENU_LABELS[menu_cursor]
      if choice == 'FIGHT' then
        phase = 'move_select'
        move_cursor = 1

      elseif choice == 'BAG' then
        bag_items  = buildBagItems()
        bag_cursor = 1
        phase = 'bag'

      elseif choice == 'SWITCH' then
        -- Check if any other alive party member exists
        local sp      = GS.get().party
        local current = bstate.player
        local hasOther = false
        for _, c in ipairs(sp) do
          if c.uid ~= current.uid and c.stats.hp > 0 then hasOther = true; break end
        end
        if hasOther then
          switch_cursor = 1
          phase = 'switch_pick'
        else
          currentMsg = "No other Riftborn able to battle!"
          events = {}; eventIdx = 0; eventTimer = 1.2
          phase = 'resolving'; nextEvent()
        end

      elseif choice == 'RUN' then
        if isWild then
          local ea = { type='run' }
          -- Enemy still gets a move for this turn (uses Struggle if no PP)
          local eAction = BATTLE.aiAction(bstate.enemy, rng)
          local new, evs = BATTLE.simulateTurn(bstate, ea, eAction, rng)
          bstate = new; events = evs; eventIdx = 0; eventTimer = 0
          phase = 'resolving'
          nextEvent()
        else
          currentMsg = "Can't flee from a trainer battle!"
          eventTimer  = 1.2
          phase = 'resolving'
          events = {}; eventIdx = 0
          nextEvent()
        end
      end
    end
    return
  end

  -- ── Move select ───────────────────────────────────────────────────────────
  if phase == 'move_select' then
    local moves = bstate.player.moves
    -- If all PP is 0, force Struggle immediately (no nav needed)
    local allEmpty = true
    for _, mid in ipairs(moves) do
      if (bstate.player.pp[mid] or 0) > 0 then allEmpty = false; break end
    end
    if allEmpty then
      local pAction = { type='move', moveId='struggle' }
      local eAction = BATTLE.aiAction(bstate.enemy, rng)
      local new, evs = BATTLE.simulateTurn(bstate, pAction, eAction, rng)
      bstate = new; events = evs; eventIdx = 0; eventTimer = 0
      phase  = 'resolving'; nextEvent()
      return
    end
    if k == 'up'    or k == 'w' then move_cursor = (move_cursor-2)%#moves+1 end
    if k == 'down'  or k == 's' then move_cursor = move_cursor%#moves+1 end
    if k == 'escape' or k == 'x' or k == 'z' then phase = 'menu'; return end
    if k == 'return' or k == 'space' then
      local mid = moves[move_cursor]
      if (bstate.player.pp[mid] or 0) <= 0 then return end
      local pAction = { type='move', moveId=mid }
      local eAction = BATTLE.aiAction(bstate.enemy, rng)
      local new, evs = BATTLE.simulateTurn(bstate, pAction, eAction, rng)
      bstate = new; events = evs; eventIdx = 0; eventTimer = 0
      phase  = 'resolving'; nextEvent()
    end
    return
  end

  -- ── Switch picker ──────────────────────────────────────────────────────────
  if phase == 'switch_pick' then
    local sp = GS.get().party
    if k == 'escape' or k == 'x' then phase = 'menu'; return end
    if k == 'up'   or k == 'w' then switch_cursor = math.max(1, switch_cursor - 1) end
    if k == 'down' or k == 's' then switch_cursor = math.min(#sp, switch_cursor + 1) end
    if k == 'return' or k == 'space' then
      local chosen  = sp[switch_cursor]
      local current = bstate.player
      if chosen and chosen.uid ~= current.uid and chosen.stats.hp > 0 then
        -- Incoming mon takes the field; enemy attacks it this turn
        bstate.player  = chosen
        bstate.pStages = {}
        loadImg(chosen.speciesId)
        local eAction = BATTLE.aiAction(bstate.enemy, rng)
        local new, evs = BATTLE.simulateTurn(bstate, { type='pass' }, eAction, rng)
        bstate = new; events = evs; eventIdx = 0; eventTimer = 0
        phase  = 'resolving'; nextEvent()
      end
    end
    return
  end

  -- ── Bag ───────────────────────────────────────────────────────────────────
  if phase == 'bag' then
    if k == 'escape' or k == 'x' or k == 'z' then phase = 'menu'; return end
    if k == 'up'   or k == 'w' then bag_cursor = math.max(1, bag_cursor - 1) end
    if k == 'down' or k == 's' then bag_cursor = math.min(#bag_items, bag_cursor + 1) end

    if k == 'return' or k == 'space' then
      if #bag_items == 0 then
        currentMsg = "Nothing usable!"
        events = {}; eventIdx = 0; eventTimer = 1.2
        phase = 'resolving'; nextEvent(); return
      end

      local item = bag_items[bag_cursor]
      if not item then return end

      -- Hardcore mode: items banned in battle
      if GS.isHardcore() then
        currentMsg = "Items are banned in Hardcore mode!"
        events = {}; eventIdx = 0; eventTimer = 1.5
        phase = 'resolving'; nextEvent(); return
      end

      if item.id == 'potion' then
        local p = bstate.player
        if p.stats.hp >= p.stats.maxHp then
          currentMsg = p.name.." is already at full HP!"
          events = {}; eventIdx = 0; eventTimer = 1.2
          phase = 'resolving'; nextEvent(); return
        end
        GS.useItem('potion')
        local healed = math.min(30, p.stats.maxHp - p.stats.hp)
        p.stats.hp   = p.stats.hp + healed   -- mutates bstate.player; copyCrea picks it up
        -- Enemy still acts this turn
        local eAction = BATTLE.aiAction(bstate.enemy, rng)
        local new, evs = BATTLE.simulateTurn(bstate, { type='pass' }, eAction, rng)
        events = {{ type='heal', target=p.name, amount=healed }}
        for _, ev in ipairs(evs) do events[#events+1] = ev end
        bstate    = new   -- new.player.stats.hp = healed HP minus any enemy counter-hit
        eventIdx  = 0; eventTimer = 0
        phase = 'resolving'; nextEvent()

      elseif item.id == 'bind_stone' or item.id == 'super_stone' then
        if not isWild then phase = 'menu'; return end
        -- Hardcore: legendary Riftborn (unique sprite path) cannot be caught
        if GS.isHardcore() then
          local enemySp = DATA.species[bstate.enemy.speciesId]
          if enemySp and enemySp.sprite and enemySp.sprite:find("uniques/") then
            currentMsg = "Legendary Riftborn cannot be caught in Hardcore mode!"
            events = {}; eventIdx = 0; eventTimer = 2.0
            phase = 'resolving'; nextEvent(); return
          end
        end
        local caught = BATTLE.attemptCatch(bstate.enemy, item.tier, rng)
        GS.useItem(item.id)
        if caught then
          local newCrea = bstate.enemy
          newCrea.bondLevel = 1
          GS.addCaught(newCrea)
          -- Award XP and bond XP for catching
          local winner  = bstate.player
          local ep      = DATA.species[newCrea.speciesId]
          local xpGain  = ep and ep.baseXpYield or 50
          local leveled = Creatures.grantXp(winner, xpGain)
          if leveled then
            local newMid = DATA.getNextLearnedMove(winner.speciesId, winner.level - 1)
            if newMid then Creatures.learnMove(winner, newMid) end
          end
          local bondLeveled = Creatures.grantBondXp(winner, 5)
          local bondLine = bondLeveled and ("  Bond Lv "..winner.bondLevel.."!") or ""
          local xpLine = "+"..xpGain.." XP!"..(leveled and "  Level up! Lv "..winner.level or "")..bondLine
          bstate.outcome = 'player_won'
          events = {{ type='damage', target=newCrea.speciesId, amount=0, typeM=1, moveName='Catch!' }}
          result_text  = newCrea.name.." was caught!\n"..xpLine
          result_timer = 2.5
          phase = 'result'
          GS.save()
        else
          events = {{ type='miss', user=item.id, moveName='Stone missed!' }}
          local eAction = BATTLE.aiAction(bstate.enemy, rng)
          local dummy   = { type='pass' }
          local new, evs = BATTLE.simulateTurn(bstate, dummy, eAction, rng)
          for _, ev in ipairs(evs) do events[#events+1] = ev end
          bstate = new
          eventIdx = 0; eventTimer = 0
          phase = 'resolving'; nextEvent()
        end
      end
    end
  end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────
function Battle.draw()
  W, H = love.graphics.getDimensions()
  love.graphics.setBackgroundColor(0.10, 0.08, 0.20)
  love.graphics.clear()

  -- Battle field: top 60%, bottom 40%
  local fieldH = H * 0.60

  love.graphics.setColor(0.18, 0.22, 0.30)
  love.graphics.rectangle("fill", 0, 0, W, fieldH)
  love.graphics.setColor(0.24, 0.30, 0.40)
  love.graphics.rectangle("fill", 0, fieldH - 24, W, 24)

  -- Enemy (top-right)
  local enemy  = bstate.enemy
  local eX, eY = W * 0.72, fieldH * 0.30
  drawSprite(enemy.speciesId, eX, eY, 4, DATA.species[enemy.speciesId].spriteFrame)

  -- Enemy info panel (top-left)
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 10, 10, 250, 80, 6,6)
  if not isWild then
    love.graphics.setColor(0.70, 0.60, 0.90)
    love.graphics.print("Tamer "..trainerName, 18, 12)
  end
  love.graphics.setColor(0.95, 0.90, 0.70)
  love.graphics.print(Creatures.displayName(enemy).."  Lv"..enemy.level, 18, isWild and 15 or 28)
  local et1 = DATA.species[enemy.speciesId].type
  local etc = DATA.typeColor(et1)
  love.graphics.setColor(etc[1],etc[2],etc[3])
  love.graphics.print(DATA.typeLabel(et1, DATA.species[enemy.speciesId].type2), 18, isWild and 32 or 45)
  drawHpBar(enemy, 18, isWild and 50 or 60, 160)
  drawStatus(enemy, 186, isWild and 48 or 58)

  -- Trainer party pip row (small dots showing remaining mons)
  if not isWild and trainerParty then
    for pi, mon in ipairs(trainerParty) do
      local px  = 18 + (pi-1) * 14
      local py  = 78
      local col = pi < trainerIdx and {0.30,0.28,0.40} or (Creatures.isFainted(mon) and {0.40,0.15,0.15} or {0.20,0.75,0.35})
      love.graphics.setColor(col)
      love.graphics.circle("fill", px, py, 4)
    end
  end

  -- Player creature (bottom-left of field)
  local player = bstate.player
  local pX, pY = W * 0.28, fieldH * 0.72
  drawSprite(player.speciesId, pX, pY, 4, DATA.species[player.speciesId].spriteFrame)

  -- Player info panel (bottom-right of field)
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", W-245, fieldH-90, 235, 80, 6,6)
  love.graphics.setColor(0.95, 0.90, 0.70)
  love.graphics.print(Creatures.displayName(player).."  Lv"..player.level, W-237, fieldH-85)
  local pt1 = DATA.species[player.speciesId].type
  local ptc = DATA.typeColor(pt1)
  love.graphics.setColor(ptc[1],ptc[2],ptc[3])
  love.graphics.print(DATA.typeLabel(pt1, DATA.species[player.speciesId].type2), W-237, fieldH-68)
  drawHpBar(player, W-237, fieldH-50, 160)
  drawStatus(player, W-70, fieldH-52)

  -- ── Bottom UI panel ──────────────────────────────────────────────────────
  local uiY = fieldH
  love.graphics.setColor(0.06, 0.05, 0.14)
  love.graphics.rectangle("fill", 0, uiY, W, H - uiY)

  -- Message box (left side)
  local msgW = W * 0.55
  love.graphics.setColor(0.10, 0.10, 0.22)
  love.graphics.rectangle("fill", 0, uiY, msgW, H - uiY)
  love.graphics.setColor(0.22, 0.22, 0.40)
  love.graphics.rectangle("line", 0, uiY, msgW, H - uiY)

  if currentMsg ~= "" then
    love.graphics.setColor(1, 0.95, 0.80)
    love.graphics.printf(currentMsg, 12, uiY + 14, msgW - 24, "left")
  else
    local hint = isWild and ("Wild "..Creatures.displayName(enemy).." appeared!") or ("Tamer "..trainerName.." wants to battle!")
    love.graphics.setColor(0.60, 0.58, 0.75)
    love.graphics.printf(hint, 12, uiY + 14, msgW - 24, "left")
  end

  -- Menu / move select / bag (right side)
  local menuX = msgW
  local menuW = W - msgW
  local mH    = H - uiY

  if phase == 'menu' then
    for i, label in ipairs(MENU_LABELS) do
      local col    = (i == 1 or i == 2) and 0 or 1  -- 2×2 grid
      local row    = (i <= 2) and 0 or 1
      local bx     = menuX + col * (menuW/2) + 6
      local by     = uiY   + row * (mH/2)   + 6
      local bw     = menuW/2 - 12
      local bh     = mH/2   - 12
      local grayed = (label == 'RUN' and not isWild) or (label == 'BAG' and GS.isHardcore())
      if menu_cursor == i and not grayed then
        love.graphics.setColor(0.95, 0.85, 0.25)
      elseif grayed then
        love.graphics.setColor(0.14, 0.14, 0.22)
      else
        love.graphics.setColor(0.22, 0.22, 0.38)
      end
      love.graphics.rectangle("fill", bx, by, bw, bh, 5,5)
      love.graphics.setColor(grayed and {0.30,0.28,0.40} or (menu_cursor==i and {0,0,0} or {0.90,0.88,0.98}))
      love.graphics.printf(label, bx, by + bh/2 - 8, bw, "center")
    end

  elseif phase == 'move_select' then
    local moves = bstate.player.moves
    for i, mid in ipairs(moves) do
      local mv   = DATA.moves[mid]
      local row  = (i-1) % 2
      local col  = math.floor((i-1)/2)
      local bx   = menuX + col*(menuW/2) + 6
      local by   = uiY   + row*(mH/2)   + 6
      local bw   = menuW/2 - 12
      local bh   = mH/2   - 12
      local noPP = (bstate.player.pp[mid] or 0) <= 0
      if move_cursor == i and not noPP then
        love.graphics.setColor(0.95, 0.85, 0.25)
      elseif noPP then
        love.graphics.setColor(0.15, 0.15, 0.22)
      else
        love.graphics.setColor(0.22, 0.22, 0.38)
      end
      love.graphics.rectangle("fill", bx, by, bw, bh, 5,5)
      if mv then
        local tc = DATA.typeColor(mv.moveType)
        love.graphics.setColor(tc[1],tc[2],tc[3],0.50)
        love.graphics.rectangle("fill", bx, by+bh-10, bw, 10, 0,0,5,5)
        love.graphics.setColor(move_cursor==i and {0,0,0} or (noPP and {0.30,0.28,0.40} or {0.90,0.88,0.98}))
        love.graphics.printf(mv.name, bx, by+6, bw, "center")
        love.graphics.setColor(0.60,0.58,0.75)
        love.graphics.printf("PP "..bstate.player.pp[mid].."/"..mv.pp, bx, by+bh-26, bw, "center")
      end
    end
    love.graphics.setColor(0.50,0.48,0.68)
    love.graphics.printf("Z/Esc: Back", menuX+6, H-22, menuW-12, "center")

  elseif phase == 'bag' then
    love.graphics.setColor(0.12, 0.12, 0.24)
    love.graphics.rectangle("fill", menuX+6, uiY+6, menuW-12, mH-12, 5,5)
    if #bag_items == 0 then
      love.graphics.setColor(0.55,0.52,0.72)
      love.graphics.printf("Bag is empty!", menuX+6, uiY+30, menuW-12, "center")
    else
      for i, item in ipairs(bag_items) do
        local iy  = uiY + 10 + (i-1) * 36
        local sel = (bag_cursor == i)
        if sel then
          love.graphics.setColor(0.95,0.85,0.25)
          love.graphics.rectangle("fill", menuX+10, iy, menuW-20, 30, 4,4)
          love.graphics.setColor(0,0,0)
        else
          love.graphics.setColor(0.90,0.88,0.98)
        end
        love.graphics.printf(item.name.."  x"..item.qty, menuX+14, iy+6, menuW-28, "left")
      end
    end
    love.graphics.setColor(0.50,0.48,0.68)
    love.graphics.printf("Z/Esc: Back", menuX+6, H-22, menuW-12, "center")

  elseif phase == 'switch_pick' then
    local sp = GS.get().party
    love.graphics.setColor(0.12, 0.12, 0.24)
    love.graphics.rectangle("fill", menuX+6, uiY+6, menuW-12, mH-12, 5,5)
    love.graphics.setColor(0.70, 0.65, 0.90)
    love.graphics.printf("Switch to:", menuX+6, uiY+10, menuW-12, "center")
    local rowH = math.max(28, (mH - 40) / math.max(1, #sp))
    for i, c in ipairs(sp) do
      local iy      = uiY + 32 + (i-1) * rowH
      local isCur   = (c.uid == bstate.player.uid)
      local fainted = Creatures.isFainted(c)
      local sel     = (switch_cursor == i)
      local unavail = isCur or fainted
      if sel and not unavail then
        love.graphics.setColor(0.95, 0.85, 0.25)
        love.graphics.rectangle("fill", menuX+10, iy, menuW-20, rowH-4, 4,4)
        love.graphics.setColor(0, 0, 0)
      elseif unavail then
        love.graphics.setColor(0.30, 0.28, 0.40)
      else
        love.graphics.setColor(0.90, 0.88, 0.98)
      end
      local tag = isCur and " (out)" or (fainted and " (fainted)" or "")
      love.graphics.printf(Creatures.displayName(c).." Lv"..c.level..tag, menuX+14, iy+6, menuW-28, "left")
    end
    love.graphics.setColor(0.50, 0.48, 0.68)
    love.graphics.printf("Esc: Cancel", menuX+6, H-22, menuW-12, "center")
  end

  -- Result overlay
  if phase == 'result' and result_text then
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(1, 0.95, 0.70)
    love.graphics.printf(result_text, 40, H/2 - 30, W - 80, "center")
  end
end

function Battle.exit() end

return Battle
