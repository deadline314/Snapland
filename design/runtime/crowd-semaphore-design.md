# Crowd Traffic: harbor semaphore miniature

## Visual intent

Crowd Traffic is a small raised 3D harbor crossing viewed from a steady, slightly overhead orthographic camera. Its visual verb is **release a waiting queue through a physical signal gate**. The crossing occupies a limited viewport between the shared HUD bands; two flat, high-contrast lane cards stay at the established horizontal and vertical pointer centers. Four stone-and-timber quay pads, intersecting asphalt lanes, raised zebra bars, brass mooring rings, timber joints, two semaphore heads, and paired gate arms give the decision an immediate spatial read.

The design is intentionally different from Fountain Jump's hero-centered 3D court and Shadow Theatre's dark projection wall. It has no central hero/avatar. The crossing is a legible traffic instrument, with only six prebuilt crowd-group tokens. Guests wait at their model-selected queue positions. Only `snapshot.active` travels, and its route position is a direct function of the model's `active_progress`. A rescue group has a stretcher and coral signal pennant so its additional importance reads by shape as well as color; it is the existing fourth group, not a claim of a new NPC cast.

## Snapshot mapping

`CrowdSemaphoreView.present_traffic(snapshot, elapsed, reduced_motion, time_phase)` reads the existing `CrowdTrafficModel` snapshot. A `walk` phase raises only the physical gate for `signal_lane`; `clearance` marks and begins lowering that lane; `red` and `all_red` keep the approaches closed. The three lenses, clear queue count, and patience strip make empty and urgent lanes readable without relying on sound or color alone. Four fixed light profiles recolor the same stage at dawn, noon, dusk, and night.

Reduced motion keeps the same controls, signal and lane lights, guest grouping, progress, queue position, and gate feedback. It quantizes the active token to nearby route markers and removes any need for a continuously animated ornament. There is no independent presenter clock or invented score. Geometry and material resources are built once; presentation updates reuse the camera, viewport, fixed token pool, mesh instances, and cached materials. The presenter retains no snapshot dictionary reference.

The control surface exposes `signal_lane_at(point)` and `signal_control_centres()` at `(520, 235)` and `(760, 235)`, preserving the existing canonical pointer mapping. It emits `signal_requested(lane)` from the live GUI click path; Session connects that signal to the existing model request path. The signal toast is anchored in a dedicated bottom HUD band and measured against the projected stage and both lane cards. The active scene remains within the 1280×720 HUD-safe frame (`x=80..1200`, `y=160..615`). `projected_content_bounds()` measures visible transformed mesh AABB corners through the live camera rather than estimating from scene constants.

## Read and design method

I reused, rather than repeated, the prior source review. It actually read the official descriptions for WarioWare: Get It Together!, Mario Party Superstars' minigame index, Panic's Playdate entry for *b360*, Annapurna's *Donut County*, Drool's *Thumper*, Enhance's *Lumines Arise* and accessibility page, Lucas Pope's *Return of the Obra Dinn* notes, House House's *Untitled Goose Game*, and Lucas Pope's *Mars After Midnight*. Six ART-21 reference images and their matching first-party pages were also opened and inspected in that earlier review. The sources were used for general principles—clear roles, a physical rule that creates feedback, motion tied to the verb, and stable reduced-motion alternatives—not for copied compositions or props. The cited games were not played as part of this work.

The presenter uses actual source-level methods from the neighboring 3D implementations: `BalloonHarborView.texture()` / `projected_bounds()` for a bounded viewport, `FountainJumpView.get_texture()` / `projected_content_bounds()` for camera-measured stage bounds, and `ShadowTheatreView.sub_viewport()` / `camera()` for viewport isolation. These are implementation comparisons, not evidence of an in-game visual acceptance pass. Native GPU review remains with the parent task.

## Verification scope

`game/tests/test_crowd_semaphore_view.gd` runs headlessly against the real `CrowdTrafficModel`. It checks the 3D viewport and fixed pointer mapping, real red/walk/clearance gate states, active versus stationary queue movement, the actual arriving rescue group, nonzero dawn/dusk/night lighting, projected bounds, stable node-pool size, and safe malformed-snapshot behavior. It does not claim visual quality or native GPU acceptance.
