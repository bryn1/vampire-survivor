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
luminance grade). Seamless-tiling is style-level (uniform edge-to-edge density), not
pixel-exact wraparound. Per-tile vision verdicts: `.tmp/biome-art-11076.txt`.

| file | px | on-disk bytes | prompt description (before the style anchor) |
|---|---|---|---|
| biomes/grass.png | 1024×1024 | 1975560 | Seamless top-down dark moor-grass ground texture at night: short dense dormant grass tufts barely visible in moonlight, subtle dark moss-green and grey-brown tuft clumping, faint patches of damp dark earth, rough weathered texture, no objects, no path, no characters, no text |
| biomes/desert.png | 1024×1024 | 1384508 | Seamless top-down deep dune-sand ground texture at night: fine wind-swept sand with faint thin rippled wind lines across the whole tile, deep ink shadows with muted cold sand-brown highlights, smooth weathered texture, no objects, no plants, no text |
| biomes/snow.png | 1024×1024 | 1554393 | Seamless top-down bluish-grey snowfield ground texture at night: wind-scoured compacted snow, faint diagonal wind streaks and low sastrugi ridges, fine crystalline grain with scattered tiny frost sparkles and thin blue-grey ice patches, dark underexposed moonlit grade, no objects, no footprints, no text |
| biomes/tundra.png | 1024×1024 | 1939908 | Seamless top-down frozen cracked-mud ground texture at night: polygonal dried mud crack pattern across the whole tile, thin pale frost lining the cracks, subtle icy sheen patches, cold rough weathered texture, no objects, no rocks, no text |
