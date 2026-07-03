-- scenes/overworld.lua
-- Tile-based top-down overworld. WASD/arrows to move. Z/Enter to interact.
-- Grass tiles trigger encounters. Healing only via Rift Center NPC interaction.
local PRNG      = require("lib.prng")
local Creatures = require("engine.creatures")
local cfg       = require("config")
local OW        = {}

-- Tile constants (no auto-heal tile — healing is NPC-only)
local T = { PATH=0, WALL=1, GRASS=2, WATER=3 }

local TILE_COLOR = {
  [T.PATH]  = {0.55, 0.52, 0.40},
  [T.WALL]  = {0.25, 0.22, 0.18},
  [T.GRASS] = {0.30, 0.62, 0.28},
  [T.WATER] = {0.25, 0.45, 0.80},
}

-- NPC types and their interactions
-- type: 'healer' | 'shop' | 'sign' | 'trainer'
-- NPCs are interacted with by facing them and pressing Z/Enter.

local SHOP_ITEMS = {
  { id="bind_stone",  name="Bind Stone",  desc="Used to catch wild Riftborn.",    price=200 },
  { id="potion",      name="Potion",      desc="Restores 30 HP to one companion.", price=300 },
  { id="super_stone", name="Super Stone", desc="Higher catch rate than Bind Stone.", price=600 },
}

-- Map definitions
local MAPS = {
  town = {
    name    = "Faro Town",
    bgColor = {0.36, 0.44, 0.30},
    -- 20 wide × 15 tall. Buildings are wall clusters; NPCs placed at their entrances.
    -- Left building = Rift Center (healer). Right building = Tamer Mart (shop).
    tiles = {
      {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},  -- row 0
      {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},  -- row 1: building tops
      {1,1,0,0,1,1,0,0,1,1,1,1,1,0,0,1,1,0,0,1},  -- row 2: building roofs (walls)
      {1,1,0,0,1,1,0,0,1,1,1,1,1,0,0,1,1,0,0,1},  -- row 3
      {1,1,0,0,1,1,0,0,1,1,1,1,1,0,0,1,1,0,0,1},  -- row 4
      {1,1,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,1},  -- row 5: entrance rows
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},  -- row 6: open plaza
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},  -- row 7
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},  -- row 8
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},  -- row 9
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},  -- row 10
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},  -- row 11
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},  -- row 12
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},  -- row 13
      {1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1},  -- row 14: south wall with exit
    },
    npcs = {
      -- Rift Center nurse: player walks to row 6, col 4 and faces up (toward row 5)
      { x=4, y=5, type='healer', name='Nurse Lyra',
        dialogue='Welcome to the Rift Center! I will heal your companions.' },
      -- Tamer Mart clerk: player at row 6, col 15 faces up
      { x=15, y=5, type='shop',   name='Mart Clerk',
        dialogue='Welcome to the Tamer Mart! What can I get you?' },
      -- Sign near exit
      { x=9, y=12, type='sign', name='',
        dialogue='Route 1 lies to the south. Wild Riftborn roam the tall grass.' },
    },
    warps = {
      { fromX=9,  fromY=14, toMap='route1', toX=9,  toY=1 },
      { fromX=10, fromY=14, toMap='route1', toX=10, toY=1 },
    },
    playerStart = {x=9, y=9},
    wildMons    = nil,
  },
  route1 = {
    name    = "Route 1",
    bgColor = {0.22, 0.36, 0.20},
    npcs = {
      { x=9,  y=6,  type='trainer', trainerTheme='dinosaur_jungle', trainerBaseLevel=5,  trainerNumMons=2, defeated=false },
      { x=14, y=10, type='trainer', trainerTheme='troll_caves',     trainerBaseLevel=6,  trainerNumMons=2, defeated=false },
      { x=5, y=11, type='sign', name='',
        dialogue='CAUTION: Riftborn energy detected in the tall grass ahead.' },
      { x=14, y=13, type='sign', name='',
        dialogue='Route 2 lies to the south — water and ice types roam there.' },
    },
    warps = {
      { fromX=9,  fromY=0,  toMap='town',   toX=9,  toY=13 },
      { fromX=10, fromY=0,  toMap='town',   toX=10, toY=13 },
      { fromX=9,  fromY=14, toMap='route2', toX=9,  toY=1  },
      { fromX=10, fromY=14, toMap='route2', toX=10, toY=1  },
    },
    playerStart = {x=9, y=1},
    -- Route 1 south wall has exits at col 9-10
    tiles = {
      {1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,2,2,2,2,0,0,0,0,0,0,2,2,2,2,0,0,0,1},
      {1,0,2,2,2,2,0,0,0,0,0,0,2,2,2,2,0,0,0,1},
      {1,0,2,2,2,2,0,0,0,0,0,0,2,2,2,2,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,2,2,2,2,0,0,0,2,2,2,2,0,0,0,0,1},
      {1,0,0,0,2,2,2,2,0,0,0,2,2,2,2,0,0,0,0,1},
      {1,0,0,0,2,2,2,2,0,0,0,2,2,2,2,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1},
    },
    wildMons = {
      { speciesId='pinklet',     weight=25, minLevel=3, maxLevel=6 },
      { speciesId='spriglet',    weight=25, minLevel=3, maxLevel=6 },
      { speciesId='tawnykit',    weight=20, minLevel=3, maxLevel=6 },
      { speciesId='shimmergrub', weight=15, minLevel=4, maxLevel=7 },
      { speciesId='graycub',     weight=10, minLevel=4, maxLevel=7 },
      { speciesId='toxrat',      weight=5,  minLevel=4, maxLevel=7 },
    },
  },

  route2 = {
    name    = "Route 2 — Coldwater Path",
    bgColor = {0.20, 0.30, 0.38},
    tiles = {
      {1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,2,2,2,0,0,0,0,0,0,0,0,0,2,2,2,2,0,1},
      {1,0,2,2,2,0,0,0,0,0,0,0,0,0,2,2,2,2,0,1},
      {1,0,2,2,2,0,0,0,0,0,0,0,0,0,2,2,2,2,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,3,3,3,0,0,0,0,0,0,0,3,3,3,0,0,0,1},
      {1,0,0,3,3,3,0,0,0,0,0,0,0,3,3,3,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,2,2,2,2,0,0,0,0,2,2,2,0,0,0,0,1},
      {1,0,0,0,2,2,2,2,0,0,0,0,2,2,2,0,0,0,0,1},
      {1,0,0,0,2,2,2,2,0,0,0,0,2,2,2,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1},
    },
    npcs = {
      { x=7,  y=5,  type='trainer', trainerTheme='coral_grotto',   trainerBaseLevel=9,  trainerNumMons=2, defeated=false },
      { x=12, y=10, type='trainer', trainerTheme='frozen_depths',  trainerBaseLevel=10, trainerNumMons=2, defeated=false },
      { x=9, y=12, type='sign', name='',
        dialogue='Route 3 is ahead. Dark Riftborn haunt those woods — be careful.' },
    },
    warps = {
      { fromX=9,  fromY=0,  toMap='route1', toX=9,  toY=13 },
      { fromX=10, fromY=0,  toMap='route1', toX=10, toY=13 },
      { fromX=9,  fromY=14, toMap='route3', toX=9,  toY=1  },
      { fromX=10, fromY=14, toMap='route3', toX=10, toY=1  },
    },
    playerStart = {x=9, y=1},
    wildMons = {
      { speciesId='tidelet',    weight=28, minLevel=7, maxLevel=11 },
      { speciesId='snowbun',    weight=22, minLevel=7, maxLevel=11 },
      { speciesId='blushkit',   weight=20, minLevel=8, maxLevel=12 },
      { speciesId='woolpup',    weight=15, minLevel=8, maxLevel=12 },
      { speciesId='stormchick', weight=10, minLevel=9, maxLevel=13 },
      { speciesId='joltoad',    weight=5,  minLevel=9, maxLevel=13 },
    },
  },

  route3 = {
    name    = "Route 3 — Dusk Woods",
    bgColor = {0.12, 0.10, 0.18},
    tiles = {
      {1,1,1,1,1,1,1,1,1,0,0,1,1,1,1,1,1,1,1,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,2,2,2,2,2,0,0,0,0,0,2,2,2,2,2,0,0,1},
      {1,0,2,2,2,2,2,0,0,0,0,0,2,2,2,2,2,0,0,1},
      {1,0,2,2,2,2,2,0,0,0,0,0,2,2,2,2,2,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,2,2,2,2,2,0,0,0,2,2,2,2,2,0,0,0,1},
      {1,0,0,2,2,2,2,2,0,0,0,2,2,2,2,2,0,0,0,1},
      {1,0,0,2,2,2,2,2,0,0,0,2,2,2,2,2,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
      {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    },
    npcs = {
      { x=6,  y=6,  type='trainer', trainerTheme='shadow_realm',   trainerBaseLevel=13, trainerNumMons=2, defeated=false },
      { x=14, y=9,  type='trainer', trainerTheme='abyssal_dark',   trainerBaseLevel=15, trainerNumMons=3, defeated=false },
      { x=5, y=12, type='sign', name='',
        dialogue='You have reached the edge of the known routes. Deeper wilds lie beyond.' },
    },
    warps = {
      { fromX=9,  fromY=0, toMap='route2', toX=9,  toY=13 },
      { fromX=10, fromY=0, toMap='route2', toX=10, toY=13 },
    },
    playerStart = {x=9, y=1},
    wildMons = {
      { speciesId='shadowchick',  weight=28, minLevel=12, maxLevel=17 },
      { speciesId='specter',      weight=25, minLevel=12, maxLevel=17 },
      { speciesId='nightbat',     weight=18, minLevel=13, maxLevel=18 },
      { speciesId='ravenlet',     weight=15, minLevel=13, maxLevel=18 },
      { speciesId='gloomfeather', weight=10, minLevel=14, maxLevel=18 },
      { speciesId='voidpup',      weight=4,  minLevel=14, maxLevel=18 },
    },
  },
}

-- ── Module state ─────────────────────────────────────────────────────────────
local mapId, mapDef, player, rng, TSIZE
local msgText, msgTimer
local gameOverState  = nil  -- nil or { timer } when permadeath game over

-- Interaction / dialogue state
local dialogue     = nil   -- { npc, text, done } or nil
local shopState    = nil   -- { cursor, items } or nil when shop open

local function setMsg(txt, dur)
  msgText  = txt
  msgTimer = dur or 2.5
end

local function getTile(mx, my)
  local row = mapDef.tiles[my + 1]
  if not row then return T.WALL end
  return row[mx + 1] or T.WALL
end

local function isPassable(mx, my)
  local t = getTile(mx, my)
  return t ~= T.WALL and t ~= T.WATER
end

-- Returns NPC at map coords, or nil
local function getNpcAt(mx, my)
  if not mapDef.npcs then return nil end
  for _, npc in ipairs(mapDef.npcs) do
    if npc.x == mx and npc.y == my then return npc end
  end
  return nil
end

local function pickWildMon()
  if not mapDef.wildMons then return nil end
  local total = 0
  for _, e in ipairs(mapDef.wildMons) do total = total + e.weight end
  local roll = rng:int(1, total)
  local acc  = 0
  for _, e in ipairs(mapDef.wildMons) do
    acc = acc + e.weight
    if roll <= acc then return e end
  end
  return mapDef.wildMons[1]
end

local function loadMap(id, startX, startY)
  mapId  = id
  mapDef = MAPS[id]
  assert(mapDef, "Unknown map: " .. id)
  -- Sync trainer defeat state and generate procedural parties from flags.
  -- Reset defeated first so New Game clears it.
  local flags = GS.get().flags
  if mapDef.npcs then
    for _, npc in ipairs(mapDef.npcs) do
      if npc.type == 'trainer' then
        local defKey = "trainer:"..id..":"..npc.x..":"..npc.y
        npc.defeated = flags[defKey] or false

        if npc.trainerTheme then
          local tkey  = "tgen:"..id..":"..npc.x..":"..npc.y
          local cached = flags[tkey]
          if not cached then
            cached      = DATA.Trainers.generate(npc.trainerTheme, npc.trainerBaseLevel, npc.trainerNumMons)
            flags[tkey] = cached
          end
          npc.name     = cached.name
          npc.dialogue = cached.style .. " — prove your worth!"
          npc.party    = cached.party
        end
      end
    end
  end
  local st = mapDef.playerStart
  player = {
    x      = startX or st.x,
    y      = startY or st.y,
    facing = { dx=0, dy=1 },  -- starts facing down (south), like Pokemon
  }
end

-- ── Interaction ───────────────────────────────────────────────────────────────
local function openDialogue(npc)
  dialogue = { npc=npc, text=npc.dialogue }
end

local function confirmDialogue()
  local npc = dialogue and dialogue.npc
  dialogue = nil
  if not npc then return end

  if npc.type == 'healer' then
    GS.healAll()
    GS.save()
    setMsg("Your companions have been fully healed!", 2.5)

  elseif npc.type == 'shop' then
    shopState = { cursor=1, items=SHOP_ITEMS, msg=nil }

  elseif npc.type == 'trainer' then
    if npc.defeated then
      setMsg(npc.name .. ": You are too strong for me now.", 2.0)
    else
      -- Build trainer party
      local trainerParty = {}
      for _, entry in ipairs(npc.party) do
        trainerParty[#trainerParty+1] = Creatures.new(entry.speciesId, entry.level)
      end
      GS.save()
      gotoScene("battle", { isWild=false, trainerName=npc.name, trainerParty=trainerParty, npc=npc })
    end
  end
end

local function interact()
  if dialogue then
    confirmDialogue()
    return
  end
  if shopState then
    shopState = nil
    return
  end

  -- Check tile in front of player
  local fx = player.x + player.facing.dx
  local fy = player.y + player.facing.dy
  local npc = getNpcAt(fx, fy)
  if npc then
    openDialogue(npc)
  else
    -- Check warp in front (let player interact with exits)
    for _, w in ipairs(mapDef.warps) do
      if w.fromX == fx and w.fromY == fy then
        -- just walk into it via movement
        break
      end
    end
  end
end

-- ── Movement ──────────────────────────────────────────────────────────────────
local function movePlayer(dx, dy)
  -- Dialogue/shop blocks movement
  if dialogue or shopState then return end

  player.facing.dx = dx
  player.facing.dy = dy

  local nx = player.x + dx
  local ny = player.y + dy

  -- NPC in that direction blocks movement (and doesn't auto-trigger)
  if getNpcAt(nx, ny) then return end

  if not isPassable(nx, ny) then return end

  player.x = nx
  player.y = ny

  local s = GS.get()
  s.steps  = s.steps + 1

  -- Bond XP tick: every 5 steps, lead gains 1 bond XP
  if s.steps % 5 == 0 then
    local lead = GS.firstAlive()
    if lead then
      local bondLeveled = Creatures.grantBondXp(lead, 1)
      if bondLeveled then
        local newSp = Creatures.checkEvolution(lead)
        if newSp then
          local oldName = lead.name
          Creatures.evolve(lead, newSp)
          setMsg(oldName .. " evolved into " .. lead.name .. "!", 3.0)
        else
          setMsg(Creatures.displayName(lead) .. "'s bond deepened! (Lv " .. lead.bondLevel .. ")", 2.5)
        end
      end
    end
  end

  -- Warp check
  for _, w in ipairs(mapDef.warps) do
    if w.fromX == nx and w.fromY == ny then
      GS.save()
      s.location = { map=w.toMap, x=w.toX, y=w.toY }
      loadMap(w.toMap, w.toX, w.toY)
      return
    end
  end

  -- Grass encounter (10% per step)
  if getTile(nx, ny) == T.GRASS and rng:chance(0.10) then
    -- Nuzlocke/hardcore: each route only grants one wild encounter
    local routeLocked = (GS.isPermadeath() and not GS.isMonlocke())
                        and GS.routeHasEncountered(mapId)
    if not routeLocked then
      local entry = pickWildMon()
      if entry then
        local lvl  = rng:int(entry.minLevel, entry.maxLevel)
        local wild = Creatures.new(entry.speciesId, lvl)
        if GS.firstAlive() then
          -- Mark route used before entering battle (encounter is consumed on trigger)
          if GS.isPermadeath() and not GS.isMonlocke() then
            GS.markRouteEncountered(mapId)
          end
          GS.save()
          gotoScene("battle", { wild=wild, isWild=true })
        end
      end
    end
  end
end

-- ── Scene lifecycle ───────────────────────────────────────────────────────────
function OW.enter(params)
  TSIZE         = cfg.tileSize
  rng           = PRNG.new(os.time())
  dialogue      = nil
  shopState     = nil
  msgText       = nil
  msgTimer      = 0
  gameOverState = nil

  local s = GS.get()
  loadMap(s.location.map, s.location.x, s.location.y)

  -- Returned from a trainer battle win
  if params and params.trainerDefeated and params.npc then
    params.npc.defeated = true
    local key = "trainer:"..mapId..":"..params.npc.x..":"..params.npc.y
    GS.get().flags[key] = true
    GS.save()
    setMsg(params.npc.name .. " was defeated!", 2.0)
  end

  -- Permadeath game over: party wiped and all mons are dead (not just fainted)
  if GS.isGameOver() then
    gameOverState = { timer = 4.0 }
    return
  end

  -- Normal blackout (non-permadeath, or permadeath with survivors)
  if GS.isWiped() and not GS.isPermadeath() then
    s.location = { map='town', x=9, y=9 }
    loadMap('town')
    GS.healAll()
    setMsg("Your party was exhausted! You woke up in Faro Town.", 3.0)
  end
end

function OW.update(dt)
  if msgTimer > 0 then msgTimer = msgTimer - dt end
  if gameOverState then
    gameOverState.timer = gameOverState.timer - dt
    if gameOverState.timer <= 0 then
      SAVE.delete()
      gotoScene("title")
    end
  end
end

local keyMove = {
  up={0,-1}, w={0,-1}, down={0,1}, s={0,1},
  left={-1,0}, a={-1,0}, right={1,0}, d={1,0},
}

function OW.keypressed(k)
  if gameOverState then return end  -- block all input during game over
  if k == 'p' or k == 'tab' then gotoScene("party"); return end
  if k == 'escape' then GS.save(); gotoScene("title"); return end

  -- Interact key
  if k == 'z' or k == 'return' or k == 'e' then
    interact()
    return
  end

  -- Shop navigation
  if shopState then
    if k == 'up'   or k == 'w' then shopState.cursor = math.max(1, shopState.cursor-1) end
    if k == 'down' or k == 's' then shopState.cursor = math.min(#shopState.items, shopState.cursor+1) end
    if k == 'x' or k == 'escape' then shopState = nil; return end
    if k == 'z' or k == 'return' or k == 'e' then
      local item  = shopState.items[shopState.cursor]
      local gs    = GS.get()
      if gs.money >= item.price then
        gs.money = gs.money - item.price
        GS.addItem(item.id, 1)
        GS.save()
        shopState.msg = "Bought "..item.name.."! ("..item.id.." x"..(gs.inventory[item.id] or 1)..")"
      else
        shopState.msg = "Not enough money!"
      end
    end
    return
  end

  -- Dialogue advance
  if dialogue then
    if k == 'z' or k == 'return' or k == 'e' or k == 'space' then
      confirmDialogue()
    end
    return
  end

  -- Movement
  local dir = keyMove[k]
  if dir and msgTimer <= 0 then movePlayer(dir[1], dir[2]) end
end

-- ── Draw ──────────────────────────────────────────────────────────────────────
local NPC_COLOR = {
  healer  = {0.95, 0.40, 0.60},
  shop    = {0.40, 0.75, 0.95},
  sign    = {0.80, 0.70, 0.40},
  trainer = {0.90, 0.55, 0.20},
}

function OW.draw()
  local W, H = love.graphics.getDimensions()
  local bg   = mapDef.bgColor or {0.2,0.3,0.2}
  love.graphics.setBackgroundColor(bg[1], bg[2], bg[3])
  love.graphics.clear()

  -- Camera centered on player
  local camX = player.x * TSIZE - W/2
  local camY = player.y * TSIZE - H/2
  love.graphics.push()
  love.graphics.translate(-camX, -camY)

  -- Tiles
  for row = 1, #mapDef.tiles do
    local trow = mapDef.tiles[row]
    for col = 1, #trow do
      local t  = trow[col]
      local c  = TILE_COLOR[t] or {0.4,0.4,0.4}
      local px = (col-1)*TSIZE
      local py = (row-1)*TSIZE
      love.graphics.setColor(c[1], c[2], c[3])
      love.graphics.rectangle("fill", px, py, TSIZE-1, TSIZE-1)
      if t == T.GRASS then
        love.graphics.setColor(0.22, 0.52, 0.20, 0.7)
        love.graphics.rectangle("fill", px+2, py+2, 3, TSIZE-5)
        love.graphics.rectangle("fill", px+TSIZE-7, py+4, 3, TSIZE-6)
      end
    end
  end

  -- Building labels drawn on wall tiles (simple text overlay)
  if mapDef.name == "Faro Town" then
    love.graphics.setColor(0.95, 0.90, 0.70)
    love.graphics.printf("RIFT\nCENTER", 2*TSIZE, 2*TSIZE, 4*TSIZE, "center")
    love.graphics.printf("TAMER\nMART",  13*TSIZE, 2*TSIZE, 4*TSIZE, "center")
  end

  -- NPCs (colored squares with first letter)
  if mapDef.npcs then
    for _, npc in ipairs(mapDef.npcs) do
      local col = NPC_COLOR[npc.type] or {0.8,0.8,0.8}
      if npc.type == 'trainer' and npc.defeated then
        love.graphics.setColor(0.40, 0.40, 0.50)
      else
        love.graphics.setColor(col[1], col[2], col[3])
      end
      local nx = npc.x * TSIZE + 3
      local ny = npc.y * TSIZE + 3
      love.graphics.rectangle("fill", nx, ny, TSIZE-6, TSIZE-6, 4,4)
      love.graphics.setColor(0,0,0)
      local label = npc.type == 'healer' and "+" or npc.type == 'shop' and "$" or npc.type == 'trainer' and "!" or "?"
      love.graphics.printf(label, nx, ny + TSIZE/2 - 8, TSIZE-6, "center")
    end
  end

  -- Player: arrow indicating facing direction
  love.graphics.setColor(0.95, 0.90, 0.55)
  local px = player.x*TSIZE+2
  local py = player.y*TSIZE+2
  love.graphics.rectangle("fill", px, py, TSIZE-4, TSIZE-4, 3,3)
  love.graphics.setColor(0.30, 0.25, 0.10)
  -- Facing dot
  local dotX = px + (TSIZE-4)/2 + player.facing.dx*6
  local dotY = py + (TSIZE-4)/2 + player.facing.dy*6
  love.graphics.circle("fill", dotX, dotY, 4)

  love.graphics.pop()

  -- ── HUD ──────────────────────────────────────────────────────────────────
  love.graphics.setColor(0,0,0,0.60)
  love.graphics.rectangle("fill", 0, 0, W, 28)
  love.graphics.setColor(0.95, 0.90, 0.70)
  love.graphics.print(mapDef.name, 8, 6)

  -- Mode badge (non-normal modes only)
  local gs = GS.get()
  if gs.mode ~= 'normal' then
    local modeColors = {
      nuzlocke={0.90,0.75,0.25}, hardcore={0.90,0.35,0.25}, monlocke={0.65,0.35,0.90}
    }
    local mc = modeColors[gs.mode] or {0.7,0.7,0.7}
    local label = gs.mode:sub(1,1):upper()..gs.mode:sub(2)
    love.graphics.setColor(mc[1],mc[2],mc[3],0.90)
    love.graphics.rectangle("fill", W/2-28, 4, 56, 20, 4,4)
    love.graphics.setColor(0,0,0)
    love.graphics.printf(label, W/2-28, 6, 56, "center")
  end

  -- Money
  love.graphics.setColor(0.85, 0.80, 0.30)
  love.graphics.printf("G "..GS.get().money, 0, 6, W-8, "right")

  -- Lead HP
  local lead = GS.firstAlive()
  if lead then
    local hpRatio = lead.stats.hp / lead.stats.maxHp
    local barW = 120
    local bx, by = W - barW - 80, 6
    love.graphics.setColor(0.15, 0.15, 0.20)
    love.graphics.rectangle("fill", bx, by, barW, 16, 4,4)
    local hpCol = hpRatio>0.5 and {0.25,0.85,0.35} or hpRatio>0.25 and {0.95,0.80,0.15} or {0.90,0.20,0.20}
    love.graphics.setColor(hpCol)
    love.graphics.rectangle("fill", bx, by, barW*math.max(0,hpRatio), 16, 4,4)
    love.graphics.setColor(0.90, 0.90, 0.90)
    love.graphics.print(Creatures.displayName(lead).." Lv"..lead.level, bx+4, by)
  end

  -- Controls hint
  love.graphics.setColor(0.45, 0.43, 0.58, 0.85)
  love.graphics.printf("WASD: Move  Z/Enter: Interact  P: Party  Esc: Quit", 0, H-22, W, "center")

  -- ── Dialogue box ─────────────────────────────────────────────────────────
  if dialogue then
    local bw = W - 60
    local bh = 80
    local bx = 30
    local by = H - bh - 36
    love.graphics.setColor(0.06, 0.05, 0.16, 0.95)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8,8)
    love.graphics.setColor(0.65, 0.60, 0.90)
    love.graphics.rectangle("line", bx, by, bw, bh, 8,8)
    if dialogue.npc.name and dialogue.npc.name ~= '' then
      love.graphics.setColor(0.95, 0.85, 0.40)
      love.graphics.print(dialogue.npc.name..":", bx+14, by+10)
      love.graphics.setColor(1, 0.96, 0.88)
      love.graphics.printf(dialogue.text, bx+14, by+28, bw-28, "left")
    else
      love.graphics.setColor(1, 0.96, 0.88)
      love.graphics.printf(dialogue.text, bx+14, by+16, bw-28, "left")
    end
    love.graphics.setColor(0.60, 0.55, 0.78)
    love.graphics.printf("Z / Enter to continue", bx, by+bh-18, bw, "center")
  end

  -- ── Shop overlay ─────────────────────────────────────────────────────────
  if shopState then
    local sw = math.min(W - 80, 480)
    local sh = 60 + #shopState.items * 44 + 30
    local sx = (W - sw) / 2
    local sy = (H - sh) / 2
    love.graphics.setColor(0.06, 0.05, 0.18, 0.97)
    love.graphics.rectangle("fill", sx, sy, sw, sh, 10,10)
    love.graphics.setColor(0.55, 0.50, 0.85)
    love.graphics.rectangle("line", sx, sy, sw, sh, 10,10)

    love.graphics.setColor(0.95, 0.88, 0.40)
    love.graphics.printf("TAMER MART", sx, sy+12, sw, "center")
    love.graphics.setColor(0.70, 0.65, 0.90)
    love.graphics.printf("Money: G "..GS.get().money, sx, sy+30, sw, "center")

    for i, item in ipairs(shopState.items) do
      local iy  = sy + 52 + (i-1)*44
      local sel = shopState.cursor == i
      if sel then
        love.graphics.setColor(0.30, 0.25, 0.55)
        love.graphics.rectangle("fill", sx+10, iy, sw-20, 38, 5,5)
        love.graphics.setColor(1, 1, 0.4)
      else
        love.graphics.setColor(0.90, 0.88, 1.0)
      end
      love.graphics.print((sel and "> " or "  ")..item.name, sx+20, iy+4)
      love.graphics.setColor(0.75, 0.70, 0.90)
      love.graphics.print(item.desc, sx+20, iy+20)
      love.graphics.setColor(0.85, 0.75, 0.30)
      love.graphics.printf("G "..item.price, sx+10, iy+4, sw-20, "right")
    end

    -- Shop message feedback
    if shopState.msg then
      love.graphics.setColor(0.70, 0.95, 0.65)
      love.graphics.printf(shopState.msg, sx, sy+sh-28, sw, "center")
    end

    love.graphics.setColor(0.50, 0.45, 0.70)
    love.graphics.printf("Z/Enter: Buy  X/Esc: Leave", sx, sy+sh-14, sw, "center")
  end

  -- ── Message overlay ───────────────────────────────────────────────────────
  if msgText and msgTimer > 0 and not dialogue and not shopState then
    local mw = math.min(W-40, 520)
    local mx = (W-mw)/2
    love.graphics.setColor(0,0,0,0.82)
    love.graphics.rectangle("fill", mx-8, H*0.72-8, mw+16, 40, 6,6)
    love.graphics.setColor(1, 0.95, 0.75)
    love.graphics.printf(msgText, mx, H*0.72, mw, "center")
  end

  -- ── Game Over overlay (permadeath) ────────────────────────────────────────
  if gameOverState then
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(0.90, 0.20, 0.20)
    love.graphics.printf("GAME OVER", 0, H*0.32, W, "center")
    love.graphics.setColor(0.80, 0.75, 0.90)
    love.graphics.printf("All your Riftborn have fallen.", 0, H*0.46, W, "center")
    love.graphics.setColor(0.50, 0.45, 0.65)
    love.graphics.printf("Returning to title...", 0, H*0.58, W, "center")
  end
end

function OW.exit() end

return OW
