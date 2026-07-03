# SingleMon — Gap Analysis vs. Creature-Collector Genre Staples

_Date: 2026-07-02. Basis: full engine read, 1099-assertion headless suite
(green), boot-verified under Love2D/LuaJIT after repairs. Every "missing" claim
keyword-verified. Role note: SingleMon is the clean Gen 1-style REFERENCE
engine; MONCLONE (F:\LOVE-MONCLONE) is the expanded fork (IVs, held-item
cards, abilities). Gaps below are chosen to keep the reference valuable —
not to re-grow MONCLONE here._

## State after 2026-07-02 debug pass

The engine **did not boot at all** before today: a bad JSON escape crashed
require at startup, the scene router used `goto` (reserved in LuaJIT/5.2+),
and the PRNG's signed-bit bug skewed every probability roll. All fixed;
94 species / moves / type chart now fully covered by `tests/run_tests.lua`
(runs headless: `lua tests/run_tests.lua`).

## What SingleMon already has (do not rebuild)

Exact Gen 1 damage formula with stat stages, STAB, dual-type effectiveness,
custom 13-type chart, burn/poison/paralyze/blind status with correct Gen 1
interactions (burn atk-halving, 1/16 ticks, speed-tie coin flip), priority
moves, deterministic seeded battles, 94 species across evolution chains,
bond-based evolution (novel — not level-based), catching with tiers, trainer
battles, wild encounters, shop, storage box, party management, JSON saves,
scene router, MONCLONE asset mounting.

---

## A. Engine gaps (worth adding to the reference)

### A1. Sound — zero audio code — LOW effort, big feel
Not a single audio call in the codebase (0 hits). Even 8-bit bleeps (hit,
faint, catch shake, level-up jingle) transform battle feel. Love2D audio is
~20 lines of manager; SFX can be generated (bfxr/sfxr-style) at zero cost.

### A2. Battle depth: the missing Gen 1 quartet — MEDIUM
The formula is faithful but four core mechanics are absent:
- **Critical hits** (Gen 1: speed-based crit rate, ignores stat stages)
- **Sleep/freeze** statuses (only burn/poison/paralyze/blind exist)
- **Multi-hit and two-turn moves** (effects system already supports move
  effect entries — these are new effect types, not new architecture)
- **Switching as a turn action** (party exists; simulateTurn only knows
  move/run — a `switch` action is the biggest strategic hole)

### A3. Experience flow: XP share semantics + evolution moments — LOW
grantXp/evolution exist; verify battle rewards route through participation.
A dedicated evolution scene (cancelable, "what? X is evolving!") is pure
scene work on the existing router.

### A4. Trading / breeding — NOT recommended here
Both absent (0 hits) — but they belong in MONCLONE (which already has
fusion/breeding concepts), not the reference engine. Keep SingleMon lean.

### A5. Encounter tuning: repel/lure + per-area rates — LOW
No encounter-rate modifiers (0 hits). Items exist (shop sells potions);
a repel item + area encounter tables rounds out the overworld loop.

### A6. Nicknames — trivial, high charm
displayName() already centralizes naming; a nickname prompt on catch is
an afternoon.

## B. Content gaps

- **Badges/gyms or any goal structure:** nothing gates progression or ends
  the game (badge hits are UI color chips). Even 3 themed trainer "dens"
  with a champion gives the loop a spine.
- **Art dependency:** all sprites mount from F:\LOVE-MONCLONE — and Love 11
  cannot mount absolute external paths, so the mount **always fails** and the
  game runs on colored shapes. Either vendor a small sprite subset into
  assets/ locally (94 species sprite sheet is one file family) or accept
  shapes for a reference engine. The current config silently half-works.

## C. Engineering

- **Tests now exist** (1099 assertions) — keep them green; they run in <1s
  and cover data integrity for every species/move, so content additions
  self-check. Add new mechanics (A2) test-first; the deterministic PRNG
  makes exact-value tests possible.
- **PRNG note:** the signed-bit fix changed RNG streams vs. old builds
  (they were biased — chance() fired ~always on half of all states). Any
  tuning done against the old RNG (catch rates, status proc rates) should
  be re-felt in play.
- **MONCLONE upstreaming:** the three boot-breaking bugs fixed here
  (json escape, goto keyword, PRNG sign) very likely exist in MONCLONE's
  copies of the same files — check F:\LOVE-MONCLONE before its next run.

## Suggested sequencing

1. **A2 switching + crits** (the strategic core) — test-first
2. **A1 audio bleeps** + **A6 nicknames** — feel pass
3. **B goal structure** (3 dens + champion)
4. **A5 encounter tuning**, **A3 evolution scene**
5. Vendor minimal local sprites (B) if the shapes bother you
