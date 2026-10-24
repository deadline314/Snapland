# Character Lighting and Shadow Proxies

ParkWorld keeps its alpha-tested billboards out of shadow maps, then gives the player and three named NPCs a pair of camera-invisible, collision-free shadow volumes: one capsule for the torso and one sphere for the head. Each proxy is parented to its actor root, so NPC routes and the player's ride transform carry it with the character. On foot, its local vertical offset is recomputed from the current ground surface. While riding, the proxy follows the elevated player root instead of leaving a standing silhouette at the ride's ground anchor.

The volumes are deliberately approximate. They cannot reproduce hair, clothing folds, gestures, the seated silhouette, or the exact alpha shape of the source sprite. Native captures should inspect whether their paired shapes read as a plausible character shadow across the four sun phases and at night. Contact ellipses remain a soft, centered foot/AO cue; they no longer pretend to be directional cast shadows.

The custom billboard shader replaces `MODELVIEW_MATRIX`, so it also writes the inverse-transpose normal transform for the replacement basis. Godot's spatial-shader reference documents the vertex built-ins as model-space inputs and exposes `MODELVIEW_NORMAL_MATRIX` as writable; it also notes that `INV_VIEW_MATRIX` refers to the active pass, including a light camera during shadow rendering. See [Godot spatial shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).

At dusk and night, ParkWorld enables up to eight active warm local lamps nearest the player, from a fixed-size candidate buffer, and assigns point shadows to the two nearest active lamps. Selection refreshes at 0.4-second intervals only after the player has moved; phase changes force an immediate refresh. Dawn lights remain unshadowed, noon lights are off, and local lamp energy does not flicker. This bounds point-shadow work but does not prove a frame-rate improvement. The existing directional sun continues to cast the island's broad shadows.

## Verification

`godot --headless --path . --script game/tests/test_daylight_lighting.gd` checks the downward key ray, four centered contact cues, four attached shadow-only actor proxies without collision geometry, the eight-lamp cap, nearest-lamp selection, two point-shadow slots at dusk/night, no noon point shadows, the billboards' disabled shadow casting, and the cached contact material. Native review is still needed to judge the proxy shapes and real shadow appearance on the ground and across character surfaces.


## Alpha silhouette feasibility review (2026-10-24)

`game/tests/native_actor_alpha_shadow_review.gd` is a separate GPU fixture, not
an island rendering change. Run the pinned engine with `--audio-driver Dummy
--rendering-method gl_compatibility --resolution 1280x720 --script
res://game/tests/native_actor_alpha_shadow_review.gd`, an actual display, an
absolute isolated `SNAPLAND_SAVE_PATH`, and a finite external timeout. Capture
files and the JSON sample report go beside that save. Never import the whole
working root just to run this review; use an owned clean validation project.

An L-shaped 32×32 alpha texture on a camera-oriented, non-billboard quad uses
alpha scissor 0.5, nearest filtering, disabled culling and SHADOWS_ONLY. The
expected floor positions are independently projected from source pixel centers
along each light ray. The baseline **hides** the caster: switching cast mode
OFF would draw the card in the baseline and invalidate the comparison.

With a 4096 directional atlas, 24m camera far plane and 20m directional shadow
range, both front/back directional lights and an OmniLight preserved all 13
opaque and 32 transparent interior samples. An intentionally opaque card lost
all 32 transparent samples and was rejected. An explicit 256 atlas run also
failed as expected; a previous wide/default-atlas run failed directional samples
while its point-light samples passed. These conditions changed jointly; the
experiment does not isolate a single cause or establish the island's required
atlas size. Raising a global atlas unconditionally would carry a memory cost.
The island still uses its original approximate volumes and light budget.

Actual character poses, ViewportTexture hair, atlas regions, clothes, rides,
animated shadow invalidation, full-island phases and release rendering must be
checked before adopting this approach. An alpha-L success is no character
animation, packaged-build, frame-rate or full ART-1 acceptance.

References read: [SpriteBase3D alpha cut and billboard caveats](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html),
[GeometryInstance3D shadow-only mode](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html),
[shader pass matrices](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).
