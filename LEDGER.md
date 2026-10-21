LEDGER — vampire_survivor "Hollow Dawn" (MC 11021, run .audits/202610201514-81bb9a6c)
goal: fully playable survivors-style game, own 3090 art, public bryn1 repo. acceptance: goal.md.
STATUS: SHIPPED 2026-10-21 (public bryn1/vampire-survivor; release v1.0.0 with HollowDawn.exe asset uploaded; TEST c2 PASS + DA FIX cycle in run .audits/202610201514-81bb9a6c)
- T1 architect-open: DONE (placement-plan.md; DA declined anti-ceremony, post-build DA covers it)
- T2/T3/T4 js-client/server/art: DELIVERED (server live-VERIFIED, art VERIFIED, js client superseded)
- OWNER AMENDMENT: Godot engine -> T8 godot client DELIVERED live-verified-in-browser by child (VS_STATE, pause, spawns, submit)
- T9 server wasm/pck content-types: DELIVERED, merged (076170e)
- master @ c4f7f58 (Windows .exe preset merged); server :8123 running (data/highscores.db)
- TEST cycle: verdict c2 PASS (136 black-box tests; suite in run out/, not shipped)
- DA cycle: verdict FIX (F1 win-screen never rendered; F2 second-death submit panel; F3 README Test line unrunnable; F6 this LEDGER stale)
- MC 11075 fix: web_head.js rebuilds submit panel per terminal show + stale-run guard (F2); scripts/smoke.sh vendored + README Test fixed (F3); LEDGER de-staled (F6); web export re-run x2
- MC 11077 biome-int (owner terrain/biome amendment): BIOMES band-table (MOORLAND/BURNING DUNES/THE FROZEN WASTE/DEAD TUNDRA @ 0/150/300/450s, tundra carries boss+win) replaces the procedural gradient+grid background with world-locked tiled 1024px biome tiles (draw_texture_rect tiled, rect snapped to the 1024 grid, pans with the camera); HUD biome-name flash banner fades over 3s; tiles shipped at res://assets/biomes/; web export x2 + .tmp/win/HollowDawn-biome.exe (released HollowDawn.exe untouched); headless smoke 0 ERROR, smoke.sh PASS=20 FAIL=0, 136/136 green
open: DA F1 win-screen browser proof via scratch 45s export (.tmp/win-demo-static/, never shipped) -> orchestrator browser drive -> DONE row 9 honest resubmit
