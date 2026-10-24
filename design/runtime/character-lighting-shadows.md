# Character lighting and projected silhouettes

The player and three named NPCs now cast from the final texture shown by their
Sprite3D. The hero can supply a live hair-rig SubViewportTexture; NPCs supply
their current authored ImageTexture. There is no independent shadow animation
clock, image recentering, body transformation, pixel readback or new collider.
The source sprite retains its existing disabled shadow mode and visible shader.

`actor_shadow_silhouette.gd` owns one camera-invisible, nearest-filtered,
alpha-scissored quad per actor. ParkWorld selects its upright mode: horizontal
orientation follows the **scene** camera, while vertical extent retains the
visible billboard's world Y extent. Keeping the tilted full-camera plane caused
all eight dawn/noon actor attachment checks to fail by 10–12 screen pixels.
The upright cast plane passed the same conditions at approximately 0.1–1.9px.
Visible sprite positions, original art and hair attachment remain unchanged.

The quad samples the source frame/region with its flips. A padded or otherwise
unsupported atlas layout selects the original capsule/sphere fallback instead;
normal current actors enable only the alpha caster. Hidden, detached or freed
sources leave no caster or fallback behind. A missing/detached camera selects
the safe fallback. The final lifecycle contract includes detach/reentry for
both source and camera; the first detached-source attempt left a fallback and
was rejected, corrected and rebuilt before the final ELF smoke.

Do not reuse the visible `living_sprite.gdshader` for shadow billboarding:
Godot's `INV_VIEW_MATRIX` describes the active pass, which is the light camera
during shadows. This caster explicitly uses the owning scene camera and a
standard alpha-scissor material. This also avoids depending on whichever camera
another viewport happens to make current. A live-texture L → full card → L test
keeps the same texture object, caster and light transform, and verifies that
shadow alpha updates instead of retaining a stale snapshot.

The original four soft contact ellipses remain foot/AO cues. Foliage and prop
volumes remain unchanged. The sun's island range and atlas settings also remain
unchanged; ParkWorld still selects at most eight nearby active lamps and two
nearest point-shadow lamps at dusk/night, with no noon point shadows. Higher
atlas resolution in the independent feasibility fixture is a diagnostic
condition, not a production memory or performance claim.

## Current verification (2026-10-24)

The official runner now contains 96 checks, including the new CPU alpha-caster
contract. Thirteen distinct affected local suites passed, including authored
walks, daylight, current NPC activity, sprite clearance, rides, island layout,
coastal/promenade play, Main/story, wardrobe pagination and building occlusion.
The complete Python suite passed 161/161. The preceding production baseline's
full 95-check CI was green; current full CI is reported by its own run after
submission rather than inferred from the local subset.

In actual Main, all 53 existing light/attachment/glow conditions passed without
relaxing their thresholds. Conditions include actors outside selected point
lamp reach; they do not mean every actor was lit by every lamp. A 16-condition
night repeat records the actual reduced-motion flag when capturing its still.
The old fixture restored that flag before its reduced-labelled screenshot;
that still is excluded from accepted reduced-motion evidence and retained as a
negative. Capture names alone are not setting evidence.

The actual World renderer supplied four phases, three authored actions, eight
project input headings and reduced motion, with 16 full-frame captures at each
of Engine.time_scale 1.0 and 0.25. Normal/quarter runs took 42.80/96.41 seconds,
exit 0 and 0 ERROR. The two 1280×720 silent 15fps movies retain all 640/1444
captured frames, were fully decoded, and each had six sampled frames inspected.
They are not continuous human watching, listening or hardware benchmarks.
The 32 state images, 16 Main phase images, four before/after crops, shadow-mask
contact pages and twelve final ELF draw images were inspected. This accepts
island lighting, not the remaining complete character-animation tickets.

The final Linux ELF is 241252096 bytes, SHA256
`14bf913415b2d022abee7d27c569419b17712291abbc9368e34f664c12ea9ca5`.
Its real clean-directory 12-scene startup/draw smoke passed in 27.27 seconds with
0 ERROR and retained saved rainvest, reduced motion and 120 coins. Runtime source
hashes match the final working files. The final export stage was removed only
after this acceptance; the binary, exact sources, build reports and logs remain.
The guarded final source differs from the active-pose review only at detached
source/camera handling; exact earlier source bytes are archived and checked
against the original build manifest. Final guards were separately verified.

[Ticket, pictures, films and replay archives](../../pm/Snapland-art/[ART-1]建立立體像素園區光影.md).
The raw screenshot archives use lossless RGB capture matrices for opaque images;
193 decoded RGBA frames were hash-checked, and an actual 16-frame extraction was
verified. They are storage, **not animation**. Original PNG byte hashes are
recorded; recreated PNG compression can differ while pixels remain identical.
Transparent PNGs retain their original bytes. The replay archive provides
`capture_matrix.py extract MATRIX.zip NEW_DIRECTORY` (ffmpeg and Pillow).

## Historical feasibility work

The following sections record the earlier pre-integration experiment. The
current implementation and acceptance above supersede their production status.

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
At this pre-integration stage, the island still used its original approximate volumes and light budget.

Actual character poses, ViewportTexture hair, atlas regions, clothes, rides,
animated shadow invalidation, full-island phases and release rendering must be
checked before adopting this approach. An alpha-L success is no character
animation, packaged-build, frame-rate or full ART-1 acceptance.

References read: [SpriteBase3D alpha cut and billboard caveats](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html),
[GeometryInstance3D shadow-only mode](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html),
[shader pass matrices](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html).


### Static character source extension

The same fixture also accepts `-- --character` for the current default front
idle cel; add `--rainvest --hat --wave` for the current free vest, straw hat and
front wave **frame zero**. It uses the final static AvatarRenderer composition,
fixed 280×360 canvas, 346 feet baseline and original pixel size. Its independent
alpha samples exclude a four-source-pixel boundary neighborhood; this checks
interior silhouette occupancy, not every hair strand or filtered edge. Neither
body placement nor appearance assets are modified. The source image is saved
with the captures, and JSON rows identify the exact appearance/action/frame.

Both cases passed front/back directional and point lights; all 156/263 opaque
interior samples were shadowed. Transparent agreement was respectively
370/370, 365/370, 370/370 and 254/257, 251/257, 257/257. The unchanged 85% floor
is a coarse diagnostic criterion, not visual acceptance. Solid-card negatives
failed all 370/257 transparent interiors. The L-shape and low-resolution
negative were rerun after this extension. Two full static sources and both
four-image crop contact sheets were actually viewed. This earlier static review remained separate
from production caster adoption and dynamic hair, animation or release review.
