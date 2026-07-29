# ASSETS_NEEDED — sprite replacement manifest

SingleMon ships with **zero media files**. Out of the box it renders every
creature and all UI as colored shapes. This document lists every asset the
engine will actually load if you provide it, the exact directory layout and
filename convention, and what is *not* loadable (so you don't waste time
authoring files nothing will read).

The short version: **the only loadable assets are 40 creature sprite-sheet
PNGs** covering all 94 species. Tiles, menus, battle backgrounds, fonts, and
audio are all code-drawn or nonexistent — there are no file hooks for them.

---

## Where to put the files

Sprite paths are baked into the species data (`data/species/*.lua`) as
VFS-root-relative paths like `riftborn/pocketmon/3evo/21.png`, and loaded
directly with `love.graphics.newImage(sp.sprite)` (see
`scenes/battle.lua`, `scenes/party.lua`, `scenes/select_starter.lua`).
LÖVE resolves those against the game's virtual filesystem root, which means
either of these locations works:

1. **Game directory (recommended):** create the folder tree next to
   `main.lua`:

   ```
   SingleMon/
   ├── main.lua
   └── riftborn/
       └── pocketmon/
           ├── 2evo/      01.png … 10.png   (10 sheets, 2 stages each)
           ├── 3evo/      01.png … 22.png   (22 sheets, 3 stages each)
           └── uniques/   01.png … 08.png   (8 sheets, 1 stage each)
   ```

2. **LÖVE save directory:** the same `riftborn/…` tree inside the save
   folder (identity `singlemon`, e.g.
   `%APPDATA%\LOVE\singlemon\` on Windows, `~/.local/share/love/singlemon/`
   on Linux). The save directory is searched before the source directory.

### About `config.lua → assetPath` and the boot warning

`main.lua` tries `love.filesystem.mount(cfg.assetPath, "assets")` and prints
`[WARN] Could not mount assets from: assets` when it fails. Two things to
know:

- **The warning is harmless.** Sprite loading does not depend on the mount.
- **The mount currently does nothing for sprites even when it succeeds**:
  it mounts under the `assets/` mount point, but every sprite path in the
  species data starts with `riftborn/`, not `assets/`, so nothing ever reads
  from the mount point. Additionally, LÖVE 11 cannot mount arbitrary
  absolute external paths. Ignore `assetPath` and use one of the two
  locations above.

---

## Asset manifest

| path/pattern | type | format | dimensions | used for | required/optional | fallback |
|---|---|---|---|---|---|---|
| `riftborn/pocketmon/2evo/NN.png` (NN = `01`–`10`) | creature sprite sheet | PNG, alpha transparency | 144×48 (3 frames of 48×48; see convention below) | 2-stage evolution chains — frame 0 = stage 1, frame 1 = stage 2, frame 2 unused (leave blank) | optional | sprite area left empty; UI panels/shapes still render |
| `riftborn/pocketmon/3evo/NN.png` (NN = `01`–`22`) | creature sprite sheet | PNG, alpha transparency | 144×48 (3 frames of 48×48) | 3-stage evolution chains — frame 0/1/2 = stage 1/2/3 | optional | same as above |
| `riftborn/pocketmon/uniques/NN.png` (NN = `01`–`08`) | creature sprite sheet | PNG, alpha transparency | 144×48 (3 frames of 48×48) | legendary/unique species — frame 0 only, frames 1–2 unused (leave blank) | optional | same as above |
| overworld tiles / player / NPCs | — | — | — | **not loadable** — the overworld (`scenes/overworld.lua`) is 100% procedural rectangles/circles; `tileSize`/`scale` in `config.lua` only size those shapes | n/a | always shapes |
| battle background / UI panels / HP bars / title | — | — | — | **not loadable** — all drawn in code (`scenes/battle.lua`, `scenes/title.lua`, etc.) | n/a | always shapes |
| fonts | — | — | — | **not loadable** — no `love.graphics.newFont` calls; LÖVE default font is used | n/a | default font |
| audio (music/SFX) | — | — | — | **no audio system exists** — zero `love.audio`/`newSource` calls anywhere in the codebase, so no audio file will ever be loaded regardless of where you put it | n/a | silence |

Counts: **40 PNG files total** (10 + 22 + 8 sheets) cover **94 species**
(20 in 2-stage chains + 66 in 3-stage chains + 8 uniques). Any subset works;
each sheet loads independently.

---

## Sheet convention (must-follow rules)

The draw code (`drawSprite` in the three scenes above) does this for every
sheet, regardless of folder:

```lua
local fw = math.floor(img:getWidth() / 3)   -- frame width = image width / 3
local fh = img:getHeight()                  -- frame height = full image height
-- quad at (fw * frame, 0, fw, fh), drawn centered on (x, y)
```

So:

- **Every sheet is a horizontal 3-frame strip**, even 2-stage and unique
  sheets. The width is always divided by 3. A unique drawn as a single
  square image will show only its left third.
- **Reference size is 144×48** (each frame 48×48). Any width divisible by 3
  works, but keep frames square-ish and consistent — battle draws at 4×
  scale (48 px → 192 px on screen), starter select at 3×, party detail at
  4×, party list at 1.2×, box grid at 1×.
- Frame index = evolution stage: `spriteFrame` 0/1/2 in the species data
  selects the stage within the shared sheet.
- **One view per species.** The same frame is used for the enemy (front,
  top-right) and your creature (back position, bottom-left) — there are no
  separate front/back sprites and no mirroring. Draw a 3/4 or side view
  that reads acceptably in both positions.
- Sprites are drawn centered on their anchor with white tint; use PNG
  transparency for the background.
- The engine does not set nearest-neighbor filtering, so pixel art will be
  smoothed when upscaled. Author at 48×48 and accept the softness, or
  author frames at a larger size (e.g. 192×192 per frame, 576×192 sheet) —
  the code scales by frame *factor*, not to a fixed pixel size, so larger
  frames render proportionally larger. 48×48 frames match the intended
  layout.
- A file that fails to load (missing/corrupt) is caught with `pcall`; the
  game continues and simply skips that creature's sprite.

---

## Worked example: the Emberfox line

The starter Emberfox and its evolutions share one sheet,
`riftborn/pocketmon/3evo/21.png`:

```
riftborn/pocketmon/3evo/21.png   — 144×48 PNG, transparent background
┌────────────┬────────────┬────────────┐
│  frame 0   │  frame 1   │  frame 2   │
│  48×48     │  48×48     │  48×48     │
│  Emberfox  │ Sinderflare│  Blazetail │
└────────────┴────────────┴────────────┘
```

Drop that single file at `SingleMon/riftborn/pocketmon/3evo/21.png`, launch
the game, and all three species render as sprites in the starter select,
battle, and party screens. No config change needed; no restart-between-scenes
needed (images are loaded on scene enter).

---

## Appendix: full sheet → species map

| sheet | frame 0 | frame 1 | frame 2 |
|---|---|---|---|
| `2evo/01.png` | Sandfur | Dustmane | — |
| `2evo/02.png` | Snowbun | Pearlhop | — |
| `2evo/03.png` | Woolpup | Rambear | — |
| `2evo/04.png` | Joltoad | Boltshell | — |
| `2evo/05.png` | Nightbat | Gloomwing | — |
| `2evo/06.png` | Dustpup | Stonefang | — |
| `2evo/07.png` | Voidgrub | Voidcoil | — |
| `2evo/08.png` | Voidpup | Riftknight | — |
| `2evo/09.png` | Dusksaur | Shadowrex | — |
| `2evo/10.png` | Gritrat | Graygnaw | — |
| `3evo/01.png` | Pinklet | Blushpaw | Blushroar |
| `3evo/02.png` | Spriglet | Thorngrub | Venomanta |
| `3evo/03.png` | Graycub ★ | Stonepelt | Boulderback |
| `3evo/04.png` | Tawnykit | Dustfang | Terraclaw |
| `3evo/05.png` | Shimmergrub | Prismcoon | Lumiwing |
| `3evo/06.png` | Cherublet | Seraphin | Angelcrest |
| `3evo/07.png` | Spiritfin | Phantomray | Abyssphant |
| `3evo/08.png` | Blushkit | Rosepaw | Florafox |
| `3evo/09.png` | Tidelet ★ | Coildepth | Seadrakon |
| `3evo/10.png` | Stormchick | Galebird | Thunderwyrm |
| `3evo/11.png` | Toxrat | Venomape | Blightlord |
| `3evo/12.png` | Glimwick | Arcanex | Riftmage |
| `3evo/13.png` | Mosscub | Ivypelt | Timberback |
| `3evo/14.png` | Shadowchick | Darkwing | Dusktalon |
| `3evo/15.png` | Ravenlet | Grimwing | Soulraven |
| `3evo/16.png` | Gloomfeather | Nightbird | Voidshriek |
| `3evo/17.png` | Specter | Phantomrat | Wraithclown |
| `3evo/18.png` | Mudbun | Dirtdog | Terramutt |
| `3evo/19.png` | Fernosaur | Bogosaur | Marshosaur |
| `3evo/20.png` | Frostkit | Chillfur | Glacicat |
| `3evo/21.png` | Emberfox ★ | Sinderflare | Blazetail |
| `3evo/22.png` | Swamplet | Bogscale | Tidemantle |
| `uniques/01.png` | Riftwarden | — | — |
| `uniques/02.png` | Verdantlord | — | — |
| `uniques/03.png` | Puremane | — | — |
| `uniques/04.png` | Stormsteed | — | — |
| `uniques/05.png` | Voidlord | — | — |
| `uniques/06.png` | Terramare | — | — |
| `uniques/07.png` | Duskrogue | — | — |
| `uniques/08.png` | Vinesprite | — | — |

★ = starter (drawn on the starter-select screen at boot — good sheets to
author first).
