# 3D Realism Overhaul — Audit, Decisions & Change Log

Scope: rendering/visual pipeline of the Kommilo 3D campus (`index.html`, module script).
App logic, UI, routing, state and interactions are untouched. Verified after every
phase with a headless-Chromium harness (screenshots day/night, console capture,
14-step interaction regression, draw-call accounting).

---

## 1. Audit (Step 0)

**Stack detected:** vanilla Three.js **0.169** from the jsdelivr CDN via import map,
single-file app (`index.html`), no build system, no TypeScript, no React Three Fiber.
Decision: build on this stack with `three/addons` only — no framework swap, no new
dependencies (zero-tolerance rule 7). The brief's drei/R3F references map to their
three/addons equivalents (`Sky`, `GTAOPass`, `UnrealBloomPass`, `ShaderPass`+`VignetteShader`).

**Reference photos analyzed** (attached to the session; the real Studierendenhaus TU
Braunschweig — the same building the scene models):

| Photo | Content | Extracted target values |
|---|---|---|
| Autumn dusk exterior | deep navy sky, warm ~3500–4500 K interior glow, gold curtains, leaf litter | night sky = blue hour (not black), warm interior key, cool/warm contrast |
| March + Jan interiors | soft bright neutral daylight, white ribbed deck, grey carpet, yellow accents | day = soft warm sun + high ambient, no harsh contrast indoors |
| July dusk after rain | saturated blue-hour sky, glowing facade, wet asphalt sheen | asphalt roughness variation, night bloom moderate, navy fog |
| January night | building radiating from inside, hedge silhouettes | night: interior carries the scene, environment nearly dark |

**Diagnosis — gaps vs. the references (baseline screenshots in the PR):**

1. **No working cast shadows** — the shadow camera frustum was assigned via
   `Object.assign` but `updateProjectionMatrix()` was never called, so the ortho
   frustum silently stayed at its ±5 m default (pre-existing bug).
2. **Indoor `RoomEnvironment` used as IBL for an outdoor scene** → wrong ambient
   color and "plastic" flatness.
3. **No sky** — a CSS gradient behind a transparent canvas; fog color mismatched it.
4. Linear fog with near-white color; no atmospheric depth.
5. **No ambient occlusion** (a comment claimed SAO; only bloom existed).
6. Night mode: bloom strength 1.05 blew the facade into a white blob; sky pitch black.
7. Composer path had no AA (canvas MSAA does not apply to post-processed rendering).
8. No normal/roughness maps anywhere; visible texture tiling on lawn/pavers.
9. No wind, no particles, no camera life; leaf cards read as static plastic.
10. Magic numbers scattered through the file; scene globals leaked via `window.__*`.
11. Table/partner rebuilds leaked GPU geometries/materials.

Scale check: the scene is already 1 unit = 1 m (people ≈ 1.7 m, storey 3.3 m,
trees 7–13 m) — no rescale needed. Camera FOV 35° already cinematic.

---

## 2. What was implemented (phases A–D)

**A — Renderer, lighting, materials**
- Explicit `outputColorSpace = SRGBColorSpace`; ACES filmic with per-mode exposure.
- `Sky` dome (Preetham) with a `skyScale` luminance uniform; the CSS gradient is now
  only a fallback. Sun disc/azimuth/elevation shared by key light, sky and specular.
- IBL: PMREM generated from the same sky **with the solar disc stripped from the
  shader** — direct sun comes only from the shadow-casting `DirectionalLight`.
  (Leaving the disc in creates a shadow-less second sun that flattens everything.)
- Shadow fix + 2048 px map, tight ±46 m frustum, `bias -0.0004`, `normalBias 0.025`.
- Layered light rig per mode: warm sun key / cool moon key, hemisphere bounce,
  faint opposite fill, sky IBL. No uniform AmbientLight.
- Full material pass: per-material `envMapIntensity` (config table), procedural
  Sobel normal maps for lawn/pavers/bark/wood/carpet/asphalt (zero new payload),
  asphalt roughness variation (wet July-photo sheen), albedo clamped below pure
  white, leaf-card backface translucency.
- Dead `Water` import removed; `window.__bloom/__water*/__stL*/__bulbMat/__dlMat/
  __terrasseLights` globals replaced by module scope + one documented handle.

**B — Atmosphere, camera, post**
- `FogExp2` color-matched per mode (hazy blue-grey day / navy blue-hour night).
- Post chain: `RenderPass → GTAO → UnrealBloom → OutputPass → Vignette`, composer
  target with 4× MSAA (WebGL2). Bloom per mode (day whisper, night warm glow).
- Camera: damping 0.05, config near/far, subtle "breathing" drift applied as a
  bounded delta so it can never accumulate or fight the controls.

**C — Vegetation & life**
- Shared foliage shader hook: per-instance wind phase from instance world position;
  tip-weighted sway for grass/hedges, rigid-cluster sway for tree/shrub leaf cards.
- World-space macro-noise brightness variation on lawn + pavers (kills tiling).
- Particles (140 total, budget < 200): fireflies at night, dust motes in the hall by
  day, falling leaves under the park trees. Two `Points` + one `InstancedMesh`,
  all buffers preallocated — zero per-frame allocations.

**D — Performance**
- Quality tiers (high/medium/low): pixel ratio 2 / 1.5 / 1.1, shadow map 2048/2048/1024,
  GTAO on / on-half-res / off. Coarse-pointer (mobile) starts at medium.
- FPS monitor: drop below 45 fps (fast), raise above 57 fps (slow, 3 good windows,
  session ceiling prevents ping-pong); outlier frames after tab-backgrounding are
  discarded. Measures on every render path (campus, theme worlds, effects off) so
  a struggling HiDPI device always recovers. Tier changes propagate the pixel
  ratio to the composer (`composer.setPixelRatio`) — its cached ratio otherwise
  only reflects construction time.
- Rebuilds now dispose geometries + per-instance materials (shared palette kept).
- Static building/park world matrices computed once, then frozen.

---

## 3. sceneConfig — the tuning table

Everything visual lives in the `sceneConfig` object at the top of the module script,
one comment per value. Live-tune in DevTools:

```js
__kommilo3d.config.modes.nacht.bloom.strength = .7
__kommilo3d.applyMode()          // re-apply the active mode
__kommilo3d.setQualityTier('low') // force a quality tier
__kommilo3d.tier()               // current tier
__kommilo3d.info()               // draw calls/triangles of the last frame
```

Key groups: `modes.tag` / `modes.nacht` (exposure, sun/sky, hemi/fill, fog, bloom,
interior emissives, water), `quality` (tiers + fps thresholds), `shadow`, `ao`,
`vignette`, `wind`, `particles`, `materials` (envMapIntensity table, normal-map
strengths, leaf translucency).

---

## 4. Decision log

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | Brief assumes R3F/drei/postprocessing — repo is vanilla single-file three.js | Stay vanilla, use `three/addons` equivalents | Brief's own rule: detect the stack and build on it; rule 7 forbids dependency creep |
| 2 | "Type check + production build" don't exist here | Equivalent gate: ESM syntax check + headless-Chromium run with zero app console errors + screenshot + 14-step interaction regression, after every phase | Strongest available verification for a build-less app |
| 3 | HDRI file for IBL? (none in repo, CDN egress for .hdr blocked in this sandbox) | Generate IBL from the Preetham sky via PMREM, sun disc stripped | Zero payload, works offline with SW cache, guarantees sky/sun/reflection consistency |
| 4 | Preetham raw luminance is ~10× typical HDRIs | `skyScale` uniform on the visible dome + low `envIntensity` | Saturated photo-blue sky at ACES 1.12 and readable shadows |
| 5 | Sun disc in the IBL flattened all shadows | Strip `L0 += vSunE*19000*Fex*sundisk` from the env sky's fragment shader | Direct light must come only from the shadowed DirectionalLight |
| 6 | Missing shadows root cause | Fixed missing `updateProjectionMatrix()` (pre-existing bug) | Shadows are an acceptance criterion; fix, not workaround |
| 7 | three's `VignetteShader` darkness semantics differ from the postprocessing lib | darkness 1.22 (≈0.3 in lib scale) | At 0.38 the shader *lightens* corners toward grey |
| 8 | DoF pass? | Skipped | Marked optional in the brief; hurts label legibility over tables and mid-range fps; bokeh quality of the addon pass is poor |
| 9 | SMAA vs MSAA | 4× MSAA on the composer target | WebGL2 hardware AA, cheaper and cleaner than SMAA pass; brief's SMAA goal is "clean edges" |
| 10 | Terrain height undulation | Skipped | Hardscape overlays (apron/street/paths/river) sit at fixed y — displacement would make them float/clip; tiling breakup handled by macro-noise + blades + litter |
| 11 | Blob contact shadows under trees | Skipped | GTAO + working 2048 px shadows already ground objects; blobs would double-darken |
| 12 | Idle camera drift vs "interactions untouched" | Bounded breathing delta (±5 cm); autoRotate semantics left exactly as before | Satisfies "subtle life" without changing control behavior |
| 13 | Wind on leaf shadow (customDepthMaterial) | Skipped | Leaf shadows are soft blobs; a swaying depth variant costs a shader permutation for an imperceptible effect |
| 14 | Old `window.__*` scene globals | Replaced by module consts + one documented `window.__kommilo3d` handle | Same-module communication needs no globals; a single tuning handle is the owner's requested tuning table |
| 15 | CDN photo-texture swap (grass/wood) kept? | Kept, now syncs normal-map repeats | Production users can reach jsdelivr; canvas fallback covers failure |
| 16 | 60 fps on mid-range laptops — verification limit | **Gap, recorded:** this sandbox only has SwiftShader software GL (~1 fps), so real-GPU fps could not be measured in-session | Mitigated with measured draw-call accounting (high ≈5.4k calls, low ≈2.7k), adaptive tiers, frozen matrices, zero per-frame allocations |
| 17 | Fog implemented in Phase A instead of B | applyMode/config rewrite owns those lines | Avoids double-editing the same region; phase split is priority order, not a wall |
| 18 | Theme-world scenes (globe/avatar/docs/…) | Untouched except shared renderer exposure differences | They are stylized UI backdrops, not the photoreal campus; kept minimal-risk |

**Dependencies added: none.** (Only `three/addons` modules from the already-used three@0.169.0 CDN package: `Sky`, `GTAOPass`, `ShaderPass`, `VignetteShader`.)

---

## 5. Acceptance criteria — status

| Criterion | Status |
|---|---|
| Side-by-side matches references (light direction, palette, atmosphere) | Met — verified against day/night screenshots; night = blue-hour navy + warm interior (photos 1/4/5), day = soft warm sun (photos 2/3) |
| Objects sit on the ground (AO + shadows) | Met — GTAO + fixed 2048 px sun shadows (verified in screenshots) |
| Distant geometry fades into haze | Met — FogExp2 per mode, city backdrop softens |
| Sun direction consistent (shadows/sky/specular) | Met — single azimuth/elevation source drives light, sky shader and IBL |
| No plastic uniformity | Met — normal maps, roughness variation, per-instance HSL jitter (existing) + macro-noise + translucent leaf backfaces |
| Subtle constant life | Met — wind (per-instance phase), 140 particles, camera breathing |
| Stable 60 fps desktop | **Partially verifiable** — see decision log #16; tiers + measured call counts + no per-frame allocs; real-GPU validation needs the owner's hardware |
| App functionality 100 % untouched | Met — 14-step interaction regression passes; only rendering code changed |

## 6. Files touched

- `index.html` — module script (rendering pipeline) + nothing else in the file
- `docs/3d-overhaul.md` — this document
