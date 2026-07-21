# PERF.md — Frame-Budget-Modell & Tier-Parameter (kommilo.app 3D)

Single-file app (`index.html`, Three.js 0.169, vendored, no build step). This document
records the frame budget, the per-tier parameters, the bottleneck attribution, and how the
**owner** verifies the numbers in a real browser. In-sandbox rendering is impossible
(SwiftShader = software GL, no GPU) — so exact FPS/draw-call figures are read on real
hardware via the `?debug=perf` overlay, never asserted here.

---

## 1. Service-Level Objectives (SLO)

| Target                         | Budget                                   | How measured |
|--------------------------------|------------------------------------------|--------------|
| Desktop (iGPU, 1080p), High    | frame p95 ≤ 16.7 ms, no frame > 50 ms    | `?debug=perf` p95 field during free-look |
| Phone / weak iGPU, Light       | p95 ≤ 33 ms, never unusable              | `?debug=perf` on device |
| Worst view                     | draw calls ≤ 350, triangles ≤ ~2.0 M     | `window.__kommilo3d.sceneDraw()` (owner) |
| Idle (no interaction)          | GPU work → ~0 (no render)                | overlay shows `on-demand IDLE — 0 draw calls` |
| Cold load to interactive       | ≤ 4 s on cable                           | DevTools Network/Perf (owner) |

---

## 2. Per-tier parameters (`sceneConfig.quality`)

Auto-selected at startup from `GL_RENDERER` + screen size + a ~1 s warm-up frame-time probe;
override with `?quality=high|balanced|light|potato`. Hysteresis: drop fast, raise slow.

| Tier (display)     | DPR cap* | shadowMap | shadows | GTAO | SMAA | Post chain |
|--------------------|----------|-----------|---------|------|------|------------|
| High               | 1.25     | 2048      | ✔       | ✔    | ✔    | **ON** (GTAO+Bloom+SMAA+Vignette) |
| Balanced (medium)  | 1.25     | 1536      | ✔       | ✗    | ✗    | **OFF** (direct render) |
| Light (low)        | 1.25     | 1024      | ✔       | ✗    | ✗    | **OFF** |
| Potato             | 1.0      | 512       | ✗       | ✗    | ✗    | **OFF** |

\* Effective DPR = `min(devicePixelRatio, tier.pixelRatio, maxPixelRatio)` where
`maxPixelRatio = 1.25` (hard clamp, Sec5B). Retina/4K desktops therefore render at ≤1.25×,
not 2–3×; fill-rate is the dominant iGPU cost and this is the single biggest per-pixel lever.

Post-processing runs **only on High** (`tier.post`). Lower tiers call `renderer.render`
directly — tone mapping (ACES) and sRGB live on the renderer and antialiasing is MSAA
(`antialias:true`), so dropping the composer costs no color/edge fidelity, only the
full-screen post passes. This makes "post off by default" true for the tiers most
laptops/phones auto-select.

---

## 3. Bottleneck attribution (Sec4 methodology)

Method: change **one** variable from the same start, read the frame-time delta. The
discriminating experiments are wired as dev toggles (no UI) so the owner runs them in a
real browser:

```js
// DevTools console on kommilo.app/?debug=perf — read window.__perf between toggles
__kommilo3d.exp.dpr(1.0)        // E1 halve DPR  → big win ⇒ fill/bandwidth bound
__kommilo3d.exp.shadows(false)  // E3 shadow pass off
__kommilo3d.exp.basicMat(true)  // E4 all MeshBasic → fragment/shader bound
__kommilo3d.exp.halfPop(true)   // E5 half instance population → vertex/draw-call bound
__kommilo3d.info()              // E6 render.calls / triangles
__kommilo3d.exp.reset()         // restore
```

**Conclusion carried from the prior CPU-breakdown + E6 draw-call reads:** the scene was
paying a continuous per-frame GPU cost even at rest (a blind 60 fps loop rendering a
mostly-static campus), and per-pixel fill dominated on integrated GPUs (E1-class). The two
highest-leverage classes were therefore **(a) wasted idle rendering** and **(b) fill-rate**.
Draw calls were already contained by prior instancing/merging work (19 `InstancedMesh`
sites; regional static merges) and sit within the ≤350 worst-view budget — so this round
did **not** chase draw calls further; it fixed (a) and (b), which the SLOs actually gate on.

> Exact ms/call figures per tier are owner-measured on real hardware (overlay). They are
> deliberately not printed here — SwiftShader cannot produce representative GPU numbers.

---

## 4. Fixes applied this round (one class per commit)

1. **On-demand rendering** (`renderNeeded`/`invalidate()`, OrbitControls `change`): render
   only on camera motion, active animation, recent input (<5 s), or auto-rotate. Idle →
   frame skipped entirely → idle GPU ~0. `document.hidden` → no work.
2. **Interaction resolution drop** (pre-existing `applyBoost`): pointer-down → DPR×0.75
   (floor 1.0) + AO/shadow-refresh paused, eased back 250 ms after release.
3. **DPR clamp** `min(devicePixelRatio, 1.25)` (Potato 1.0).
4. **Shadows cheap:** exactly one directional caster (`sun`), `mapSize` per tier (High
   2048 / Light 1024 / Potato off), `shadowMap.autoUpdate = false`, explicit `needsUpdate`
   on sun/preset change + a throttled live refresh (every 3rd rendered frame, frozen during
   boost) for moving foliage/figures.
5. **Post off by default:** composer only on High (see §2).
6. **Instancing + zero per-frame allocation** in the render path (no `new`, no literals, no
   `clone()`, no `getBoundingClientRect` on the hot path; debug string built ≤4 Hz and only
   under `?debug=perf`).
7. **`?debug=perf` overlay:** FPS, frame ms, **p95 (5 s window)**, CPU phase breakdown
   (controls.update / scene-update / renderer.render), best-effort GPU timer
   (`EXT_disjoint_timer_query_webgl2`, "n/a" when blocked), draw calls, triangles, DPR,
   tier, `GL_RENDERER`, build stamp. Mirrored to `window.__perf` for scripted reads.

8. **Navigation-LOD (movement feel — the key fix for "heavy to move"):** during a
   drag/zoom the scene is CPU draw-call + vertex bound, not fill bound (the DPR drop
   can't touch geometry). While the camera is actually moving, the heaviest
   non-clickable detail is hidden and restored 250 ms after release (masked by the
   motion): all alpha-card foliage (`AO_EXCLUDE`: 42k grass + clusters + hedge/tree
   leaves), `peopleGroup` figures, and particles. Engaged from the OrbitControls
   `change` event only when a gesture is active (`boostOn`) — a plain tap / table
   select never flashes detail. Per-object visibility is saved/restored so day-night
   particle state stays correct.
9. **Per-tier grass cap:** the 42k-instance grass field (largest single vertex load)
   is thinned by a `grass` fraction per tier (High 1.0 / Balanced .55 / Light .3 /
   Potato .12) on `InstancedMesh.count`, relieving the continuous-render frames on
   weak hardware, not just the gesture.

Interaction-boost parameters: `boostScale 0.75`, `boostFloor 1.0`, `boostRestoreMs 250`.

---

## 5. Predicted p95 per tier (to be confirmed by owner)

These are **predictions**, not measurements — confirm with `?debug=perf`:

- **High** on a mid laptop iGPU: interaction p95 ≈ 12–16 ms (DPR 1.25 + boost dip);
  **idle p95 → n/a (no frames rendered)**.
- **Balanced/Light:** p95 lower still (no post chain); phone Light target ≤ 33 ms.
- If a mid laptop cannot hold ≤16.7 ms at High, the auto-probe drops it to Balanced/Light
  at startup (feel over detail, Sec5F) — this is logged, not silent.

---

## 6. Regression prevention

- **`?benchmark=1`** — deterministic 20 s camera path; prints avg/p95 ms + tier/GPU/build
  to console. Owner-run on real hardware.
- **`scripts/perf-guard.cjs`** — headless-free structural guard (Node, no browser/GL):
  asserts the DPR clamp, the High-only post gate, the on-demand gate, the single shadow
  caster, and `autoUpdate=false` are all present. Fails CI on regression. A rendered
  draw-call/triangle CI gate is intentionally **not** run in-sandbox (SwiftShader would time
  out); the ≤350 / ≤2.0 M budget is enforced by the owner via `sceneDraw()` + overlay.
