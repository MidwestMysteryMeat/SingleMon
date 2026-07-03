# SingleMon

**A clean, Gen 1-accurate creature-battle engine in Love2D — 94 species, the exact classic damage formula, deterministic seeded battles, and a headless test suite.**

## What it does

SingleMon is a reference implementation of a monster-collector battle system. It faithfully reproduces the Generation 1 damage formula (stat stages, STAB, dual-type effectiveness over a custom 13-type chart) with burn/poison/paralyze/blind status handled by the correct classic rules (burn halving physical attack, 1/16 end-of-turn ticks, speed-tie coin flips), priority moves, and fully deterministic seeded RNG so battles are reproducible. Content: 94 species across evolution chains, with a novel **bond-based evolution** system (creatures evolve by relationship level, not raw XP level), trainer and wild battles, catching, a shop, a storage box, party management, and JSON saves. The battle/creature engine is pure Lua (no LÖVE dependency), which is what makes it testable and reusable.

## Status

**Fixed, tested, and boots — was previously unbootable.** As of 2026-07-02 the engine runs and a 1099-assertion headless test suite passes (data integrity for every species/move/type, plus battle mechanics). Three bugs that prevented it from launching at all were fixed: an invalid JSON escape, a scene router named `goto` (a reserved keyword under LÖVE's LuaJIT), and a signed-bit PRNG bug that biased every probability roll. Rough edges: sprites mount from an external MONCLONE asset path that **doesn't resolve under LÖVE 11** (the game runs on colored shapes), and there's no goal structure (gyms/champion) yet.

## How to run

Requires [LÖVE 11.4](https://love2d.org/).

```
love .                        # play (renders shapes unless you set config.lua assetPath)
lua tests/run_tests.lua       # 1099-assertion headless suite, ~1s, no LÖVE needed
```

Sprites are optional: `config.lua` points `assetPath` at a MONCLONE asset folder; if it's missing (the default), the game logs a warning and renders colored shapes.

## Screenshots

_TODO — add a battle-screen capture._

## Known issues / roadmap

See [`docs/GAP_ANALYSIS.md`](docs/GAP_ANALYSIS.md). This is meant to stay a lean *reference* engine (the expanded fork with IVs/cards/abilities is a separate project). Priority: party switching as a battle action + critical hits → sleep/freeze + multi-hit moves → audio bleeps + nicknames → a goal structure (trainer dens + champion). Note: the PRNG fix changed RNG streams, so anything tuned by feel (catch/proc rates) should be re-playtested.

## AI development note

Built and repaired primarily through AI-assisted "vibe coding" with **Anthropic Claude** (Claude Code); **OpenAI Codex** reviews output per the shared workflow. Human direction owned the design and the Gen 1 accuracy goal; the AI implemented the engine and authored the test suite. The 2026-07-02 rescue pass (three boot-blocking fixes + the 1099-assertion suite) was done with Claude. There is no LLM or AI in the game itself — it's a deterministic rules engine.

## License

MIT — see [LICENSE](LICENSE). Sprite assets are not bundled (they load from an external MONCLONE path); the shipped code is original.
