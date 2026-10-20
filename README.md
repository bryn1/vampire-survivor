# Hollow Dawn

A **survivors-style** browser game (Vampire-Survivors *mechanics*, clean-room: original name,
art and code — no Vampire Survivors assets/names/code). Built on **Godot 4.7.2** (GDScript,
Web/WASM export) with a **Python stdlib** leaderboard server and **100% original art** generated
on an RTX 3090 (Qwen-Image diffusion; prompts in `static/assets/MANIFEST.md`).

## Play
```bash
python3 server/server.py        # Python 3.10+, stdlib only, no pip
# open http://127.0.0.1:8123/
```
WASD / arrows move · weapons auto-fire · grab XP gems · pick upgrades on level-up (keys 1/2/3) ·
Esc pause · survive 10:00 or die trying, then submit your run to the local leaderboard.

## Rebuild the client (Godot)
```bash
godot --headless --path godot --import
godot --headless --path godot --export-release "Web" ../static/index.html   # run twice
```
Requires Godot 4.7.2 + web export templates (threads OFF preset is committed).
Commit the regenerated `static/index.*` artifacts.

## Test
```bash
bash .tmp/smoke-server-11024.sh    # live API smoke (20 cases, self-starts/kills server)
python3 -m pytest <run-dir>/out -q # independent black-box suite (server API), if the run dir exists
```
Browser-automation contract: `window.VS_STATE()` returns the 12-field live snapshot; synthetic
KeyboardEvents drive the game (see `docs/ARCHITECTURE.md`).

## Layout
- `godot/` — the game project (GDScript + scenes + export presets + JS bridge shim `web_head.js`)
- `static/` — the Godot Web export (what the server serves) + `assets/` source sprites
- `server/` — stdlib HTTP: static files + `/api/health` + `/api/highscores` (sqlite in `data/`)
- `docs/ARCHITECTURE.md` — modules, entrypoints, ports, data stores (kept true)

Limitations: no audio (Web build); leaderboard has no auth (local PoC by design).
