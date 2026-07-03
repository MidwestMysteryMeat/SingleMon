-- engine/battle.lua
-- Deterministic turn-based battle logic. Pure functions; no side effects on global state.
local PRNG    = require("lib.prng")
local Battle  = {}

-- Stat-stage multipliers (-6 to +6)
local STAGE = {}
for i = -6, 6 do
  STAGE[i] = math.max(2, 2 + i) / math.max(2, 2 - i)
end

local function stageOf(stages, stat) return stages[stat] or 0 end

-- Extract priority value from effects list (priority moves store it in effects)
local function getMovePriority(mv)
  if not mv then return 0 end
  for _, eff in ipairs(mv.effects or {}) do
    if eff.type == 'priority' then return eff.value end
  end
  return 0
end

-- Damage formula (Pokemon-style)
local function damage(attacker, defender, moveId, atkStages, defStages, rng)
  local mv = DATA.moves[moveId]
  if not mv or mv.power == 0 then return 0, 1 end

  local atk, def
  if mv.moveCategory == 'special' then
    atk = attacker.stats.spAttack  * STAGE[stageOf(atkStages,'spAttack')]
    def = defender.stats.spDefense * STAGE[stageOf(defStages,'spDefense')]
  else
    atk = attacker.stats.attack    * STAGE[stageOf(atkStages,'attack')]
    def = defender.stats.defense   * STAGE[stageOf(defStages,'defense')]
    if attacker.status == 'burn' then atk = math.floor(atk / 2) end
  end

  local sp    = DATA.species[attacker.speciesId]
  local stab  = (mv.moveType == sp.type or mv.moveType == sp.type2) and 1.5 or 1.0
  local ds    = DATA.species[defender.speciesId]
  local typeM = DATA.effectiveness(mv.moveType, ds.type, ds.type2)
  local roll  = 0.85 + rng:float() * 0.15

  local dmg = math.floor(math.floor(2 * attacker.level / 5 + 2) * mv.power * (atk / def) / 50 + 2)
  dmg = math.floor(dmg * typeM * stab * roll)
  return math.max(1, dmg), typeM
end

-- Apply one move from attacker onto defender; appends events
local function applyMove(attacker, defender, atkSt, defSt, moveId, rng, events)
  local mv = DATA.moves[moveId]
  if not mv then return end

  -- Consume PP
  if attacker.pp[moveId] and attacker.pp[moveId] > 0 then
    attacker.pp[moveId] = attacker.pp[moveId] - 1
  end

  -- Accuracy check (nil accuracy = always hits, e.g. struggle)
  -- Blind: halves accuracy even on normally-guaranteed moves
  local isBlind = attacker.status == 'blind'
  if mv.accuracy and (mv.accuracy < 100 or isBlind) then
    local acc   = (mv.accuracy or 100) * (STAGE[stageOf(atkSt,'accuracy')] or 1)
    local eva   = STAGE[stageOf(defSt,'evasion')] or 1
    local blind = isBlind and 0.5 or 1.0
    local hit   = acc / eva * blind
    if rng:int(1,100) > hit then
      events[#events+1] = { type='miss', user=attacker.speciesId, moveName=mv.name }
      return
    end
  end

  -- Damage
  if mv.power > 0 then
    local dmg, typeM = damage(attacker, defender, moveId, atkSt, defSt, rng)
    defender.stats.hp = math.max(0, defender.stats.hp - dmg)
    events[#events+1] = { type='damage', target=defender.speciesId, amount=dmg, typeM=typeM, moveName=mv.name }

    -- Recoil
    for _, eff in ipairs(mv.effects or {}) do
      if eff.type == 'recoil' then
        local recoil = math.max(1, math.floor(dmg * eff.fraction))
        attacker.stats.hp = math.max(0, attacker.stats.hp - recoil)
        events[#events+1] = { type='recoil', target=attacker.speciesId, amount=recoil }
      elseif eff.type == 'heal_damage_dealt' then
        local heal = math.max(1, math.floor(dmg * eff.fraction))
        attacker.stats.hp = math.min(attacker.stats.maxHp, attacker.stats.hp + heal)
        events[#events+1] = { type='heal', target=attacker.speciesId, amount=heal }
      end
    end
  end

  -- Non-damage effects
  for _, eff in ipairs(mv.effects or {}) do
    if eff.type == 'apply_status' and rng:chance(eff.chance) then
      local tgt = (eff.target == 'foe') and defender or attacker
      if not tgt.status then
        tgt.status      = eff.status
        tgt.statusTurns = 0
        events[#events+1] = { type='status_applied', target=tgt.speciesId, status=eff.status }
      end
    elseif eff.type == 'stat_change' then
      local tgt  = (eff.target == 'foe') and defSt or atkSt
      local stat = eff.stat
      tgt[stat]  = math.max(-6, math.min(6, (tgt[stat] or 0) + eff.stages))
      local who  = (eff.target == 'foe') and defender or attacker
      events[#events+1] = { type='stat_change', target=who.speciesId, stat=stat, stages=eff.stages }
    elseif eff.type == 'heal_self' then
      local heal = math.max(1, math.floor(attacker.stats.maxHp * eff.fraction))
      attacker.stats.hp = math.min(attacker.stats.maxHp, attacker.stats.hp + heal)
      events[#events+1] = { type='heal', target=attacker.speciesId, amount=heal }
    end
  end
end

-- Check if creature can move; appends event if it can't
local function canAct(c, rng, events)
  if c.status == 'sleep' then
    if rng:chance(0.33) then
      c.status = nil
      events[#events+1] = { type='wake', target=c.speciesId }
      return true
    end
    events[#events+1] = { type='cant_act', target=c.speciesId, reason='sleep' }
    return false
  elseif c.status == 'freeze' then
    if rng:chance(0.2) then
      c.status = nil
      events[#events+1] = { type='thaw', target=c.speciesId }
      return true
    end
    events[#events+1] = { type='cant_act', target=c.speciesId, reason='freeze' }
    return false
  elseif c.status == 'paralyze' then
    if rng:chance(0.25) then
      events[#events+1] = { type='cant_act', target=c.speciesId, reason='paralyze' }
      return false
    end
  end
  return true
end

-- End-of-turn status damage
local function endOfTurnStatus(c, events)
  if not c.status then return end
  local dmg = 0
  if c.status == 'poison' then
    dmg = math.max(1, math.floor(c.stats.maxHp / 16))
  elseif c.status == 'bad_poison' then
    c.statusTurns = (c.statusTurns or 0) + 1
    dmg = math.max(1, math.floor(c.stats.maxHp * c.statusTurns / 16))
  elseif c.status == 'burn' then
    dmg = math.max(1, math.floor(c.stats.maxHp / 16))
  end
  if dmg > 0 then
    c.stats.hp = math.max(0, c.stats.hp - dmg)
    events[#events+1] = { type='status_damage', target=c.speciesId, amount=dmg, status=c.status }
  end
end

-- Shallow copy of a creature table (deep copy stats and pp sub-tables)
local function copyCrea(c)
  local n = {}
  for k,v in pairs(c) do
    if type(v) == 'table' then
      local t = {}; for k2,v2 in pairs(v) do t[k2] = v2 end
      n[k] = t
    else n[k] = v end
  end
  return n
end

-- Simulate one full turn. Returns (newState, events[]).
-- state = { player, enemy, pStages, eStages, turn }
-- action = { type='move', moveId } | { type='item', itemId } | { type='run' }
function Battle.simulateTurn(state, pAction, eAction, rng)
  local p  = copyCrea(state.player)
  local e  = copyCrea(state.enemy)
  local ps = {}; for k,v in pairs(state.pStages or {}) do ps[k]=v end
  local es = {}; for k,v in pairs(state.eStages or {}) do es[k]=v end
  local events = {}
  local turn   = (state.turn or 0) + 1

  if pAction.type == 'run' then
    events[#events+1] = { type='fled' }
    return { player=p, enemy=e, pStages=ps, eStages=es, turn=turn, outcome='fled' }, events
  end

  -- Determine who goes first (priority > speed)
  local pMv    = pAction.type == 'move' and DATA.moves[pAction.moveId]
  local eMv    = eAction.type == 'move' and DATA.moves[eAction.moveId]
  local pPri   = getMovePriority(pMv)
  local ePri   = getMovePriority(eMv)
  local pFirst = pPri > ePri or
                 (pPri == ePri and (p.stats.speed > e.stats.speed or
                                    (p.stats.speed == e.stats.speed and rng:chance(0.5))))

  local function act(actor, actorSt, target, targetSt, action)
    if action.type == 'move' then
      if canAct(actor, rng, events) then
        applyMove(actor, target, actorSt, targetSt, action.moveId, rng, events)
      end
    end
  end

  if pFirst then
    act(p, ps, e, es, pAction)
    if e.stats.hp > 0 then act(e, es, p, ps, eAction) end
  else
    act(e, es, p, ps, eAction)
    if p.stats.hp > 0 then act(p, ps, e, es, pAction) end
  end

  if p.stats.hp > 0 then endOfTurnStatus(p, events) end
  if e.stats.hp > 0 then endOfTurnStatus(e, events) end

  local outcome = 'ongoing'
  if     p.stats.hp <= 0 and e.stats.hp <= 0 then outcome = 'draw'
  elseif p.stats.hp <= 0                      then outcome = 'player_lost'
  elseif e.stats.hp <= 0                      then outcome = 'player_won'
  end

  return { player=p, enemy=e, pStages=ps, eStages=es, turn=turn, outcome=outcome }, events
end

-- Catch attempt: returns true if the creature is caught
function Battle.attemptCatch(enemy, tier, rng)
  local sp      = DATA.species[enemy.speciesId]
  local rate    = sp and sp.catchRate or 45
  local hpRatio = enemy.stats.hp / enemy.stats.maxHp
  local chance  = (rate / 255) * (1.5 - hpRatio) * (tier or 1)
  return rng:chance(math.min(0.95, chance))
end

-- Simple enemy AI: pick a random move that still has PP
function Battle.aiAction(enemy, rng)
  local avail = {}
  for _, mid in ipairs(enemy.moves) do
    if (enemy.pp[mid] or 0) > 0 then avail[#avail+1] = mid end
  end
  if #avail == 0 then return { type='move', moveId='struggle' } end
  return { type='move', moveId=avail[rng:int(1,#avail)] }
end

-- Create a seeded RNG for a battle session
function Battle.newRng(seed)
  return PRNG.new(seed or os.time())
end

return Battle
