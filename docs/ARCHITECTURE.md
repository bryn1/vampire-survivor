# ARCHITECTURE — Hollow Dawn

Re-derived from the actual tree on 2026-10-20 (integrator); the ARCHITECT closing keeps this true.
Owner ruling 2026-10-20: "I want the game built on godot engine" — the client is a Godot project;
the earlier vanilla-JS client was REPLACED (kept as history on branch `feat/client`, not on master).

## What it is
A survivors-style browser game: the player moves (WASD/arrows), weapons auto-fire, enemies swarm
from the viewport edges at rates scaling with the run clock, kills drop XP gems; leveling pauses
the game to pick 1 of 3 upgrades; die or survive 10:00 to submit a score to a local leaderboard.
Clean-room: original names/art/code; no Vampire Survivors assets, names, or code.

## Entry points
- Run the game: `python3 server/server.py` → http://127.0.0.1:8123/ (env `VS_PORT`, `VS_DB`).
- Rebuild the client: Godot 4.7.2 editor on `godot/` (main scene `godot/Main.tscn`), export
  preset "Web" (threads OFF, `gl_compatibility` renderer, 1280x720) to `static/index.html`:
  `godot --headless --path godot --import && godot --headless --path godot --export-release "Web" ../static/index.html`
  (run twice; commit the regenerated `static/index.*`).

## Modules
- `server/server.py` — ThreadingHTTPServer entry; env wiring; dispatch to api/static handlers.
- `server/api.py` — `/api/health`, `/api/highscores` (GET top-10, POST validated insert→rank);
  JSON errors 400 BAD_JSON / 422 VALIDATION{fields} / 404 NOT_FOUND / 405 METHOD_NOT_ALLOWED.
- `server/db.py` — sqlite init + queries (`highscores` table, per-request discipline).
- `server/static_app.py` — docroot `static/`, traversal-safe resolution (realpath+commonpath→404),
  content-type allowlist incl. `.wasm` (application/wasm) and `.pck` (application/octet-stream).
- `godot/scripts/*.gd` — client: `game_state.gd` (phases/timer/VS_STATE snapshot fields),
  `main.gd` (loop+wiring), `world.gd` (spawns/gates per spec), `weapons.gd` (6 auto-fire weapons),
  `levelup.gd` (xp curve + 3 cards), `hud.gd`, `render.gd` (sprite draw sizes, procedural bg),
  `screens.gd` (menu/gameover/win), `bridge.gd` (JS bridge).
- `godot/web_head.js` — shim injected into the Web export via `godot/export_presets.cfg`
  head_include: defines `window.VS_STATE()` (12-field snapshot pushed by GDScript each physics
  tick), relays `keydown/keyup` → `vsHost.on_key` (`JavaScriptBridge.create_callback` — Godot 4.7
  removed `register()`), and `vsShowSubmit()` DOM overlay (#vs-submit/#vs-name/#vs-send/#vs-result)
  that POSTs `/api/highscores` and renders rank + top-10 ("offline" on fetch failure).
- `static/assets/` — 16 original PNG sprites (generated on the fleet RTX 3090, Qwen-Image;
  prompts in `static/assets/MANIFEST.md`); imported into `godot/assets/` and shipped in the .pck.

## Ports / deps / data
- Port: 8123 default (127.0.0.1), env `VS_PORT`.
- Python 3.10 stdlib ONLY (no pip). Client runtime: browser WASM (WebGL-compatible renderer); no
  frameworks, no CDN, no build step beyond the Godot export.
- Data store: sqlite at `data/highscores.db` (env `VS_DB`; `data/` gitignored; auto-created).

## Test/verification surface
- Browser automation contract: `window.VS_STATE()` exact 12 fields {phase,hp,maxHp,level,xp,
  xpNext,gold,kills,time,enemies,weapons,runId}; `time` advances only while `phase=="playing"`;
  input via synthetic KeyboardEvents on window (`e.code`: KeyW/A/S/D, Arrow*, Escape, Digit1/2/3,
  Enter). Level-up picks = Digit keys (in-canvas cards); score submit = DOM overlay above.
- Score formula (client-side): `time*10 + kills*5 + level*25 + gold`.
- The independent pytest suite + evidence live in the run dir `.audits/202610201514-81bb9a6c/out/`
  (server API black-box); the game itself is verified by scripted browser playthroughs.

## Known limitations (stated, not hidden)
- No audio in the Web build (M is an internal no-op flag).
- Victory (survive 600 s) is a client-side screen; the leaderboard server does not gate on it.
- Single-server, single-file sqlite; throwaway/local PoC scope (no auth, no rate limit by design).
