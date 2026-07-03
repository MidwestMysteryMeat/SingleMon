-- engine/creatures.lua
-- Creature instance creation and stat computation.
local Creatures = {}

local _uid = 0
local function nextUid() _uid = _uid + 1; return _uid end

-- Call after loading a save to prevent UID collisions with saved creatures.
function Creatures.bumpUid(maxSeen)
  if maxSeen and maxSeen > _uid then _uid = maxSeen end
end

local function calcHP(base, level)
  return math.floor((2 * base + 31) * level / 100) + level + 10
end
local function calcStat(base, level)
  return math.floor((2 * base + 31) * level / 100) + 5
end

-- Create a new creature at the given level
function Creatures.new(speciesId, level)
  local sp = DATA.species[speciesId]
  assert(sp, "Unknown species: " .. tostring(speciesId))
  local bs = sp.baseStats
  local maxHp = calcHP(bs.hp, level)
  local moves  = DATA.getStartMoves(speciesId, level)

  local pp = {}
  for _, mid in ipairs(moves) do
    local mv = DATA.moves[mid]
    pp[mid] = mv and mv.pp or 10
  end

  return {
    uid          = nextUid(),
    speciesId    = speciesId,
    name         = sp.name,
    nickname     = nil,
    level        = level,
    xp           = 0,
    xpToNext     = Creatures.xpForLevel(level + 1),
    bondLevel    = 1,
    bondXp       = 0,
    status       = nil,    -- 'poison','bad_poison','burn','paralyze','sleep','freeze'
    statusTurns  = 0,
    moves        = moves,  -- up to 4 active move IDs
    pp           = pp,
    stats = {
      maxHp     = maxHp,
      hp        = maxHp,
      attack    = calcStat(bs.attack,    level),
      spAttack  = calcStat(bs.spAttack,  level),
      defense   = calcStat(bs.defense,   level),
      spDefense = calcStat(bs.spDefense, level),
      speed     = calcStat(bs.speed,     level),
    },
  }
end

-- XP threshold for a level (simple cubic)
function Creatures.xpForLevel(lvl)
  return math.floor(lvl ^ 3 * 0.8)
end

-- Bond XP needed to advance from bondLevel to bondLevel+1
function Creatures.bondXpNeeded(bondLevel)
  return bondLevel * 50
end

-- Grant bond XP; returns true if bond level advanced
function Creatures.grantBondXp(c, amount)
  if c.bondLevel >= 10 then return false end
  c.bondXp = (c.bondXp or 0) + amount
  local leveled = false
  while c.bondLevel < 10 and c.bondXp >= Creatures.bondXpNeeded(c.bondLevel) do
    c.bondXp    = c.bondXp - Creatures.bondXpNeeded(c.bondLevel)
    c.bondLevel = c.bondLevel + 1
    leveled     = true
  end
  return leveled
end

-- Recalculate stats in-place after level change (preserves HP ratio)
function Creatures.recalcStats(c)
  local sp = DATA.species[c.speciesId]
  local bs = sp.baseStats
  local ratio = c.stats.hp / c.stats.maxHp
  c.stats.maxHp     = calcHP(bs.hp, c.level)
  if ratio <= 0 then
    c.stats.hp = 0
  else
    c.stats.hp = math.max(1, math.floor(c.stats.maxHp * ratio))
  end
  c.stats.attack    = calcStat(bs.attack,    c.level)
  c.stats.spAttack  = calcStat(bs.spAttack,  c.level)
  c.stats.defense   = calcStat(bs.defense,   c.level)
  c.stats.spDefense = calcStat(bs.spDefense, c.level)
  c.stats.speed     = calcStat(bs.speed,     c.level)
  c.xpToNext        = Creatures.xpForLevel(c.level + 1)
end

-- Grant XP; returns true if at least one level-up occurred
function Creatures.grantXp(c, amount)
  c.xp = c.xp + amount
  local leveled = false
  while c.level < 100 and c.xp >= c.xpToNext do
    c.xp     = c.xp - c.xpToNext
    c.level  = c.level + 1
    Creatures.recalcStats(c)
    leveled = true
  end
  return leveled
end

-- Add a new move learned on level-up; replaces the oldest if already 4 moves
function Creatures.learnMove(c, moveId)
  if #c.moves < 4 then
    table.insert(c.moves, moveId)
  else
    -- Forget the first move (oldest), shift, append new
    table.remove(c.moves, 1)
    table.insert(c.moves, moveId)
  end
  local mv = DATA.moves[moveId]
  c.pp[moveId] = mv and mv.pp or 10
end

-- Check if the creature is ready to evolve; returns new speciesId or nil
function Creatures.checkEvolution(c)
  local sp = DATA.species[c.speciesId]
  if sp and sp.evolvesTo and c.bondLevel >= sp.evolvesTo.atBondLevel then
    return sp.evolvesTo.speciesId
  end
  return nil
end

-- Evolve creature in-place
function Creatures.evolve(c, newSpeciesId)
  local newSp = DATA.species[newSpeciesId]
  assert(newSp, "Unknown species for evolution: " .. tostring(newSpeciesId))
  c.speciesId = newSpeciesId
  c.name      = newSp.name
  Creatures.recalcStats(c)
end

-- Display name: nickname if set, else species name
function Creatures.displayName(c)
  return c.nickname or c.name
end

function Creatures.isFainted(c)
  return c.stats.hp <= 0
end

return Creatures
