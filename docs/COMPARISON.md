# Comparison — Hollow Dawn vs genre footage

Run `.audits/202610201514-81bb9a6c` · MC 11071 · researcher seat · 2026-10-21.
Owner authorization (recorded on card 11071, brief verbatim): *"can you do a playthrough of
what has been built and compare it with gameplay on youtube?"*

**What we compared.** OUR side: the captured playthrough (8 screenshots in `playthrough/pt-*.png`,
run facts lv2@129s lv3@156s lv4@209s, death t=309.7s, 260 kills, 16 gold, submitted score 4513 =
Rank #1, re-checked arithmetically: 309.7·10+260·5+4·25+16 = 4513.0 exactly — VERIFIED) plus the
live API read-back (`GET /api/highscores` this session returned the OrchPlay5/4513 row — VERIFIED)
and, for mechanics not reached in the run (boss, win, Dawnlight), code proof from `godot/`
(cited per row). Footage side: four public Vampire Survivors gameplay videos (URLs + citation
tags in §e), frames in `playthrough/footage/f-*.png`.

**Ambiguity note (stated).** The brief said placement-plan.md §References names the inspiration
titles; placement-plan.md has **no §References section** (instrument: full-file read). The
inspiration is instead identified by the owner-quoted brief, the project dir name
`vampire_survivor`, and README.md:3 — "Vampire-Survivors *mechanics*, clean-room". Treated as
Vampire Survivors; VERIFIED via the two preceding artifacts.

**Footage access statement.** The YouTube watch-page player **refused to render the main content
stream in this headless browser** across 4 videos and ~8 load attempts: ads played (evidence
`f-12-ad-wall.png`), but the main stream always ended at "Something went wrong. Refresh or try
again later." (evidence `f-11-playback-wall-error.png`; video element stuck at readyState 0,
videoWidth 0). Per the brief's fallback clause we used the videos' **YouTube-embedded stills** —
`maxresdefault`/`oar`/`hq` variants, which are images embedded *from the actual videos*, served
as plain GETs. Stills are fixed positions (legacy storyboard ≈ 25/50/75 % of runtime —
INFERRED convention); in-frame in-game timers are read where visible. No timestamped scrubbing
was possible; the level-up/upgrade overlay was NOT caught in any still (labeled per row).

---

## (a) Mechanic-parity table

| Mechanic | OUR proof | FOOTAGE observation | Verdict |
|---|---|---|---|
| Movement (8-dir free move) | pt-2-early.png player sprite mid-field; run facts (kills accumulating while moving); input contract README:13 | Player-centered character with enemies converging in every in-run still (f-3, f-4, f-8) — free 2-D movement [INFERRED from stills + genre norm] | parity |
| Auto-attack weapons | pt-2 (grey forward arc, no attack key exists); pt-4 (white ember trail); weapon-icon row "2 1 1" pt-6; 6-weapon spec placement-plan §5 | f-4: multiple concurrent effect silhouettes around the character (white orbit trails, purple arc loop, blue streaks) with player hands empty — auto-firing [VERIFIED direct read + vision pass] | parity (class); ours fewer concurrent effects at same run-minute |
| Swarm spawn scaling | run facts: kills 8@1:58 → 15@2:09 → 49@2:35 → 124@3:28 → 260@5:09; spawn formula `min(12, 1+1.3·min)/s` (placement-plan §5; world.gd) | f-3 in-game 10:56: 4401 kills; f-4 in-game 12:56: 9641–9643 kills (480p; both readings, VERIFIED ±digit), 30–40 units visible in a ~420×250 px field inset; f-1 thumb: >100 units [VERIFIED direct reads + vision pass] | **weaker** — pressure curve far below genre norm (see gap G1) |
| XP gems | green XP bar across pt-2→pt-6 (0→full at each level); gem drop + magnet spec §5; level timestamps | ground carpeted with small blue/cyan gem drops in f-3/f-4/f-8 [VERIFIED direct read + vision pass] | parity (ours visibly sparser drops) |
| Level-up choice cards | pt-3 "Choose an upgrade" 3 framed cards (Ember Bolt / Talon Lash Lv2 / Cinder Halo, keys 1/2/3); pt-5, pt-6 same pattern; pause-to-pick matches §5 | NOT captured in any embedded still; player refused scrubbing. Selection-overlay exists in the genre [INFERRED genre knowledge — flagged UNVERIFIED for footage side] | parity at class level (unconfirmed vs footage) |
| Gold | HUD "Gold 3/6/9/12/16" across pt shots; coin drop 6 % + boss +50 g §5; coin.png | f-3: gold "996" top-right + yellow coin dots on field + "+282.00 G" chest burst; f-2 menu gold "138" [VERIFIED] | parity |
| Timer / HP / kills HUD | pt-4 top strip: 02:09, "34/100" bar, Lv 2, Gold 6, Kills 15, weapon icons [VERIFIED direct + vision bullet 1] | f-3/f-4: blue XP bar top-left, timer top-centre (10:56/12:56), kill count + gold top-right, LV badge top-right corner [VERIFIED + vision pass] | parity (same info set, different layout) |
| Pause | pt-4 orange "PAUSED" label, timer frozen at 02:09; Esc contract README:13; VS_STATE time-freeze test | no still can show pause [footage UNVERIFIED]; menu/pause is genre-standard [INFERRED] | parity (ours VERIFIED, footage unobserved) |
| Death + leaderboard | pt-7 "The night took you" + stats + name field + Submit; pt-8 "Rank #1" + board rows; POST 201/rank VERIFIED via live API this session | no leaderboard shown in our stills [footage UNVERIFIED]; VS class has run-summary/stats screens [INFERRED] | **stronger** (persistent server-backed board is beyond what the footage evidences) |
| Win condition | `WIN_TIME := 600.0` + phase "win" (game_state.gd:7,10; main.gd:134) — not reached in the run (death at 309.7 s) [code VERIFIED, live UNTESTED] | VS stages end on a timed finale [INFERRED genre knowledge] | parity (class); ours 10:00 vs genre's longer stages |
| Dawnlight heal drops | `world.gd:23` heals array + drop/magnet lines 94,124,140; render.gd:130–138 cross drawn in DAWNLIGHT color — none visible in pt frames [code VERIFIED, frame UNVERIFIED] | healing pickups exist in the genre (food drops) [INFERRED; not in our stills — UNVERIFIED] | parity (both sides weakly evidenced on-frame) |
| Boss wave | `BOSS_AT := 540.0` "The Hollow Warden" (world.gd:5,70–71) + 128 px boss sprite + boss bar (render.gd:10,87) — run ended before 9:00 [code VERIFIED, live UNTESTED] | no boss frame in our stills [footage UNVERIFIED]; timed elite/boss waves are genre-standard [INFERRED] | parity (class); neither observed live |

## (b) Visual-readability assessment (our build vs genre norm)

- **Density / figure-ground.** Our swarm (~30 enemy tokens at 1280×720, pt-4/paused) sits on a
  dark navy grid with dark sprites — the per-area density is far below the footage norm, where
  vision pass counts "30–40 individual units" inside a field inset roughly 1/10 the pixel area
  (f-4), and the f-1 thumb packs >100 units screen-wide. Bright grass-green ground in footage
  gives strong figure/ground separation; our desaturated moonlit palette (MANIFEST art anchor)
  costs enemy-vs-background contrast at distance.
- **Enemy states.** Ours reads as circular glow-halo tokens; overlapping translucent halos blur
  into bubbles at swarm counts ("~30+ circular tokens", vision bullet 2), making instant threat
  counting hard. Footage sprites are small, high-contrast silhouettes that stay individually
  legible when packed.
- **Effect clarity.** Our ember/ward effects are soft white blobs that occlude what they hit
  (pt-4, pt-6). Footage weapon effects are thin distinct lines (orbit arcs, thrown-arc
  scythes, radiating beams) still separable at 480p (f-3/f-4 reads).
- **HUD.** Ours is single top-strip text (timer, HP x/y, XP bar, Lv, Gold, Kills, weapon row) —
  high legibility, arguably clearer than the footage's small pixel-font corner clusters.
  Parity-plus on legibility; the genre layout reads faster at a glance (bigger XP bar, centred
  timer) but our values are exact-text.
- **Overlay/menu polish.** Our level-up overlay is readable (framed cards + keys) but the card
  interiors are near-empty dark panels — name + one-line effect carry all meaning; footage's
  upgrade UI (per the class-standard icon grid) conveys choices pictorially. Our menu/title
  screens (pt-1, f-2, f-5) are clean; parity.

## (c) Ranked gap list (game-feel / mechanic-class inputs for the design discussion — NOT copied content)

1. **G1 Swarm-pressure density below genre norm.** Ours: 260 kills by 5:09 (~51 kills/min at the
   5-min mark, ~30–40 on-screen). Footage: 4401 kills at in-game 10:56 and 9641+ at 12:56
   (f-3/f-4) with hundreds on screen at peak (f-1). Even allowing the genre's longer 30-min
   stage vs our 10-min stage, the *shape* of the pressure curve is the gap: genre escalates to
   wall-of-enemies; ours plateaus at scattered clusters. (Quantified VERIFIED reads.)
2. **G2 No weapon-evolution tier.** Footage f-7 shows the class-level crafting table (base weapon
   + passive item → evolved weapon, ~16 rows). Ours caps at weapon level 8 + 5 passive kinds —
   no fusion/evolution payoff exists in `weapons.gd` (absence instrument: grep boss/heal/evolve
   terms + §5 spec). Design question: add an evolution tier or accept the flatter power curve.
3. **G3 Weapon visual identity.** 6 weapons read as similar pale blobs/arcs (b §effects). Genre
   frames stay weapon-legible at 480p. Affects build fantasy ("my Bible orbits" vs "some glow").
4. **G4 Ground-reward carpet.** Genre fields are littered with gems/coins even mid-run
   (f-3/f-4/f-8); ours shows few visible drops (pt frames) — weakens the greed-loop feedback.
5. **G5 Concurrent-weapon pacing.** At 5:09 ours shows 3 weapon icons (2/1/1); genre frames show
   fuller weapon rows earlier — our level cadence (lv4 at 209 s) gates that.
6. **G6 No meta progression.** Footage menu still (f-2) shows Collection / Power-Up / Achievements
   (persistent-between-runs layer); ours has only the run + a score board.
7. **G7 No audio.** Our build states "M — mute (no audio in this build)" (pt-1). Footage audio
   can't be assessed from stills [UNVERIFIED], but survivors audio-cues are a known feel pillar
   [INFERRED] — flag for design.
8. **G8 Verification risk (not a genre gap):** boss (9:00), win (10:00) and Dawnlight drops are
   code-VERIFIED only — never seen live because our capture-run died at 5:09.

## (d) Clean-room attestation

No asset, art, name, text, or code was taken from any footage source into Hollow Dawn. All 16
game PNGs are original, generated on the fleet 3090 with recorded prompts
(`static/assets/MANIFEST.md`, placement-plan §4); all names (Hollow Dawn, Hollow Warden, Talon
Lash, Dawnlight…) are original; the engine is fleet-authored Godot GDScript + Python stdlib.
Only **genre-level observations of what the class of game feels like** (density, HUD info-set,
auto-fire, choice-overlay, evolution-tier existence) passed from footage into this document —
these are inputs to a design discussion, not implementation references. Per MC 10365 R2, the
owner authorized this comparison in writing (quoted on card 11071); this document is the
evidence record and is not fed into a product-code session as a copy source.

## (e) Sources (citation discipline)

Footage (all frame files in `playthrough/footage/`):

1. [VERIFIED — in-page playerResponse fetch + frames viewed] "Vampire Survivors is the Best Game
   of 2022 so far!  Vampire Survivors Gameplay" — BaronVonGames (2.71M subs badge shown),
   https://www.youtube.com/watch?v=wgYu6lLi6cE · viewCount "587500", lengthSeconds "1593".
   Frames: `f-1-v1-barongames-swarm-thumb.png` (video's embedded 1280×720 frame: >100 skeleton
   enemies with muskets ring a red-robed player), `f-2-v1-barongames-menu-oar.png` (in-game
   main menu: gold "138", START / POWER UP / COLLECTION / ACHIEVEMENTS, version stamp
   "v0.2.9c – EA").
2. [VERIFIED — in-page playerResponse fetch + frames viewed] "First level 220+ WORLD RECORD Run!
   Mad Forest Record Run on Vampire Survivors" — Ben Evolved,
   https://www.youtube.com/watch?v=ppTksyNGwf8 · viewCount "514120", lengthSeconds "2436".
   Frames: `f-3-v2-benevolved-midrun-hq2.png` (in-game 10:56, 4401 kills, gold 996, LV 30, chest
   burst "282.00 G", gem/coin field), `f-4-v2-benevolved-lateswarm-hq3.png` (in-game 12:56,
   kills 9641–9643 ±digit at 480p, LV 49, 30–40 units in a small field inset, orbit/arc/beam
   weapon effects), `f-5-v2-benevolved-title-hq1.png` (title "PRESS TO START"),
   `f-6-v2-benevolved-thumb-composite.png` (composite thumb: character sprite on in-game Mad
   Forest ground).
3. [VERIFIED existence + displayed metadata; frames viewed] "50 Tips & Secrets About Vampire
   Survivors I WIsh I Knew When I Started" — Dex, 1.1M views, 30:59 badge (both read from
   YouTube's own watch-page related sidebar DOM this session),
   https://www.youtube.com/watch?v=0VK1JuPAu8Q. Frames:
   `f-7-v3-dex-evolutions-thumb.png` (in-game evolution/crafting table: three columns
   "Base weapon | Passive Item | Evolution", ~16 rows — G2 evidence),
   `f-8-v3-dex-randomfootage-hq2.png` (in-run chest burst "1461.00 G", LV 22, kills 4338, wide
   gem carpet, fire AoE effect).
4. [VERIFIED existence + displayed metadata; frames viewed] "Vampire Survivors | Full Game
   Walkthrough | No Commentary" — The Game Archivist, 80K views, 4:35:52 (search-page DOM),
   https://www.youtube.com/watch?v=bzYEU3rBD-Y. Frames:
   `f-9-v4-walkthrough-treasure-hq2.png` (chest-burst overlay with gem field),
   `f-10-v4-walkthrough-promo-thumb.png` (promotional art thumb — NOT a gameplay frame).
5. [VERIFIED this-session] Wall evidence for the playback refusal:
   `f-11-playback-wall-error.png` (player error screen), `f-12-ad-wall.png` (ads render fine).

Our run (all VERIFIED this session or at capture 2026-10-21 08:30–08:40):
`playthrough/pt-1-menu.png … pt-8-rank1.png`; score formula arithmetic re-run (4513.0 exact);
`GET /api/highscores` live read-back (OrchPlay5, 4513, 309.7 s, 260 kills, Lv 4, Rank #1);
code rows: `godot/scripts/world.gd` (BOSS_AT 540, heals), `game_state.gd:7,10` (WIN_TIME 600,
phases), `main.gd:134`, `render.gd` (boss bar, Dawnlight cross). Vision corroboration via
Lane E describe-image (qwen3.8-flash-next): 3 calls, prompt_tokens 1024–1067, 15.2–22.0 s each;
its bullets are quoted where cited.
