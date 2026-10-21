# ARCHITECTURE — Hollow Dawn

Re-derived from the actual tree 2026-10-21 by the ARCHITECT closing (MC 11027) — every claim below
carries a `file:line` into this checkout (master, final release-candidate content at `aae77d6`).
Owner ruling 2026-10-20: "I want the game built on godot engine" — the client is a Godot 4.7.2
project (`godot/project.godot:2,10`); the earlier vanilla-JS client was REPLACED (history on branch
`feat/client`, not on master). Owner amendments 2026-10-21: biome terrain bands + per-band enemies
(`goal.md` amendments; rendered by `render.gd`/`world.gd` below).

## 1. What it is
A survivors-style game (browser WASM + Windows build): the player moves (WASD/arrows,
`godot/scripts/bridge.gd:8-9,60-73`), six weapons auto-fire (`godot/scripts/weapons.gd:6`), enemies
swarm in on a ring outside the viewport at a rate that scales with the run clock
(`godot/scripts/world.gd:59-60,83-92`), kills drop XP gems (`godot/scripts/world.gd:133`), leveling
pauses the game to pick 1 of 3 cards (`godot/scripts/main.gd:137-138,154-171`), and the ground
terrain swaps biome bands as the clock crosses 0/150/300/450 s (§6). Die or survive 10:00
(`godot/scripts/game_state.gd:7`), then submit a score to a local leaderboard
(`godot/scripts/main.gd:174-190`). Clean-room: original names/art/code (`README.md:3-5`,
`docs/COMPARISON.md` §(d)).

## 2. Entry points
- Run: `python3 server/server.py` → http://127.0.0.1:8123/ (`server/server.py:20-21,49-53`);
  env `VS_PORT`, `VS_DB` (`server/server.py:50-51`).
- Rebuild the Web client (Godot 4.7.2 + web templates):
  `godot --headless --path godot --import && godot --headless --path godot --export-release "Web" ../static/index.html`
  — the committed rule is to run the export **twice** and commit the regenerated `static/index.*`
  (`README.md:17-22`; every build row in `LEDGER.md` records "web export x2").
- Rebuild the Windows build: preset "Windows Desktop" → `../.tmp/win/HollowDawn.exe`, embed_pck
  (`godot/export_presets.cfg:40-51,62`); `.tmp/` is gitignored (`.gitignore:2`). Shipped GitHub
  releases: v1.0.0 `HollowDawn.exe`, v1.1.0 `HollowDawn-final.exe`, digests byte-verified against
  GitHub's own records in `out/DA-verdict-c3.md` §G1 (run dir).

## 3. Modules — server (Python 3.10+ stdlib only)
- `server/server.py` — `ThreadingHTTPServer` on 127.0.0.1 (`:10,20,53`); per request `api.handle`
  first, then `static_app.serve` (`:28-31`); GET/POST/PUT/DELETE/PATCH only, so HEAD answers 501
  (documented + pinned by `tests/test_static_contract.py:105-109`).
- `server/api.py` — `/api/health` GET `{"status":"ok"}` (`:14,108-113`); `/api/highscores` GET
  top-10 / POST validated insert→rank 201 (`:15,114-121,128-147`); JSON errors 400 BAD_JSON
  (malformed body / Content-Length absent, negative or > 65536 B, `:11,84-103`), 422 VALIDATION
  with a `{field: reason}` map (`:42-81,132-139`; bounds: name 1-16 printable, score int
  0-999999999, time_survived number 0-3600, kills int 0-999999, level int 1-999), 404 NOT_FOUND
  under `/api/` (`:122-124`), 405 METHOD_NOT_ALLOWED (`:112,120`).
- `server/db.py` — `highscores` table (`:19-29`); one shared sqlite connection behind one lock
  (single-writer discipline, `:49-57`); rank = 1 + strictly-higher-score count so ties share a
  rank, board ordered score DESC with earlier `created_at` breaking ties, `LIMIT 10` (`:17,31-41,59-94`).
- `server/static_app.py` — docroot `static/` (`server/server.py:18`); every path realpath'd and
  required inside the docroot via commonpath, NUL bytes rejected, escapes and unknown extensions
  answer 404 (never 403/500) (`:23-40,46-53`); content-type allowlist incl. `.wasm`
  (application/wasm) and `.pck` (application/octet-stream) (`:13-20`).

## 4. Modules — client (Godot 4.7.2, GDScript, `godot/scripts/`)
- `game_state.gd` — phases `menu|playing|levelup|gameover|win` + pause/mute flags + clock
  (`:10-13`), xp curve `5 + 4·L + L²` (`:28-30`), passive math (`:32-42`), run reset (`:44-59`,
  starting weapon "talon" `:56`), and the Contract B snapshot: exact 12 fields {phase,hp,maxHp,
  level,xp,xpNext,gold,kills,time,enemies,weapons,runId} serialized per tick (`:87-104`).
- `main.gd` — boots + wires all nodes (`:20-48`); simulation runs on the fixed physics tick and
  only while `phase=="playing"` and not paused (`:80-84`); the 12-field snapshot is pushed to
  `window.__vsSnapshot` every tick (`:84`); key routing incl. Escape-pause, Digit1/2/3 card picks,
  and Enter-on-gameover deliberately NOT restarting (`:87-105`); contact damage with `iframes`
  (`:121-128`); death/win end conditions (`:130-136`); `_score = time*10 + kills*5 + level*25 + gold`
  (`:193-194`); `_js_eval` is the ONLY JavaScriptBridge choke point and no-ops off-web (`:65-71`).
- `world.gd` — `ENEMY_TYPES` stats+sprite per id (`:13-25`, §7), `GATES` minute rotation
  (`:28`), `_types_open(t)` merging the band roster + gates (§7), spawn ring + rate + HP creep
  (`:59-92`), death drops (`:126-138`), pickup collect + Grip-scaled magnet (`:95-121,141-159`).
- `weapons.gd` — the six auto-fire weapons talon/ember/cleaver/halo/ward/spike (`:6-16`), level
  cap 8 (`:7`), rate `base·0.96^(level-1)` (`:47-48`), one damage entry `_hit` with per-source
  tick cooldowns (`:78-100`), continuous orbiting halo (`:171-188`), per-weapon fire behaviour
  (`:103-168`).
- `levelup.gd` — pool of new-weapon / weapon-upgrade / passive cards (`:17-36`), passives cap 5
  (`:6`), 3-card offer with a gold+hp consolation when the pool is empty (`:40-50`), apply (`:53-65`).
- `screens.gd` — menu / level-up / end overlays on a `layer = 10` CanvasLayer (`:22`), signals
  `start_pressed`/`card_picked` (`:6-7`), end titles "You survived until dawn" / "The night took
  you" (`:58`), the web-only "sign the ledger" hint (`:112-115`), Play-again button (`:115`).
- `hud.gd` — pure-display CanvasLayer (`layer = 5`, `:32`): timer, HP bar + text, XP bar, level,
  gold, kills, weapon-icon row, PAUSED (`:39-78`) and the biome-name banner (§6).
- `bridge.gd` — the ONLY gameplay-input path: web fills its queues from the DOM relay, desktop
  builds feed the SAME queues from native `_input` (`:1-5,28-43`); move + discrete key sets
  (`:8-11`), normalised 8-dir vector (`:60-73`), press drain (`:76-79`).
- `render.gd` — the world renderer, §6.

## 5. Web↔JS bridge + submit-panel lifecycle
- `godot/web_head.js` is injected into the Web export as `html/head_include`
  (`godot/export_presets.cfg:28`); the cfg string mirrors `godot/web_head.js` (escape-aware
  compare: identical modulo the file's trailing newline — verified this rewrite).
- `window.VS_STATE()` returns the last pushed snapshot (`web_head.js:2-3`); `time` advances only
  while `phase=="playing"` and not paused (`main.gd:82,109`).
- Input: window keydown/keyup relay → `window.vsHost.on_key(code, down)`, ignoring repeats and
  DOM form fields (`web_head.js:5-13`); on the GDScript side the callback is
  `JavaScriptBridge.create_callback` hung on `window.vsHost.on_key` — Godot 4.7 removed
  `register()` (`main.gd:51-62`).
- Submit panel (`web_head.js:14-75`), `#vs-submit/#vs-name/#vs-send/#vs-result` (`:23-40`):
  `vsShowSubmit()` REBUILDS the panel on every terminal show (marker `vs-fix-11075`, `:14-21`) and
  the Submit click refuses to POST once a newer `runId` owns the live snapshot (stale-POST guard,
  `:51-58`); it POSTs `/api/highscores` and renders rank + top-10, "offline" on fetch failure
  (`:62-73`). Symmetrically, `main.gd::_start_game` — the single run-start funnel (menu Enter
  `main.gd:93-94` + Start/Play-again via `start_pressed` `main.gd:39`, `screens.gd:153-154`) —
  deletes a leftover `#vs-submit` through `_js_eval` so a dead panel never sits over live play
  (marker `vs-fix-11083`, `main.gd:141-151`, live proof in `out/DA-verdict-c3.md` §G5). The
  shipped `static/index.html` carries `vs-fix-11075` ×2 + `vs-fix-11083` ×1 (grep-verified this
  rewrite; TEST-c4 §4).

## 6. Biome bands + rendering (`godot/scripts/render.gd`, `hud.gd`)
- `const BIOMES` is the ONE band table, 4 rows, each with its per-band enemy roster:
  MOORLAND (`assets/biomes/grass.png`, `t_start 0.0`, enemies wraith+moor-brute) / BURNING DUNES
  (`desert.png`, 150.0, wraith+dune-scarab) / THE FROZEN WASTE (`snow.png`, 300.0,
  wraith+rime-ghoul) / DEAD TUNDRA (`tundra.png`, 450.0, wraith+pale-wight) — `render.gd:68-77`;
  tundra carries the boss at 9:00 and the win at 10:00 (`render.gd:60-61`, `world.gd:5`,
  `game_state.gd:7`).
- `biome_at(t)` (`render.gd:80-85`) is the single band lookup, used by the terrain draw
  (`render.gd:116`) and by the HUD banner (`hud.gd:88`) — one source, no second table.
- Terrain: the band's 1024 px tile drawn `tiled=true` across the visible world rect with the rect
  origin snapped to the tile grid, so the ground is WORLD-locked and pans with the camera, drawn
  first so gameplay always stays on top (`render.gd:210-222`, called at `:116`).
- Seamlessness: the tiles are seamless by an FFT wrap-safe low-frequency FLATTEN + offset-blend
  re-master (card 11084), NOT by generation — the original 11078 tiles were style-level seamless
  only and were replaced (`static/assets/MANIFEST.md:52-56,65-81`); measured wrap-vs-interior
  diff ratios all ≤ 1.12 (`MANIFEST.md:76-77`, independently re-measured ≤ 1.25 gate in
  `out/DA-verdict-c3.md` §G2).
- Band-name banner: on each band change the band name flashes full alpha and fades over
  `BIOME_FLASH := 3.0` s (fade = last 1 s) — `hud.gd:12,84-96`; re-armed out of "playing"
  (`hud.gd:85-86`).
- Sprites draw at pinned sizes {player 40, enemy 34, boss 128, coin 14, gem 14}
  (`render.gd:10,126`); per-type tints `ENEMY_TINTS` (classic five, acceptance-pinned by
  `tests/test_game_numbers.py:110-116`) + `BIOME_TINTS` (four signatures) behind one `tint_of()`
  lookup (`render.gd:22-42`); the level-5 player sprite swap + iframes flash (`render.gd:134-138`).
- Glow halos (MC 11048): modulate is multiplicative, so enemies + Dawnlight also get ADDITIVE
  auras from a child `HaloPass` node with a `BLEND_MODE_ADD` CanvasItemMaterial — radii/alphas at
  `render.gd:49-53`, the pass at `render.gd:237-264`. Dawnlight pickups are drawn programmatically
  as a bright cross, no PNG (`render.gd:18,174-182`). Boss HP bar "THE HOLLOW WARDEN"
  (`render.gd:194-207`).

## 7. Enemy roster (`godot/scripts/world.gd`)
- `ENEMY_TYPES` — stats + sprite per id (`:13-25`): wraith 8/55/2/xp1 (`:14`), hound 6/95/3/1
  (`:15`), crawler 30/35/5/3 (`:16`), cultist 18/60/6/4 (`:17`), moor-brute 26/32/4/xp2 slow+tanky
  (`:20`), dune-scarab 5/105/2/xp1 fast swarmer (`:21`), rime-ghoul 18/60/5/xp3 (`:22`),
  pale-wight 45/52/9/xp4 hardest (`:23`), boss warden 3000/45/12 (`:24`).
- Which ids spawn when: `_types_open(t)` = the band roster (`BIOMES.enemies` through the one
  `biome_at()`, duplicate-guarded) MERGED with the classic `GATES` rotation (wraith at 0, hound
  2 m, crawler 4 m, cultist 6 m) — `:51-56,28`; signature creatures spawn only in their own band
  (no other reader of `BIOMES.enemies`). One merged set feeds the single spawn loop (`:83-92`).
- Difficulty: spawned HP scales `1 + 0.22·(t/60)` per minute (`:67`); spawn rate
  `min(12, 1 + 1.3·minute)/s` (`:88`); swarmers home in (`:96-105`).

## 8. Game constants (plan §5 set, pinned by `tests/test_game_numbers.py`)
WIN_TIME 600.0 (`game_state.gd:7`, gated `main.gd:134`) · BOSS_AT 540.0 (`world.gd:5`) ·
MAX_HP 100 (`game_state.gd:8`) · BASE_SPEED 140 (`game_state.gd:5`) · IFRAMES 0.5
(`game_state.gd:6`, applied `main.gd:127`) · xp_need `5+4L+L²` (`game_state.gd:29`) ·
Dawnlight heal: drop chance 0.015 per kill, guaranteed once from the boss, +8 HP clamped to
max_hp (`world.gd:6-7,137-138,158`) · glow halos §6 · weapon level cap 8 (`weapons.gd:7`) ·
passive cap 5 stacks (`levelup.gd:6`) · Ward −1 dmg/stack (`game_state.gd:36-38`), Ferocity
+10 % dmg (`:40-42`), Haste +8 % speed (`:32-34`), Grip +25 % pickup magnet (`world.gd:106`),
Insight +15 % xp (`game_state.gd:77-84`) · drops 70 % gem / 6 % coin 1-3 g / boss +50 g
(`world.gd:131-136`) · pickups collected within 16 px (`world.gd:146,151,156`); enemy touch radius
17 px (boss 55) + player 16, `iframes`-gated (`main.gd:121-128`) · score formula §4 ·
BIOME_FLASH 3.0 §6.

## 9. Scene structure
`godot/Main.tscn` is one Node2D carrying `scripts/main.gd` (`godot/Main.tscn:3-6`); every other
node is built in code at boot (`main.gd:20-48`): renderer Node2D (`:27-31`), HUD CanvasLayer
layer 5 (`:33-35`; `hud.gd:32`), screens CanvasLayer layer 10 (`:37-41`; `screens.gd:22`), bridge
Node named "VSHost" (`:42-44`). Viewport 1280×720, `gl_compatibility` renderer, threads OFF
(`godot/project.godot:14-15,19-20`; `export_presets.cfg:23`).

## 10. Ports / deps / data
- Port 8123 default, bound 127.0.0.1 (`server/server.py:20,53`), env `VS_PORT`; test ports are
  separate and owned by tooling: pytest `:8931/:8932` (`tests/conftest.py:22-25`), smoke `:8912`
  (`scripts/smoke.sh:7`).
- Server deps: Python 3.10+ stdlib ONLY, no pip (`README.md:10`; imports in `server/*.py`). Client
  runtime: browser WASM (gl_compatibility) or the Windows build; no frameworks, no CDN, no build
  step beyond the Godot export.
- Data store: sqlite at `<repo>/data/highscores.db` (env `VS_DB`; `data/` gitignored
  `.gitignore:1`; parent dir auto-created `server/db.py:51-52`).

## 11. Assets
`static/assets/` — 24 original PNGs, all generated on the fleet vm100 RTX 3090 (Qwen-Image), with
prompts + byte sizes pinned in `static/assets/MANIFEST.md`: the 16 contract-C sprites/icons
(`MANIFEST.md:19-38`, filename set pinned by `tests/test_assets_manifest.py:17-22`), the 4 biome
ground tiles (`MANIFEST.md:41-63`, re-master record `:65-81`), and the 4 biome-enemy signatures
(`MANIFEST.md:83-102`). Every file is mirrored under `godot/assets/` (byte-identical copies —
re-verified by `out/DA-verdict-c3.md` §G2) and shipped inside the exported `.pck`; the final
committed `static/index.pck` is sha256 `7858f80b009fa4c9da09d02aac35c8fce8f5c2be54261bbde86c0494815acfcb`
and the live :8123 server serves those same bytes (TEST-c4 §4+§7, re-verified this rewrite).

## 12. Test / verification surface
- The acceptance suite SHIPS in the repo at `tests/` — 7 files, 136 tests, green from the repo
  root with `python3 -m pytest -q -p no:cacheprovider tests/` (`README.md:25-33`; fresh-clone run
  in TEST-c4 §1). It was vendored from the run dir at `774114a` — the older "suite lives in
  .audits/out" wording was superseded (`LEDGER.md:9`).
- Source-truth pins: boss/win thresholds, heal drop/amount/clamp, GATES minutes, spawn-rate cap,
  five ENEMY_TYPES base stats, xp curve, ENEMY_TINTS exactly five
  (`tests/test_game_numbers.py:35-116`). Black-box API + validation: `tests/test_contract_a_api.py`,
  `tests/test_contract_a_validation.py`; static contract incl. the documented HEAD 501 and the
  NUL-path 404: `tests/test_static_contract.py`; asset integrity: `tests/test_assets_manifest.py`;
  hygiene gates (300-line source caps, zero marker words, .gitignore coverage, trackedness
  meta-guards that honestly SKIP — not silently pass — in a .git-less sealed export):
  `tests/test_tree_hygiene.py:19-108` (sealed behaviour TEST-c4 §2).
- Coverage debt, honestly stated (TEST-c4 finding 1, P3): the biome/band surface (BIOME_FLASH,
  band rosters, the four signature-enemy stats) is NOT pinned by the suite — planting a wrong
  banner constant stays green; recommended fix is a biome-numbers file mirroring
  `test_game_numbers.py`. `scripts/smoke.sh` case 19 guards "no leak", not "server alive" (P4,
  TEST-c4 findings 2-3).
- Runtime proof lives in the run dir `/home/claudecode/Games/.audits/202610201514-81bb9a6c/`
  (run dir lives at the Games workspace root by the ARCHITECT-OPEN deviation note,
  `placement-plan.md` §0): scripted browser playthroughs, live screenshots, TEST c1-c4 +
  DA c1-c3 verdicts, DONE/CYCLES.
- Contract B input surface for drivers: synthetic KeyboardEvents on window with `e.code` values
  KeyW/A/S/D, Arrow*, Escape, Digit1/2/3, Enter (`bridge.gd:8-11`; relay `web_head.js:5-13`);
  in-canvas mouse clicks also work on cards/buttons (`screens.gd:145-149`).

## 13. Known limitations (stated, not hidden)
- No audio in the shipped build; `M` toggles an internal no-op flag (`game_state.gd:12`,
  `main.gd:89-90`, `screens.gd:93`).
- Victory (survive 600 s) is a client-side screen; the leaderboard server does not gate on it.
- Single-server, single-file sqlite; throwaway/local PoC scope — no auth, no rate limit by
  design; HEAD answers 501 (§3).
- Boss HP shares the per-minute creep (`world.gd:67` applies to every spawn, boss included);
  harmless because the win is survive-600, not boss-kill (`DA-verdict-c3` §new-surface note).
