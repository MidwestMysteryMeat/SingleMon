-- data/trainers.lua
-- Procedural NPC trainer generation with themed species pools.
-- Trainers.generate(theme, baseLevel, numMons) → { name, style, party: [{speciesId, level}] }

local Trainers = {}

local FIRST_NAMES = {
  'Kael','Mira','Torvyn','Sela','Doran','Lysse','Brek','Vantha',
  'Osric','Tali','Fenwick','Runa','Cador','Ishel','Pryn','Voss',
  'Amara','Jet','Sable','Wyren','Dusk','Fen','Mord','Pela',
}

-- Each theme: style title + weighted species pool (repeated entries = higher weight)
local THEME_TRAINERS = {
  shadow_realm     = { style='Shadow Stalker',  pool={'shadowchick','specter','shadowchick','voidpup'} },
  void_debris      = { style='Void Sifter',     pool={'voidpup','shadowchick','dustpup','voidpup'} },
  astral_rift      = { style='Rift Scholar',    pool={'voidpup','specter','stormchick','seraphin'} },
  abyssal_dark     = { style='Abyss Walker',    pool={'shadowchick','specter','dustpup','shadowchick'} },
  lich_sanctum     = { style='Sanctum Warden',  pool={'specter','seraphin','shadowchick','voidpup'} },
  crystal_cavern   = { style='Gem Seeker',      pool={'frostkit','dustpup','graycub','frostkit'} },
  lava_rift        = { style='Flame Tamer',     pool={'emberfox','sinderflare','emberfox','graycub'} },
  flooded_ruins    = { style='Ruin Diver',      pool={'tidelet','coildepth','tidelet','specter'} },
  frozen_depths    = { style='Frost Warden',    pool={'frostkit','dustpup','frostkit','graycub'} },
  fungal_forest    = { style='Spore Keeper',    pool={'thorngrub','coildepth','thorngrub','tawnykit'} },
  bone_yard        = { style='Bone Collector',  pool={'specter','shadowchick','dustpup','specter'} },
  coral_grotto     = { style='Tide Walker',     pool={'tidelet','coildepth','stormchick','tidelet'} },
  infernal_pit     = { style='Ember Fist',      pool={'emberfox','sinderflare','shadowchick','emberfox'} },
  dragons_den      = { style='Dragon Tamer',    pool={'sinderflare','emberfox','dustpup','sinderflare'} },
  plague_warren    = { style='Plague Doctor',   pool={'thorngrub','coildepth','shadowchick','thorngrub'} },
  spider_hive      = { style='Web Weaver',      pool={'thorngrub','dustpup','shadowchick','thorngrub'} },
  frost_citadel    = { style='Ice Knight',      pool={'frostkit','dustpup','stormchick','frostkit'} },
  sunken_depths    = { style='Deep Diver',      pool={'tidelet','coildepth','frostkit','tidelet'} },
  troll_caves      = { style='Cave Brawler',    pool={'graycub','dustpup','tawnykit','graycub'} },
  floating_islands = { style='Sky Tamer',       pool={'stormchick','voidpup','tawnykit','stormchick'} },
  clockwork_maze   = { style='Gear Master',     pool={'dustpup','stormchick','voidpup','dustpup'} },
  sand_tomb        = { style='Desert Rider',    pool={'graycub','sinderflare','tawnykit','graycub'} },
  ruined_village   = { style='Salvager',        pool={'tawnykit','shadowchick','specter','tawnykit'} },
  overgrown_temple = { style='Veil Keeper',     pool={'thorngrub','seraphin','tawnykit','thorngrub'} },
  ancient_library  = { style='Lore Keeper',     pool={'voidpup','seraphin','specter','voidpup'} },
  catacombs        = { style='Tomb Raider',     pool={'specter','shadowchick','dustpup','specter'} },
  dinosaur_jungle  = { style='Wild Tamer',      pool={'sinderflare','graycub','thorngrub','tawnykit'} },
  werewolf_den     = { style='Pack Leader',     pool={'tawnykit','shadowchick','tawnykit','dustpup'} },
  vampire_castle   = { style='Blood Tamer',     pool={'shadowchick','specter','seraphin','shadowchick'} },
}

local DEFAULT_STYLE = { style='Rift Tamer', pool={'tawnykit','shadowchick','specter','voidpup'} }

-- generate(theme, baseLevel, numMons) → { name, style, party }
-- numMons: how many party members (default 1)
-- party entries: { speciesId, level }
function Trainers.generate(theme, baseLevel, numMons)
  local data      = THEME_TRAINERS[theme] or DEFAULT_STYLE
  local firstName = FIRST_NAMES[math.random(#FIRST_NAMES)]
  local name      = firstName .. ' the ' .. data.style
  local size      = numMons or 1
  local pool      = data.pool
  local party     = {}
  for i = 1, size do
    local speciesId = pool[math.random(#pool)]
    local level     = math.max(1, math.min(100, baseLevel + (i - 1)))
    party[#party+1] = { speciesId=speciesId, level=level }
  end
  return { name=name, style=data.style, party=party }
end

-- generateForRoute(theme, baseLevel) → same as generate but party size is 1
function Trainers.generateForRoute(theme, baseLevel)
  return Trainers.generate(theme, baseLevel, 1)
end

return Trainers
