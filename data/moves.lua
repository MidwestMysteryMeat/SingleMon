-- data/moves.lua
-- Full move database, ported from monclone server/move-data.js.
-- moveCategory: 'blunt'|'slash'|'pierce'|'special'|'status'
-- Physical categories (blunt/slash/pierce) use attack vs defense.
-- 'special' uses spAttack vs spDefense.
-- effects: list of { type, ... }
return {

  -- PLANT (base physical)
  tackle       = { name='Tackle',        moveType='plant',     moveCategory='blunt',   power=35,  accuracy=95,  pp=35, effects={} },
  growl        = { name='Growl',         moveType='plant',     moveCategory='status',  power=0,   accuracy=100, pp=40, effects={{type='stat_change',target='foe',stat='attack',stages=-1,chance=1.0}} },
  quick_strike = { name='Quick Strike',  moveType='plant',     moveCategory='pierce',  power=40,  accuracy=100, pp=30, effects={{type='priority',value=1}} },
  body_slam    = { name='Body Slam',     moveType='plant',     moveCategory='blunt',   power=85,  accuracy=100, pp=15, effects={{type='apply_status',status='paralyze',chance=0.30}} },
  focus_charge = { name='Focus Charge',  moveType='plant',     moveCategory='status',  power=0,   accuracy=100, pp=20, effects={{type='stat_change',target='self',stat='attack',stages=1,chance=1.0}} },
  hyper_strike = { name='Hyper Strike',  moveType='plant',     moveCategory='blunt',   power=100, accuracy=90,  pp=10, effects={} },
  recovery     = { name='Recovery',      moveType='plant',     moveCategory='status',  power=0,   accuracy=100, pp=10, effects={{type='heal_self',fraction=0.5}} },
  absorb       = { name='Absorb',        moveType='plant',     moveCategory='special', power=30,  accuracy=100, pp=20, effects={{type='heal_damage_dealt',fraction=0.5}} },

  -- FIRE
  ember_shot   = { name='Ember Shot',    moveType='fire',      moveCategory='pierce',  power=40,  accuracy=100, pp=25, effects={} },
  scorch       = { name='Scorch',        moveType='fire',      moveCategory='status',  power=0,   accuracy=100, pp=20, effects={{type='stat_change',target='foe',stat='attack',stages=-1,chance=1.0}} },
  flame_burst  = { name='Flame Burst',   moveType='fire',      moveCategory='special', power=60,  accuracy=100, pp=15, effects={} },
  heat_crash   = { name='Heat Crash',    moveType='fire',      moveCategory='blunt',   power=65,  accuracy=100, pp=15, effects={{type='apply_status',status='burn',chance=0.10}} },
  blaze_rush   = { name='Blaze Rush',    moveType='fire',      moveCategory='pierce',  power=40,  accuracy=100, pp=20, effects={{type='priority',value=1}} },
  inferno_wave = { name='Inferno Wave',  moveType='fire',      moveCategory='special', power=85,  accuracy=90,  pp=10, effects={{type='apply_status',status='burn',chance=0.10}} },

  -- WATER
  water_jet    = { name='Water Jet',     moveType='water',     moveCategory='pierce',  power=40,  accuracy=100, pp=25, effects={} },
  damp_mist    = { name='Damp Mist',     moveType='water',     moveCategory='status',  power=0,   accuracy=100, pp=20, effects={{type='stat_change',target='foe',stat='accuracy',stages=-1,chance=1.0}} },
  tide_pulse   = { name='Tide Pulse',    moveType='water',     moveCategory='special', power=60,  accuracy=100, pp=15, effects={} },
  aqua_slam    = { name='Aqua Slam',     moveType='water',     moveCategory='blunt',   power=70,  accuracy=90,  pp=10, effects={} },
  torrential_blast = { name='Torrential Blast', moveType='water', moveCategory='special', power=90, accuracy=85, pp=10, effects={} },

  -- ICE
  frost_bite     = { name='Frost Bite',     moveType='ice', moveCategory='pierce',  power=50,  accuracy=95,  pp=20, effects={{type='apply_status',status='freeze',chance=0.10}} },
  chill_wind     = { name='Chill Wind',     moveType='ice', moveCategory='special', power=60,  accuracy=100, pp=15, effects={} },
  blizzard_shard = { name='Blizzard Shard', moveType='ice', moveCategory='special', power=70,  accuracy=90,  pp=10, effects={{type='apply_status',status='freeze',chance=0.10}} },
  ice_crash      = { name='Ice Crash',      moveType='ice', moveCategory='blunt',   power=80,  accuracy=90,  pp=10, effects={} },
  glacial_wave   = { name='Glacial Wave',   moveType='ice', moveCategory='special', power=95,  accuracy=100, pp=5,  effects={} },
  ice_shard      = { name='Ice Shard',      moveType='ice', moveCategory='pierce',  power=40,  accuracy=100, pp=30, effects={{type='priority',value=1}} },
  frost_drain    = { name='Frost Drain',    moveType='ice', moveCategory='special', power=55,  accuracy=100, pp=10, effects={{type='heal_damage_dealt',fraction=0.5}} },

  -- LIGHTNING
  spark_strike  = { name='Spark Strike',  moveType='lightning', moveCategory='pierce',  power=40, accuracy=100, pp=30, effects={} },
  static_field  = { name='Static Field',  moveType='lightning', moveCategory='status',  power=0,  accuracy=100, pp=20, effects={{type='apply_status',status='paralyze',chance=1.0}} },
  volt_surge    = { name='Volt Surge',    moveType='lightning', moveCategory='special', power=65, accuracy=100, pp=15, effects={} },
  charge_tackle = { name='Charge Tackle', moveType='lightning', moveCategory='blunt',   power=80, accuracy=100, pp=10, effects={{type='priority',value=1}} },
  thunder_crash = { name='Thunder Crash', moveType='lightning', moveCategory='special', power=95, accuracy=75,  pp=10, effects={{type='apply_status',status='paralyze',chance=0.30}} },

  -- EARTH
  stone_throw   = { name='Stone Throw',   moveType='earth', moveCategory='pierce',  power=50,  accuracy=90,  pp=15, effects={} },
  mud_toss      = { name='Mud Toss',      moveType='earth', moveCategory='special', power=55,  accuracy=95,  pp=15, effects={{type='stat_change',target='foe',stat='accuracy',stages=-1,chance=1.0}} },
  boulder_crush = { name='Boulder Crush', moveType='earth', moveCategory='blunt',   power=75,  accuracy=100, pp=10, effects={} },
  quake_slam    = { name='Quake Slam',    moveType='earth', moveCategory='blunt',   power=90,  accuracy=100, pp=10, effects={} },
  sand_throw    = { name='Sand Throw',    moveType='earth', moveCategory='status',  power=0,   accuracy=100, pp=20, effects={{type='apply_status',status='blind',chance=1.0}} },

  -- METAL (harden is metal-typed, categorized with earth section in source)
  harden      = { name='Harden',       moveType='metal', moveCategory='status',  power=0,  accuracy=100, pp=30, effects={{type='stat_change',target='self',stat='defense',stages=1,chance=1.0}} },
  iron_strike = { name='Iron Strike',  moveType='metal', moveCategory='slash',   power=50, accuracy=100, pp=20, effects={} },
  shield_bash = { name='Shield Bash',  moveType='metal', moveCategory='blunt',   power=65, accuracy=100, pp=15, effects={{type='stat_change',target='self',stat='defense',stages=1,chance=1.0}} },
  metal_slam  = { name='Metal Slam',   moveType='metal', moveCategory='blunt',   power=80, accuracy=100, pp=10, effects={} },
  steel_crush = { name='Steel Crush',  moveType='metal', moveCategory='blunt',   power=95, accuracy=90,  pp=10, effects={} },
  iron_sweep  = { name='Iron Sweep',   moveType='metal', moveCategory='slash',   power=60, accuracy=100, pp=15, effects={} },
  iron_fang   = { name='Iron Fang',    moveType='metal', moveCategory='pierce',  power=50, accuracy=95,  pp=15, effects={{type='stat_change',target='foe',stat='defense',stages=-1,chance=0.10}} },
  steel_guard = { name='Steel Guard',  moveType='metal', moveCategory='status',  power=0,  accuracy=100, pp=20, effects={{type='stat_change',target='self',stat='defense',stages=2,chance=1.0}} },
  metal_crash = { name='Metal Crash',  moveType='metal', moveCategory='blunt',   power=90, accuracy=85,  pp=10, effects={{type='recoil',fraction=0.25}} },

  -- INFERNAL
  shadow_claw  = { name='Shadow Claw',   moveType='infernal', moveCategory='slash',   power=50, accuracy=100, pp=15, effects={} },
  night_shroud = { name='Night Shroud',  moveType='infernal', moveCategory='status',  power=0,  accuracy=100, pp=20, effects={{type='apply_status',status='blind',chance=0.80}} },
  soul_drain   = { name='Soul Drain',    moveType='infernal', moveCategory='special', power=60, accuracy=100, pp=10, effects={{type='heal_damage_dealt',fraction=0.5}} },
  void_pulse   = { name='Shadow Pulse',  moveType='infernal', moveCategory='special', power=80, accuracy=100, pp=10, effects={} },
  abyss_strike = { name='Abyss Strike',  moveType='infernal', moveCategory='slash',   power=85, accuracy=90,  pp=10, effects={} },

  -- CELESTIAL
  radiant_strike  = { name='Radiant Strike',  moveType='celestial', moveCategory='special', power=45, accuracy=100, pp=25, effects={} },
  blessing_ward   = { name='Blessing Ward',   moveType='celestial', moveCategory='status',  power=0,  accuracy=100, pp=20, effects={{type='stat_change',target='self',stat='spDefense',stages=1,chance=1.0}} },
  light_beam      = { name='Light Beam',      moveType='celestial', moveCategory='special', power=65, accuracy=100, pp=15, effects={} },
  sacred_mend     = { name='Sacred Mend',     moveType='celestial', moveCategory='status',  power=0,  accuracy=100, pp=10, effects={{type='heal_self',fraction=0.5}} },
  moonlight       = { name='Moonlight',       moveType='celestial', moveCategory='status',  power=0,  accuracy=100, pp=5,  effects={{type='heal_self',fraction=0.33}} },
  blinding_flash  = { name='Blinding Flash',  moveType='celestial', moveCategory='status',  power=0,  accuracy=100, pp=20, effects={{type='apply_status',status='blind',chance=1.0}} },
  divine_judgment = { name='Divine Judgment', moveType='celestial', moveCategory='special', power=90, accuracy=100, pp=10, effects={} },

  -- POISON
  toxic_bite       = { name='Toxic Bite',       moveType='poison', moveCategory='pierce',  power=45, accuracy=100, pp=25, effects={{type='apply_status',status='poison',chance=0.30}} },
  venom_cloud      = { name='Venom Cloud',      moveType='poison', moveCategory='special', power=60, accuracy=100, pp=15, effects={{type='apply_status',status='bad_poison',chance=0.20}} },
  acid_spray       = { name='Acid Spray',       moveType='poison', moveCategory='special', power=40, accuracy=100, pp=20, effects={{type='stat_change',target='foe',stat='defense',stages=-1,chance=1.0}} },
  corrosive_strike = { name='Corrosive Strike', moveType='poison', moveCategory='slash',   power=75, accuracy=90,  pp=10, effects={{type='apply_status',status='poison',chance=0.30}} },
  plague_wave      = { name='Plague Wave',      moveType='poison', moveCategory='special', power=90, accuracy=90,  pp=10, effects={{type='apply_status',status='bad_poison',chance=0.20}} },
  spore_cloud      = { name='Spore Cloud',      moveType='poison', moveCategory='status',  power=0,  accuracy=100, pp=15, effects={{type='apply_status',status='sleep',chance=1.0}} },
  toxic_smoke      = { name='Toxic Smoke',      moveType='poison', moveCategory='status',  power=0,  accuracy=90,  pp=15, effects={{type='apply_status',status='blind',chance=1.0}} },
  poison_sting     = { name='Poison Sting',     moveType='poison', moveCategory='pierce',  power=35, accuracy=100, pp=35, effects={{type='apply_status',status='poison',chance=0.30}} },

  -- VOID
  mystic_bolt  = { name='Mystic Bolt',  moveType='void', moveCategory='special', power=40, accuracy=100, pp=25, effects={} },
  phase_shift  = { name='Phase Shift',  moveType='void', moveCategory='status',  power=0,  accuracy=100, pp=20, effects={{type='stat_change',target='self',stat='evasion',stages=1,chance=1.0}} },
  arcane_surge = { name='Arcane Surge', moveType='void', moveCategory='special', power=70, accuracy=100, pp=15, effects={} },
  mana_burst   = { name='Mana Burst',   moveType='void', moveCategory='special', power=80, accuracy=100, pp=10, effects={} },
  rift_tear    = { name='Rift Tear',    moveType='void', moveCategory='special', power=95, accuracy=90,  pp=10, effects={} },
  void_drain   = { name='Void Drain',   moveType='void', moveCategory='special', power=60, accuracy=100, pp=10, effects={{type='heal_damage_dealt',fraction=0.5}} },
  null_wave    = { name='Null Wave',    moveType='void', moveCategory='special', power=75, accuracy=90,  pp=10, effects={} },

  -- GHOST
  shadow_touch  = { name='Shadow Touch',  moveType='ghost', moveCategory='special', power=40, accuracy=100, pp=25, effects={} },
  haunt         = { name='Haunt',         moveType='ghost', moveCategory='status',  power=0,  accuracy=100, pp=20, effects={{type='stat_change',target='foe',stat='accuracy',stages=-1,chance=1.0}} },
  hypnosis      = { name='Hypnosis',      moveType='ghost', moveCategory='status',  power=0,  accuracy=60,  pp=20, effects={{type='apply_status',status='sleep',chance=1.0}} },
  spectral_rush = { name='Spectral Rush', moveType='ghost', moveCategory='pierce',  power=65, accuracy=100, pp=15, effects={} },
  phase_walk    = { name='Phase Walk',    moveType='ghost', moveCategory='pierce',  power=40, accuracy=100, pp=20, effects={{type='priority',value=1}} },
  soul_rend     = { name='Soul Rend',     moveType='ghost', moveCategory='special', power=90, accuracy=95,  pp=10, effects={} },

  -- ARCANE
  mana_spark   = { name='Mana Spark',   moveType='arcane', moveCategory='special', power=40,  accuracy=100, pp=30, effects={} },
  rune_strike  = { name='Rune Strike',  moveType='arcane', moveCategory='special', power=60,  accuracy=100, pp=20, effects={} },
  arcane_pulse = { name='Arcane Pulse', moveType='arcane', moveCategory='special', power=75,  accuracy=95,  pp=15, effects={{type='stat_change',target='foe',stat='spDefense',stages=-1,chance=0.20}} },
  spellbind    = { name='Spellbind',    moveType='arcane', moveCategory='status',  power=0,   accuracy=90,  pp=20, effects={{type='apply_status',status='paralyze',chance=1.0}} },
  ley_surge    = { name='Ley Surge',    moveType='arcane', moveCategory='special', power=90,  accuracy=90,  pp=10, effects={} },
  void_mirror  = { name='Void Mirror',  moveType='arcane', moveCategory='special', power=80,  accuracy=85,  pp=10, effects={{type='stat_change',target='foe',stat='attack',stages=-1,chance=0.30}} },
  rift_brand   = { name='Rift Brand',   moveType='arcane', moveCategory='special', power=110, accuracy=80,  pp=5,  effects={{type='recoil',fraction=0.10}} },

  -- STRUGGLE (used when all moves have 0 PP)
  struggle     = { name='Struggle',     moveType='plant',  moveCategory='blunt',   power=50,  accuracy=nil, pp=nil, effects={{type='recoil',fraction=0.25}} },
}
