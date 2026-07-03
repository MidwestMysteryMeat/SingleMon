-- data/type_chart.lua
-- TYPE_CHART[attackType][defenseType] = multiplier. Omitted = 1.0.
return {
  fire      = { fire=0.5, water=0.5, earth=0.5, ice=2,   plant=2,   metal=2   },
  water     = { water=0.5, plant=0.5, ice=0.5,  fire=2,   earth=2                },
  ice       = { fire=0.5, ice=0.5,   water=0.5, plant=2,  earth=2                },
  lightning = { lightning=0.5, earth=0.5, plant=0.5, ghost=0.5, water=2, metal=2 },
  earth     = { earth=0.5,            fire=2,   lightning=2, poison=2, void=2    },
  infernal  = { infernal=0.5, celestial=0.5,    ghost=2,  void=2,    arcane=2    },
  celestial = { celestial=0.5, void=0.5,        infernal=2, ghost=2, poison=2    },
  poison    = { fire=0.5, ghost=0.5, poison=0.5, metal=0, plant=2,   water=2     },
  void      = { void=0.5, metal=0.5,             infernal=2, celestial=2, ghost=2, arcane=2 },
  ghost     = { infernal=0.5, celestial=0.5, void=0.5, metal=0, ghost=2, plant=2 },
  metal     = { earth=0.5, metal=0.5, fire=0.5, water=0.5, lightning=0.5, ice=2, plant=2, void=2 },
  plant     = { fire=0.5, ice=0.5, poison=0.5, plant=0.5, metal=0.5, water=2    },
  arcane    = { void=0.5, infernal=0.5, celestial=0.5, arcane=0.5, ghost=2, lightning=2, poison=2 },
}
