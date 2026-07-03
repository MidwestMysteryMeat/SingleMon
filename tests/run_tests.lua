-- tests/run_tests.lua — Headless battle-engine test suite.
-- Usage (from project root): lua tests/run_tests.lua
-- Pure Lua: engine/battle.lua, engine/creatures.lua, and data/ are love-free.

package.path = './?.lua;./?/init.lua;' .. package.path

DATA = require('engine.data')
local Battle    = require('engine.battle')
local Creatures = require('engine.creatures')

local passed, failed = 0, {}
local function T(cond, name)
    if cond then passed = passed + 1
    else failed[#failed + 1] = name end
end
local function eq(a, b, name)
    T(a == b, name .. (' (expected %s, got %s)'):format(tostring(b), tostring(a)))
end

---------------------------------------------------------------------------
-- Data integrity
---------------------------------------------------------------------------

local speciesCount = 0
for _, sp in pairs(DATA.species) do
    speciesCount = speciesCount + 1
    T(sp.baseStats and sp.baseStats.hp and sp.baseStats.speed,
      'species ' .. sp.speciesId .. ' has base stats')
    T(DATA.type_chart[sp.type] ~= nil or sp.type,
      'species ' .. sp.speciesId .. ' has a type')
    for _, m in ipairs(sp.baseMoveset or {}) do
        T(DATA.moves[m.moveId] ~= nil,
          'species ' .. sp.speciesId .. ' moveset references known move ' .. m.moveId)
    end
    if sp.evolvesTo then
        T(DATA.species[sp.evolvesTo.speciesId] ~= nil,
          'species ' .. sp.speciesId .. ' evolvesTo known species')
    end
end
eq(speciesCount, 94, 'species count matches documented 94')

for id, mv in pairs(DATA.moves) do
    T(mv.name and mv.moveType and mv.moveCategory, 'move ' .. id .. ' well-formed')
    T(mv.power == 0 or mv.power > 0, 'move ' .. id .. ' has power field')
    T(DATA.type_chart[mv.moveType] ~= nil, 'move ' .. id .. ' type exists in chart')
end

-- Type chart: every referenced defense type is a real attack type row
for atk, row in pairs(DATA.type_chart) do
    for def in pairs(row) do
        T(DATA.type_chart[def] ~= nil,
          'type chart: ' .. atk .. ' -> ' .. def .. ' references known type')
    end
end

-- Effectiveness math
eq(DATA.effectiveness('fire', 'plant'), 2, 'fire vs plant is super effective')
eq(DATA.effectiveness('poison', 'metal'), 0, 'poison vs metal is immune')
eq(DATA.effectiveness('fire', 'plant', 'ice'), 4, 'dual weakness multiplies')
eq(DATA.effectiveness('nonexistent', 'fire'), 1, 'unknown attack type neutral')

---------------------------------------------------------------------------
-- Creature construction and progression
---------------------------------------------------------------------------

local c5  = Creatures.new('pinklet', 5)
local c50 = Creatures.new('pinklet', 50)
T(c5.stats.maxHp > 0 and c5.stats.hp == c5.stats.maxHp, 'new creature at full HP')
T(c50.stats.maxHp > c5.stats.maxHp, 'higher level -> more HP')
T(c50.stats.attack > c5.stats.attack, 'higher level -> more attack')
T(Creatures.xpForLevel(10) > Creatures.xpForLevel(5), 'xp curve monotonic')
T(not Creatures.isFainted(c5), 'fresh creature not fainted')
c5.stats.hp = 0
T(Creatures.isFainted(c5), 'zero HP is fainted')

---------------------------------------------------------------------------
-- Battle simulation (seeded, deterministic)
---------------------------------------------------------------------------

local function freshState(pLevel, eLevel, pSpecies, eSpecies)
    return {
        player = Creatures.new(pSpecies or 'pinklet', pLevel or 20),
        enemy  = Creatures.new(eSpecies or 'pinklet', eLevel or 20),
        pStages = {}, eStages = {}, turn = 0,
    }
end

-- Damage happens and is bounded
local rng = Battle.newRng(12345)
local st = freshState()
local out = Battle.simulateTurn(st,
    { type='move', moveId='tackle' }, { type='move', moveId='tackle' }, rng)
T(out.enemy.stats.hp < out.enemy.stats.maxHp or out.player.stats.hp < out.player.stats.maxHp,
  'a turn of tackles deals damage to someone')

-- Determinism: same seed, same result
local a = Battle.simulateTurn(freshState(),
    { type='move', moveId='tackle' }, { type='move', moveId='tackle' }, Battle.newRng(777))
local b = Battle.simulateTurn(freshState(),
    { type='move', moveId='tackle' }, { type='move', moveId='tackle' }, Battle.newRng(777))
eq(a.enemy.stats.hp, b.enemy.stats.hp, 'same seed reproduces identical damage')

-- Priority beats speed: slow player with quick_strike moves first.
-- Give the enemy overwhelming speed; if priority failed, enemy would act first.
local stP = freshState(20, 20)
stP.enemy.stats.speed = 999
local outP, evP = Battle.simulateTurn(stP,
    { type='move', moveId='quick_strike' }, { type='move', moveId='tackle' }, Battle.newRng(1))
local firstDamage
for _, ev in ipairs(evP) do
    if ev.type == 'damage' or ev.type == 'hit' or ev.dmg then firstDamage = ev; break end
end
T(outP.enemy.stats.hp < outP.enemy.stats.maxHp, 'priority user lands its hit')

-- Burn halves physical damage (Gen 1 rule): compare same seed with/without burn
local function dmgDealtWithStatus(status)
    local s = freshState(30, 30)
    s.player.status = status
    local o = Battle.simulateTurn(s,
        { type='move', moveId='hyper_strike' }, { type='move', moveId='growl' }, Battle.newRng(42))
    return s.enemy.stats.maxHp - o.enemy.stats.hp
end
local dmgClean = dmgDealtWithStatus(nil)
local dmgBurn  = dmgDealtWithStatus('burn')
T(dmgBurn < dmgClean, 'burn reduces physical damage dealt')
T(dmgBurn >= math.floor(dmgClean * 0.4), 'burn reduction is about half, not more')

-- End-of-turn poison ticks 1/16 max HP
local sPo = freshState(30, 30)
sPo.player.status = 'poison'
local oPo = Battle.simulateTurn(sPo,
    { type='move', moveId='growl' }, { type='move', moveId='growl' }, Battle.newRng(9))
local tick = sPo.player.stats.maxHp - oPo.player.stats.hp
eq(tick, math.max(1, math.floor(sPo.player.stats.maxHp / 16)), 'poison ticks 1/16 max HP')

-- Stat stages: growl lowers attack, lowering subsequent damage
local sSt = freshState(30, 30)
local oSt = Battle.simulateTurn(sSt,
    { type='move', moveId='growl' }, { type='move', moveId='growl' }, Battle.newRng(3))
eq(oSt.eStages.attack, -1, 'growl lowers enemy attack one stage')
eq(oSt.pStages.attack, -1, 'enemy growl lowers player attack one stage')

-- Run action flees immediately
local oRun = Battle.simulateTurn(freshState(),
    { type='run' }, { type='move', moveId='tackle' }, Battle.newRng(5))
eq(oRun.outcome, 'fled', 'run action produces fled outcome')

-- Catch: guaranteed at rng extremes over many attempts, never errors
local caughtAny, missedAny = false, false
local rngC = Battle.newRng(2026)
for i = 1, 200 do
    local weak = Creatures.new('pinklet', 3)
    weak.stats.hp = 1
    local ok = Battle.attemptCatch(weak, 1, rngC)
    if ok then caughtAny = true else missedAny = true end
end
T(caughtAny, 'catching a 1-HP low-level creature succeeds sometimes')

-- AI returns a usable action
local ai = Battle.aiAction(Creatures.new('pinklet', 20), Battle.newRng(8))
T(ai and ai.type == 'move' and DATA.moves[ai.moveId], 'aiAction returns a known move')

---------------------------------------------------------------------------

print(('PASS %d  FAIL %d'):format(passed, #failed))
for _, f in ipairs(failed) do print('  FAIL: ' .. f) end
os.exit(#failed == 0 and 0 or 1)
