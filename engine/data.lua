-- engine/data.lua
-- Loads and indexes species, moves, and type chart. Accessed globally as DATA.
local DATA = {}

local type_chart  = require("data.type_chart")
local moves_raw   = require("data.moves")
local species_raw = require("data.species")
local Trainers    = require("data.trainers")

-- Index species by speciesId for O(1) lookup
DATA.species = {}
for _, sp in ipairs(species_raw) do
  DATA.species[sp.speciesId] = sp
end
DATA.speciesList = species_raw

DATA.moves       = moves_raw
DATA.type_chart  = type_chart
DATA.Trainers    = Trainers

-- Type effectiveness: attack type vs one or two defense types
function DATA.effectiveness(atkType, defType1, defType2)
  local row = type_chart[atkType]
  if not row then return 1 end
  local m1 = row[defType1] or 1
  local m2 = defType2 and (row[defType2] or 1) or 1
  return m1 * m2
end

-- Returns all move IDs a species naturally learns up to a given level
function DATA.getLearnedMoves(speciesId, level)
  local sp = DATA.species[speciesId]
  if not sp then return {} end
  local learned = {}
  for _, entry in ipairs(sp.baseMoveset) do
    if entry.learnLevel <= level then
      learned[#learned+1] = entry.moveId
    end
  end
  return learned
end

-- Returns up to 4 active moves for a species at a given level (last 4 learned)
function DATA.getStartMoves(speciesId, level)
  local all   = DATA.getLearnedMoves(speciesId, level)
  local start = math.max(1, #all - 3)
  local active = {}
  for i = start, #all do active[#active+1] = all[i] end
  return active
end

-- Returns the next move a species learns after the current level, or nil
function DATA.getNextLearnedMove(speciesId, level)
  local sp = DATA.species[speciesId]
  if not sp then return nil end
  for _, entry in ipairs(sp.baseMoveset) do
    if entry.learnLevel > level then
      return entry.moveId, entry.learnLevel
    end
  end
  return nil
end

-- Type display string
function DATA.typeLabel(type1, type2)
  if not type1 then return "???" end
  local t1 = type1:sub(1,1):upper()..type1:sub(2)
  if not type2 then return t1 end
  return t1.." / "..type2:sub(1,1):upper()..type2:sub(2)
end

-- Type badge colors (r,g,b 0-1)
local TYPE_COLORS = {
  fire      = {0.95,0.35,0.15},
  water     = {0.25,0.55,0.95},
  ice       = {0.55,0.85,0.95},
  lightning = {0.95,0.85,0.10},
  earth     = {0.75,0.55,0.25},
  infernal  = {0.60,0.15,0.55},
  celestial = {0.95,0.90,0.45},
  poison    = {0.65,0.25,0.75},
  void      = {0.25,0.15,0.45},
  ghost     = {0.40,0.30,0.60},
  metal     = {0.65,0.70,0.75},
  plant     = {0.30,0.70,0.25},
  arcane    = {0.70,0.40,0.90},
}
function DATA.typeColor(typeName)
  return TYPE_COLORS[typeName] or {0.5,0.5,0.5}
end

return DATA
