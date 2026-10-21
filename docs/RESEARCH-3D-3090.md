# RESEARCH — 3D remake on the fleet RTX 3090 (MC 11089)

Owner ruling (verbatim, quoted in the dispatch brief): *"then a 3d remake. Same type of
visuals, top down, but with character animations, movements. 3090 only with best possible
model doing the word regardless of time taken."* → Phase-2 decision research. Constraints read
from it: **local 3090 only** (Meshy / cloud ruled out), **best model wins even if slow**, **time
is not a constraint**. Tags below follow citation-discipline: **VERIFIED** = fetched this session
AND the quote supports the claim; **INFERRED** = reasoned, not measured; **PLAUSIBLE** = could
not fetch the primary text. This is a 24GB RTX 3090 shared with the fleet verifier LLM
(VERIFIED — this session's harness environment: the generator window runs on vm100's RTX 3090,
"the 3090 is shared with the fleet verifier LLM, which is paused while the [GPU] window is open";
generation is therefore **exclusive-window / batch-offline**, not concurrent with the verifier).

Target: keep today's top-down look, replace 2D sprites (player; wraith + moor-brute + dune-scarab
+ rime-ghoul + pale-wight; boss "Hollow Warden"; 6 weapons; props) with **real 3D models, animated
and moving**. Current sprites are already made on this 3090 with Qwen-Image (`docs/ARCHITECTURE.md`
"generated on the fleet RTX 3090, Qwen-Image"), so the concept→image front-end already exists.

---

## (a) Image/Text → 3D candidates for 24 GB VRAM

Every model below is image-conditioned (feed a clean concept render); text→3D is done by
first rendering an image — TRELLIS states it directly: *"It is always recommended to do text to
3D generation by first generating images using text-to-image models and then using TRELLIS-image
models"* (VERIFIED, microsoft/TRELLIS README).

| Model | Repo / paper | VRAM (reported) | ComfyUI node | License (ship?) |
|---|---|---|---|---|
| **Hunyuan3D-2.1** (Tencent) | github.com/Tencent-Hunyuan/Hunyuan3D-2.1 · arXiv 2506.15442 | **"10 GB VRAM for shape generation, 21GB for texture generation and 29GB for shape and texture generation in total"** (VERIFIED README) | yes — visualbruno/ComfyUI-Hunyuan3d-2-1 (VERIFIED, 2.1 README community list) + official docs.comfy.org Hunyuan3D tutorial | **Tencent Hunyuan 3D 2.1 Community License — EU/UK/SK EXCLUDED** (see risks) |
| **Hunyuan3D-2 (2.0)** (Tencent) | github.com/Tencent-Hunyuan/Hunyuan3D-2 · arXiv 2501.12202 | **"6 GB VRAM for shape generation and 16 GB for shape and texture generation in total"** (VERIFIED README) → fits 24GB fully | kijai/ComfyUI-Hunyuan3DWrapper + MrForExample/ComfyUI-3D-Pack (VERIFIED, 2.0 README "Community Resources") | Tencent 3D 2.0 Community License (same EU/UK/SK exclusion family) |
| **TRELLIS** (Microsoft, v1) | github.com/microsoft/TRELLIS · arXiv 2412.01506 (CVPR'25) | **"An NVIDIA GPU with at least 16GB of memory is necessary"** (VERIFIED README); verified on A100/A6000 (3090 = Ampere, flash-attn OK) | smthemex/ComfyUI_TRELLIS (VERIFIED via comfy.icu) | **MIT** — "TRELLIS models and the majority of the code are licensed under the MIT License" (VERIFIED) |
| **TRELLIS.2** (Microsoft, NEWEST, 4B) | github.com/microsoft/TRELLIS.2 · arXiv 2512.14692 | **"An NVIDIA GPU with at least 24GB of memory is necessary"** (VERIFIED README) → **exactly at the 3090 ceiling — see risks** | visualbruno/ComfyUI-Trellis2 (VERIFIED via search) | **MIT** — "This model and code are released under the MIT License" (VERIFIED) |
| **TripoSG** (VAST/Tripo) | github.com/VAST-AI-Research/TripoSG · arXiv 2502.06608 | **"CUDA-enabled GPU with at least 8GB VRAM"** (VERIFIED README); 1.5B shape model | via TripoSG community | **MIT** (VERIFIED LICENSE: "Copyright (c) 2025 VAST-AI-Research") |
| **TripoSR** (Tripo+Stability, 2024) | github.com/VAST-AI-Research/TripoSR · arXiv 2403.02151 | **"about 6GB VRAM for a single image input"** (VERIFIED README); "<0.5 s on A100" | older; superseded | **MIT** (VERIFIED LICENSE) |

Quality reputation (honest): Hunyuan3D's benchmark tables are **self-reported** ("surpasses all
baselines") — treat as OVERSTATED, not neutral evidence. Community reality for a shipped game:
**TRELLIS.2 (2025-12, CVPR'26, 4B) is the current open SOTA** — PBR materials, arbitrary topology
(open surfaces / non-manifold), GLB export — and is MIT. Hunyuan3D-2.1 is its nearest PBR rival
but is **license-blocked in the EU**. TripoSG has a strong geometry reputation (sharp features,
2M Image-SDF pairs) but is **shape-only** (needs a separate texturing pass). TripoSR is the oldest
and weakest (fast drafts / props), fine for throwaway blockers.

**24GB reality on this card.** Two of the "best" options do **not** fit in one pass: Hunyuan3D-2.1
combined = **29GB > 24GB** (VERIFIED) — you must run shape and texture as **separate passes** or
use its `--low_vram_mode` (flag is in the 2.1 README gradio command). TRELLIS.2 needs **≥24GB**
(VERIFIED) = right at the limit; run ≤1024³ with `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`
(its own README example sets this) + fp16, and **expect OOM at 1536³**. A real 3090 user reports
Hunyuan3D as slow even on the distilled Turbo build: *"Is it normal that it takes so long to
generate models with Hunyuan3D-2mini-Turbo and an RTX 3090?"* (VERIFIED, YanWenKun/Hunyuan3D-2-
WinPortable issue #45 title).

## (b) Fully-local rig + animation

**Auto-rig (the crux for this game):**
- **UniRig** — github.com/VAST-AI-Research/UniRig · arXiv 2504.12451 (SIGGRAPH'25) · **MIT**
  (VERIFIED LICENSE). *"Aims to handle diverse model categories (humans, animals, objects) with a
  single framework"*; teaser GIFs are a **devil, dragon, rabbit** (VERIFIED README) — i.e. it is
  built for **non-standard/non-human topologies**, exactly the ghoul/wight/scarab case. Input
  `.obj/.fbx/.glb/.vrm`, output a rigged **FBX/GLB** (skeleton + skinning merge commands VERIFIED).
  *"For generation: CUDA-enabled GPU with at least 8GB VRAM"* (VERIFIED) → fits the 3090.
  Honest limit (VERIFIED README): *"the results may degrade significantly if the skeleton is
  inaccurate — for example, if tail bones or wing bones are missing. Therefore, it is recommended
  to refine the skeleton before performing skinning"* → budget **human-in-the-loop cleanup**.
  **SkinTokens** is its newer successor (linked in UniRig README, "+98%–133% improvement in
  skinning accuracy") — evaluate as it matures. (INFERRED: successor may not be fully released yet.)
- **Mixamo** (Adobe, free) is **not** a local option and is **humanoid-only** — its own positioning
  is an "automatically rigged full human skeleton" (PLAUSIBLE, mixamo.com); community notes say
  non-"human proportions" characters need collision fixes (PLAUSIBLE, mixamo-rig-joint-constraint
  repo). Ruled out for scarab/ghoul/wight.
- **Blender free add-ons**: **Rigify** ships with Blender (free/GPL) — solid biped meta-rig +
  IK/FK, but a *manual* meta-rig fit per character, not ML auto-rig for arbitrary meshes
  (INFERRED, well-known Blender capability). Free "Rigify-based" auto-rig add-ons exist (PLAUSIBLE,
  category pages) but UniRig is the stronger non-human answer. **Auto-Rig Pro is paid** → out of
  scope for "free add-ons".

**Motion generation (all HUMAN-bipedal — the key honest finding):**
- **MDM** github.com/GuyTevet/motion-diffusion-model — *"generates coherent motions that achieve
  state-of-the-art results on the HumanML3D and KIT benchmarks"* (VERIFIED, guytevet.github.io/mdm-page).
- **T2M-GPT** github.com/Mael-zys/T2M-GPT — *"Generating Human Motion from Textual Descriptions
  with Discrete Representations"* (VERIFIED, project page title).
- **MLD** (efficient latent-diffusion variant) exists — arXiv 2212.04048, *"Executing your Commands
  via Motion Diffusion in Latent Space"* (VERIFIED arXiv title). (Earlier ID 2212.04503 is a physics
  paper — do not cite; caught and corrected this session.)
- **Walk-cycle feasibility for the stylized non-human humanoids (ghoul/wight) and the beetle
  (scarab): POOR.** These models are trained on **HumanML3D = human mocap** (VERIFIED: benchmark
  name/definition), so they emit *human* gait on a *human* skeleton. Retargeting a human walk onto
  a hunched, long-limbed wraith or a 6-legged scarab looks wrong (INFERRED; standard retargeting
  limitation). Expect **manual keyframe cycles in Blender** or **procedural** motion for them.

**Fallback — procedural animation in Godot (note, cheap, ships reliably):** Godot 4 `Tween`
*"Lightweight object used for general-purpose animation via script"* (VERIFIED,
docs.godotengine.org/.../class_tween) + `AnimationPlayer`/`AnimationTree`. A rigged mesh can get
bob/lean/face-along-velocity/attack-tween procedurally with **zero extra GPU** — the realistic
answer for the non-human enemies and for fast iteration; reserve baked mocap for the player/boss.

## (c) Recommended stack + pipeline (per asset class)

**Recommendation (fits every owner constraint):** TRELLIS.2 as the primary generator (best
open quality **and** MIT — no EU block, unlike Hunyuan3D-2.1), with **TRELLIS v1 / TripoSG as the
24GB-comfortable fallbacks** when a TRELLIS.2 run OOMs; UniRig for rigging; a **hybrid** of
retargeted mocap (player/boss) and **Godot procedural** (scarab/ghoul/wight) for motion.
Hunyuan3D-2.1 only if the owner rules the game does **not** ship to EU/UK/SK (see (d)).

Per-asset pipeline: **concept image (Qwen-Image, already local) → 3D gen → decimate/UV → rig →
motion → GLB → Godot.**

| Asset class | Gen | Rig | Motion |
|---|---|---|---|
| Player | TRELLIS.2 1024³ | UniRig (biped) | MDM/T2M walk+idle, retargeted; else procedural |
| Boss "Hollow Warden" | TRELLIS.2 1024³–1536³ (if VRAM allows) | UniRig | mocap + attack clip; else procedural |
| moor-brute / rime-ghoul / pale-wight (stylized humanoid) | TRELLIS.2 / TripoSG | UniRig biped **+ manual bone fix** | **procedural** (bob/lean/lunge tween) |
| dune-scarab (beetle, non-humanoid) | TRELLIS.2 / TripoSG | UniRig (general/quadruped) | **procedural** leg/scuttle cycle |
| Weapons ×6 (props) | TRELLIS.2 or TripoSR | none | static / Tween spin only |
| Props / biome set-dressing | TripoSR or TripoSG (fast) | none | static |

Pipeline stages + tools: **decimate/UV** = TRELLIS.2's own `to_glb(decimation_target=…,
texture_size=…)` (VERIFIED example.py) or Blender headless `bpy` (decimate/remesh/Smart UV —
free/GPL); **rig** = UniRig `generate_skeleton → refine → generate_skin → merge` (VERIFIED
commands); **motion→GLB** = Blender bake → Godot 4 imports GLB/glTF directly.

**GPU-minutes per asset (source + label):** TRELLIS.2 official, **on H100**: *"512³ ~3s · 1024³
~17s · 1536³ ~60s"* (VERIFIED README table). On this **3090** expect **~2–4× slower** (INFERRED —
lower FLOPS/bandwidth, and the card is shared), so a single ~1024³ asset ≈ **~40–70s of GPU**
(INFERRED), plus UniRig rig (8GB, seconds–minutes, INFERRED) and motion (small, seconds, INFERRED).
Hunyuan3D alt: a community write-up estimates *"100-300 minutes of pure generation time"* for a
200-prop build ≈ **~0.5–1.5 min/asset** (PLAUSIBLE — secondary techpedia source, not the vendor;
treat as order-of-magnitude). Net: **tens of minutes of exclusive-window GPU per character**,
hours for a full pass — consistent with the owner's "regardless of time taken".

## (d) RISKS

1. **LICENSE — the one that can block shipping (owner decision).** The Tencent Hunyuan 3D
   license excludes the EU: *"THIS LICENSE AGREEMENT DOES NOT APPLY IN THE EUROPEAN UNION, UNITED
   KINGDOM AND SOUTH KOREA"*, and *"You must not use … Output or results … outside the Territory"*
   (VERIFIED, Hunyuan3D-2.1 LICENSE) — **including generated meshes**. The fleet/owner is Swedish
   (EU) and this game **ships**, so Hunyuan3D-2.0/2.1 outputs are the wrong legal base unless the
   owner rules EU/UK/SK are excluded territories. It also has a ">1M monthly active users must
   request a license" clause (VERIFIED) — irrelevant at this scale. **MIT models
   (TRELLIS, TRELLIS.2, TripoSG, TripoSR, UniRig) carry no territory limit and are the safe
   commercial path** — this is the main reason to prefer them beyond quality.
2. **Non-humanoid rig quality.** UniRig's own caveat — missing tail/wing bones degrade skinning
   (VERIFIED) — bites hardest on the **scarab** (legs/wings) and the **hunched ghoul/wight**; plan
   manual bone refinement or fall back to procedural-only (no skinning) for those. Human-motion
   models (MDM/T2M/MLD) will **not** credibly animate them (bipedal human mocap — VERIFIED bench).
3. **GPU contention with the fleet verifier.** This 3090 hosts the verifier LLM, only "paused
   while the window is open" (VERIFIED, harness env). A multi-hour TRELLIS.2/Hunyuan batch holds
   that window and **starves the verifier** → run generation as **scheduled offline batches** during
   verifier-idle windows, keep each batch short, never leave the window open idle between assets.
   Owner said time is not a constraint, so batch off-peak rather than fight for the card.
4. **VRAM overflow of 2.1-class models on 24 GB.** Hunyuan3D-2.1 shape+texture = **29GB > 24GB**
   (VERIFIED) → cannot run in one pass; use separate passes or `--low_vram_mode`. TRELLIS.2 min =
   **24GB** (VERIFIED) = the exact ceiling; run ≤1024³, fp16, `expandable_segments:True`, expect
   **OOM at 1536³** and on verbose remesh. TripoSG/TripoSR/TRELLIS-v1 (8/6/16GB) are the safe
   headroom options when a 24GB run dies mid-batch.

**One-line recommendation:** build on the **MIT stack — TRELLIS.2 (primary) → UniRig rig →
retargeted mocap for player/boss + Godot procedural for non-human enemies**, keeping TRELLIS-v1 /
TripoSG as 24GB-comfortable fallbacks; do **not** ship Hunyuan3D-generated assets into the EU.

---
### Source list (fetched this session; quotes in-line above)
Hunyuan3D-2.1 README+LICENSE · Hunyuan3D-2 README · TRELLIS README · TRELLIS.2 README+LICENSE ·
TripoSG README+LICENSE · TripoSR README+LICENSE · UniRig README+LICENSE · arXiv 2506.15442 /
2501.12202 / 2412.01506 / 2512.14692 / 2502.06608 / 2403.02151 / 2504.12451 / 2212.04048 ·
GuyTevet/motion-diffusion-model (+mdm-page) · Mael-zys/T2M-GPT · Godot class_tween docs ·
Hunyuan3D-2-WinPortable issue #45 · comfy.icu smthemex/ComfyUI_TRELLIS · mixamo.com (PLAUSIBLE).
ComfyUI nodes: visualbruno/ComfyUI-Hunyuan3d-2-1, kijai/ComfyUI-Hunyuan3DWrapper,
MrForExample/ComfyUI-3D-Pack, smthemex/ComfyUI_TRELLIS, visualbruno/ComfyUI-Trellis2 (existence
VERIFIED via README/comfy.icu; their VRAM behaviour not separately measured here — PLAUSIBLE).
