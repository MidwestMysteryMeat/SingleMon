-- engine/game_state.lua
-- Global game state: player info, party, inventory, location, run mode.
-- Accessed globally as GS.
local Creatures = require("engine.creatures")
local Save      = require("engine.save")
local GS        = {}

local function defaultState(playerName, starterId, mode)
  local starter = Creatures.new(starterId, 5)
  return {
    playerName      = playerName,
    money           = 1000,
    mode            = mode or 'normal',
    party           = { starter },
    box             = {},
    inventory       = { bind_stone = 5, potion = 3 },
    location        = { map = "town", x = 9, y = 7 },
    steps           = 0,
    flags           = {},
    hallOfHeroes    = {},   -- fallen companions (permadeath modes)
    routeEncounters = {},   -- mapId → true when nuzlocke/hardcore used the slot
  }
end

function GS.new(playerName, starterId, mode)
  GS._state = defaultState(playerName, starterId, mode)
end

function GS.load()
  local data, err = Save.load()
  if not data then return false, err end
  -- Back-fill fields missing from older saves
  if data.box             == nil then data.box             = {} end
  if data.flags           == nil then data.flags           = {} end
  if data.hallOfHeroes    == nil then data.hallOfHeroes    = {} end
  if data.routeEncounters == nil then data.routeEncounters = {} end
  if data.mode            == nil then data.mode            = 'normal' end
  GS._state = data
  -- Bump the UID counter past all saved creature UIDs to prevent collisions
  local maxUid = 0
  for _, c in ipairs(data.party or {}) do
    if (c.uid or 0) > maxUid then maxUid = c.uid end
  end
  for _, c in ipairs(data.box or {}) do
    if (c.uid or 0) > maxUid then maxUid = c.uid end
  end
  Creatures.bumpUid(maxUid)
  return true
end

function GS.save()
  return Save.write(GS._state)
end

function GS.get() return GS._state end

-- ── Mode helpers ──────────────────────────────────────────────────────────────

function GS.isPermadeath()
  local m = GS._state.mode
  return m == 'nuzlocke' or m == 'hardcore' or m == 'monlocke'
end

function GS.isHardcore()
  return GS._state.mode == 'hardcore'
end

function GS.isMonlocke()
  return GS._state.mode == 'monlocke'
end

-- ── Party queries ─────────────────────────────────────────────────────────────

function GS.firstAlive()
  for _, c in ipairs(GS._state.party) do
    if c.stats.hp > 0 then return c end
  end
  return nil
end

function GS.isWiped()
  for _, c in ipairs(GS._state.party) do
    if c.stats.hp > 0 then return false end
  end
  return true
end

-- Returns true when party is empty AND mode is permadeath (true game over)
function GS.isGameOver()
  return GS.isPermadeath() and #GS._state.party == 0
end

function GS.healAll()
  for _, c in ipairs(GS._state.party) do
    c.stats.hp    = c.stats.maxHp
    c.status      = nil
    c.statusTurns = 0
    for _, mid in ipairs(c.moves) do
      local mv = DATA.moves[mid]
      c.pp[mid] = mv and mv.pp or 10
    end
  end
end

-- Permadeath: archive fainted creatures to hallOfHeroes and remove from party.
-- Call instead of healAll() when GS.isPermadeath() is true.
function GS.killFainted()
  local s = GS._state
  local survivors = {}
  for _, c in ipairs(s.party) do
    if c.stats.hp > 0 then
      survivors[#survivors+1] = c
    else
      s.hallOfHeroes[#s.hallOfHeroes+1] = {
        name      = c.nickname or c.name,
        speciesId = c.speciesId,
        level     = c.level,
        bondLevel = c.bondLevel,
      }
    end
  end
  s.party = survivors
end

-- ── Nuzlocke route tracking ───────────────────────────────────────────────────

function GS.markRouteEncountered(routeId)
  GS._state.routeEncounters[routeId] = true
end

function GS.routeHasEncountered(routeId)
  return GS._state.routeEncounters[routeId] == true
end

-- ── Inventory helpers ─────────────────────────────────────────────────────────

function GS.hasItem(id, qty)
  return (GS._state.inventory[id] or 0) >= (qty or 1)
end

function GS.addItem(id, qty)
  local s = GS._state
  s.inventory[id] = (s.inventory[id] or 0) + (qty or 1)
end

function GS.useItem(id, qty)
  qty = qty or 1
  if not GS.hasItem(id, qty) then return false end
  GS._state.inventory[id] = GS._state.inventory[id] - qty
  return true
end

-- Add a caught creature to party or box.
-- Monlocke caps party at 1; all overflow goes to box.
function GS.addCaught(creature)
  local s        = GS._state
  local maxParty = GS.isMonlocke() and 1 or 6
  if #s.party < maxParty then
    table.insert(s.party, creature)
  else
    table.insert(s.box, creature)
  end
end

return GS
