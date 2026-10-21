# Asset manifest — "Hollow Dawn" original art

Generated 2026-10-20 on the fleet vm100 RTX 3090 via the imagegen MCP tool
(Qwen-Image t2i, Lightning 8-step, seed 42, `background=transparent` → real PNG alpha cutout).
All 16 files match the pinned contract C filenames (placement plan
`.audits/202610201514-81bb9a6c/placement-plan.md` §4). Sizes on disk are the generation
resolutions (sprites/icons/pickups 512×512, card-frame 512×640, boss 1024×1024); the client
draws them scaled per §4.

Style anchor included verbatim in EVERY prompt (quoted once here):

> Gothic dark-fantasy survivor art, desaturated moonlit palette (ink #10131c, slate #2a3140,
> moonlight #aebdd4, bone #d8d2c0, blood #8e2f35, ichor-green #6fae5a, ember #c97b3d),
> readable silhouettes, strong moonlight rim light from upper-left, painted look, no text,
> no watermark.

Per-asset prompts = the description line below + " — " + the style anchor above.

| file | px | on-disk bytes | prompt description (before the style anchor) |
|---|---|---|---|
| player.png | 512×512 | 112654 | Lone gothic survivor figure in a long tattered dark coat, one hand raised holding a small glowing lantern, facing forward in a ready walking pose, simple readable silhouette for a small game sprite |
| player-alt.png | 512×512 | 157145 | Gothic survivor level-up variant: same lone figure in a long tattered dark coat now with bone pauldrons and a hood, raised lantern burning pale ichor-green, facing forward, simple readable silhouette for a small game sprite |
| enemy-wraith.png | 512×512 | 151006 | Floating tattered shroud wraith with two pale eye lights, arms outstretched drifting forward, trailing shredded cloth instead of legs, simple readable silhouette for a small game sprite |
| enemy-hound.png | 512×512 | 142043 | Gaunt skeletal hound mid-leap to the right, elongated limbs, exposed ribcage, pale glowing eyes, tattered hide, simple readable silhouette for a small game sprite |
| enemy-crawler.png | 512×512 | 229637 | Bloated armored crawler beast low to the ground, chitinous segmented plates, dragging clawed limbs, hunched heavy silhouette facing left, simple readable silhouette for a small game sprite |
| enemy-cultist.png | 512×512 | 150964 | Hooded robed cultist standing, floor-length tattered ceremonial hooded robe, face lost in shadow with two faint pale glints, faint ichor-green sigil glow at the wide sleeves, hands raised in a chanting pose, simple readable silhouette for a small game sprite |
| boss-warden.png | 1024×1024 | 1034381 | The Hollow Warden boss: towering armored warden in heavy cracked plate armor, cracked hollow great-helm with a single pale light burning inside, tattered dark mantle, holding an oversized iron lantern staff, imposing dominant silhouette, simple readable silhouette for a game boss sprite |
| icon-talon.png | 512×512 | 88494 | Single curved bone claw weapon icon, talon-shaped, centered, clean bold shape readable at very small size, no frame, no background decoration |
| icon-ember.png | 512×512 | 115185 | Single flame mote weapon icon, a small swirling ember ball with a rising flame wisp, centered, clean bold shape readable at very small size, no frame, no background decoration |
| icon-cleaver.png | 512×512 | 102091 | Single notched bone axe weapon icon, a heavy cleaver head carved from bone on a short dark haft, centered, clean bold shape readable at very small size, no frame, no background decoration |
| icon-halo.png | 512×512 | 146327 | Single rusted iron ring halo weapon icon with glowing ember points along its edge, centered, clean bold shape readable at very small size, no frame, no background decoration |
| icon-ward.png | 512×512 | 201348 | Single glowing sigil circle weapon icon, a protective rune circle drawn in pale moonlight lines with an ichor-green glow at its core, centered, clean bold shape readable at very small size, no frame, no background decoration |
| icon-spike.png | 512×512 | 101787 | Single jagged grave shard weapon icon, a broken splinter of weathered gravestone stone with sharp jagged edges pointing up, centered, clean bold shape readable at very small size, no frame, no background decoration |
| card-frame.png | 512×640 | 341884 | Ornate vertical gothic upgrade-card frame: dark carved wood border with bone corner ornaments and small ember accents, completely empty plain dark interior for text to be drawn on top, decorative border only, portrait orientation |
| coin.png | 512×512 | 184600 | Single antique bone-gold coin game pickup, slightly tilted, faint skull engraving on its face, simple bold round shape readable at very small size |
| gem.png | 512×512 | 92026 | Single glowing green soul gem game pickup, faceted crystal, ichor-green inner light, simple bold gem shape readable at very small size |

All 16 verified with `file` as `PNG image data, …, 8-bit/color RGBA, non-interlaced`
(real alpha cutout per contract).

## Biome ground tiles (2026-10-21, card 11078)

Four top-down game-ground texture tiles for the owner terrain/biome request ("terrain,
different biomes like snow, desert, grass, tundra and so on"). Generated on the same
vm100 RTX 3090 imagegen pipeline (Qwen-Image t2i, Lightning 8-step) with the style
anchor's dark moonlit palette, but **opaque 8-bit RGB** ground (no alpha) — these are
backgrounds, the player sprite and enemy glow halos must stay readable ON TOP, so all
four are graded very dark (mean luminance 39–55/255, no blown highlights). Grass and
tundra are single-pass t2i (seed 42); desert and snow went through extra passes
(desert: t2i seed 44 + reference-edit seed 45 to remove scrub/perspective; snow: t2i
seed 44 + reference-edit seed 45 for snow identity + a deterministic 0.58× PIL
luminance grade). Seamless-tiling was style-level (uniform edge-to-edge density), not
pixel-exact wraparound — SUPERSEDED by the tile re-master below (card 11084): all four
files below were replaced; their bytes/ratios are the re-mastered ones, the 11078
generation history is kept for provenance. Per-tile vision verdicts:
`.tmp/biome-art-11076.txt`.

| file | px | on-disk bytes | prompt description (before the style anchor) |
|---|---|---|---|
| biomes/grass.png | 1024×1024 | 2445218 | Seamless top-down dark moor-grass ground texture at night: short dense dormant grass tufts barely visible in moonlight, subtle dark moss-green and grey-brown tuft clumping, faint patches of damp dark earth, rough weathered texture, no objects, no path, no characters, no text (re-mastered card 11084) |
| biomes/desert.png | 1024×1024 | 1546787 | Seamless top-down deep dune-sand ground texture at night: fine wind-swept sand with faint thin rippled wind lines across the whole tile, deep ink shadows with muted cold sand-brown highlights, smooth weathered texture, no objects, no plants, no text (re-mastered card 11084, seed 44 regen — v1 carried the same perspective banding as the 11078 tile) |
| biomes/snow.png | 1024×1024 | 1811095 | Seamless top-down bluish-grey snowfield ground texture at night: wind-scoured compacted snow, faint diagonal wind streaks and low sastrugi ridges, fine crystalline grain with scattered tiny frost sparkles and thin blue-grey ice patches, dark underexposed moonlit grade, no objects, no footprints, no text (re-mastered card 11084, seed 44 regen — v1 carried a crust/flat-snow perspective break) |
| biomes/tundra.png | 1024×1024 | 2383921 | Seamless top-down frozen cracked-mud ground texture at night: polygonal dried mud crack pattern across the whole tile, thin pale frost lining the cracks, subtle icy sheen patches, cold rough weathered texture, no objects, no rocks, no text (re-mastered card 11084) |

## Tile re-master (card 11084, 2026-10-21)

DA-c2 G2: the 11078 biome tiles showed VISIBLE SEAMS tiled (render.gd `tiled=true`;
live :8123 captures). All four tiles re-mastered genuinely seamless on the same vm100
RTX 3090 imagegen pipeline, then made wrap-continuous by a deterministic recipe
(FFT wrap-safe low-frequency flatten → roll-half offset-blend across the midlines with
high-frequency detail restore → auto film grain → per-channel palette match to the
11078 file's mean/std — palette and mean luminance preserved within ±1). Both copies
replaced (`static/assets/biomes/` + `godot/assets/biomes/`, byte-identical; dims/type
unchanged so the `.import` files need no edit — the ctex caches regenerate on next
Godot open/export). Seam metric: mean|left−right| and |top−bottom| wrap-diff ÷
mean|neighbour-diff| (~1.0 seamless; gate ≤1.25). Worst-axis old→new:
grass 4.44→1.09, desert 8.92→1.02, snow 7.85→1.12, tundra 3.38→1.10. Full old-vs-new
table, regen log and vision-lane leg (partial + low-confidence, disclosed):
`.tmp/tile-reseam-11084.txt`. Residual honest gap: the offset-blend midline bands are
faintly perceptible at tile CENTRES on grass close-up (soft, not an edge step); the
tile EDGES — what tiling shows — are seam-free by measurement.

## Biome enemies (2026-10-21, card 11081)

Four biome-themed enemy sprites for the owner request ("Addition would be different enemie
types based on biome"). One creature per shipped biome band: moor-brute → MOORLAND (grass),
dune-scarab → BURNING DUNES (desert), rime-ghoul → THE FROZEN WASTE (snow), pale-wight →
DEAD TUNDRA (tundra). Same vm100 RTX 3090 imagegen pipeline as the 16 shipped sprites
(Qwen-Image t2i, Lightning 8-step, `background=transparent` → real PNG alpha RGBA
cutouts, 1024×1024, no ground shadow plate), each carrying the shipped style anchor and
the set's "dark body, one glowing signature accent" readability treatment; each silhouette
is distinct from the hooded shroud wraith. Single-pass t2i except dune-scarab, which was
regenerated once (v2) after a fleet-vision readability pass found the first cut's outline
would sink on near-black ground — v2 adds the moonlit rim line tracing shell and legs.
Per-sprite vision verdicts: `.tmp/enemy-art-11079.txt`.

| file | px | on-disk bytes | prompt description (before the style anchor) |
|---|---|---|---|
| enemies/moor-brute.png | 1024×1024 | 1163385 | Hunched bog-body horror creature: a stocky low brute made of twisted gnarled roots and wet dark moss bundled into a hunched shoulders-and-arms silhouette, small buried head, pale green bone-glow (#6fae5a) shining from inside its hollow chest cavity and knotholes, wet moss highlights |
| enemies/dune-scarab.png | 1024×1024 | 785248 | Six-legged carapace crawler creature: a low wide scarab-like beast with a glossy obsidian-black domed shell, six clawed dark legs splayed outward, a segmented armored underbelly, glowing ember-orange cracks (#c97b3d) splitting the obsidian shell like cooling lava seams, faint ember glow leaking from the cracks; strong moonlight rim light tracing the outer edge of shell and every leg |
| enemies/rime-ghoul.png | 1024×1024 | 698462 | Gaunt frozen corpse ghoul creature: a tall emaciated humanoid with frostbitten grey-blue skin, a thick crust of white-blue rime frost over its shoulders, arms and ribcage, a tattered frozen shroud hanging stiff and ice-rimed from its arms, hollow eye sockets with a faint cold blue-white glow |
| enemies/pale-wight.png | 1024×1024 | 656687 | Near-invisible ghostly wight creature: a tall thin spectral humanoid figure made of translucent smoke-grey mist fading at the edges like cold vapor, a faint cold violet glow (#9b8cff) outlining its form and pooling in its hollow face, exposed cracked pale ice bones showing through the mist at its hands and ribs, drifting pose with wispy dissolving lower body |
