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
python3 -m pytest -q -p no:cacheprovider tests/   # acceptance suite: 136 tests, all green from the repo root
bash scripts/smoke.sh    # live API smoke (20 cases; starts/kills its own server on :8912 with a /tmp DB)
```
The black-box pytest suite ships in `tests/` (7 files: server API + validation, game numbers,
static contract, assets manifest, tree hygiene) — run it from the repo root; pytest is the only
test dep. `tests/conftest.py` starts and stops the real server itself on :8931/:8932 with throwaway
/tmp DBs (never :8123, never `data/`). `scripts/smoke.sh` is the live-HTTP gate: green means it
prints `RESULT: PASS=20 FAIL=0` and exits 0 (last line `VERIFY_EXIT=0`).
Browser-automation contract: `window.VS_STATE()` returns the 12-field live snapshot; synthetic
KeyboardEvents drive the game (see `docs/ARCHITECTURE.md`).

## Layout
- `godot/` — the game project (GDScript + scenes + export presets + JS bridge shim `web_head.js`)
- `static/` — the Godot Web export (what the server serves) + `assets/` source sprites
- `server/` — stdlib HTTP: static files + `/api/health` + `/api/highscores` (sqlite in `data/`)
- `docs/ARCHITECTURE.md` — modules, entrypoints, ports, data stores (kept true)

Limitations: no audio (Web build); leaderboard has no auth (local PoC by design).

## Related

- **Hollow Dawn 3D** — the 3D remake (animated 3D characters, same top-down loop) lives in its own repo with its own releases: https://github.com/bryn1/hollow-dawn-3d (owner ruling 2026-10-21: "Go, make this its own github repo with its own releases"). This repo remains the shipped 2D original.
