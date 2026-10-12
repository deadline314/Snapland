# Hat rescue catch animation: generation and review record

## Candidate status and provenance

The v3 candidate is **rejected** for face/body/shoe proportion and identity drift versus the approved idle image; it remains preserved as history and is no longer the catch source. The active candidate is `assets/characters/traveller-catch-front-v4.png`, copied from `C:/Users/stanl/.codex/generated_images/01a12b04-74ea-79a2-8750-6c7f7653b695/exec-4cae61ed-e9c2-4b44-a7aa-8030faf37c8a.png`. Both are 1448×1086 RGBA; v4 SHA-256 is `89DE9D7EF8E047420B005779BD5B16090D0EB453C7FAD3C72CDD33DF8981B7F7`. Root generated v4 through the built-in image-generation tool, not ComfyUI. This section's original table records v3's historical bounds only; v4's exact regions and anchors are recorded below. In v13, both normal speed (1,943 frames / 32.3833 s) and quarter speed (7,598 frames / 126.6333 s) passed the native fixture, including all twelve catch and all sixteen directional walk post-draw frames and six-center formal/practice results. Root reviewed both full v13 runs and their catch/walk captures; the default character presentation passed this round's visual review. This does not certify fifty wardrobe silhouettes, the three-NPC scene target, or Park-private exit.

| Frame | Measured alpha bounds | Manifest region `[x,y,w,h]` | Feet anchor |
|---:|---|---|---|
| 0 | `[111,58,307,370)` | `[109,56,200,316]` | `[100,314]` |
| 1 | `[453,58,651,370)` | `[451,56,202,316]` | `[101,314]` |
| 2 | `[801,57,1005,370)` | `[799,55,208,317]` | `[104,315]` |
| 3 | `[1148,58,1383,370)` | `[1146,56,239,316]` | `[120,314]` |
| 4 | `[87,431,319,732)` | `[85,429,236,305]` | `[118,303]` |
| 5 | `[445,429,666,732)` | `[443,427,225,307]` | `[112,305]` |
| 6 | `[788,443,1006,733)` | `[786,441,222,294]` | `[111,292]` |
| 7 | `[1158,443,1370,732)` | `[1156,441,216,293]` | `[108,291]` |
| 8 | `[106,756,304,1059)` | `[104,754,202,307]` | `[101,305]` |
| 9 | `[453,757,649,1059)` | `[451,755,200,306]` | `[100,304]` |
| 10 | `[799,756,997,1060)` | `[797,754,202,308]` | `[101,306]` |
| 11 | `[1161,757,1358,1059)` | `[1159,755,201,306]` | `[100,304]` |

Historically, v3 used head anchors at the top of each cropped cell, feet anchors at `region_height - 2`, and `source_scale=0.656`. Those settings are rejected with the v3 asset. The current v4 manifest uses alpha≥32 primary silhouette bounds with a 2px pad, a common `source_scale=0.602`, and anatomically selected central hair-top anchors that ignore raised hands. All frames still use the traveller's shared `280×360` canvas, `reference_size=[175,220]`, and `feet_baseline=346`; the common scale and shoe contacts preserve actual proportions without independently fitting each pose. Hat Rescue draws the normalized texture into its existing `126×162` character rectangle with its bottom at `y=638`.

| Frame | Primary alpha≥32 bounds `[x0,y0,x1,y1)` | Manifest region `[x,y,w,h]` | Source head anchor | Source feet anchor | Normalized head y |
|---:|---|---|---|---|---:|
| 0 | `[95,54,296,356)` | `[93,52,205,306]` | `[102,9]` | `[102,304]` | 62 |
| 1 | `[439,54,641,356)` | `[437,52,206,306]` | `[103,9]` | `[103,304]` | 62 |
| 2 | `[801,54,1002,356)` | `[799,52,205,306]` | `[102,9]` | `[102,304]` | 63 |
| 3 | `[1151,54,1382,356)` | `[1149,52,235,306]` | `[118,8]` | `[118,304]` | 61 |
| 4 | `[88,408,310,713)` | `[86,406,226,309]` | `[113,8]` | `[113,307]` | 58 |
| 5 | `[434,402,654,713)` | `[432,400,224,315]` | `[112,9]` | `[112,313]` | 54 |
| 6 | `[798,384,1002,713)` | `[796,382,208,333]` | `[104,32]` | `[104,331]` | 58 |
| 7 | `[1161,408,1366,713)` | `[1159,406,209,309]` | `[104,9]` | `[104,307]` | 59 |
| 8 | `[86,739,313,1041)` | `[84,737,231,306]` | `[116,8]` | `[116,304]` | 61 |
| 9 | `[440,739,645,1041)` | `[438,737,209,306]` | `[104,8]` | `[104,304]` | 61 |
| 10 | `[798,742,1000,1041)` | `[796,740,206,303]` | `[103,9]` | `[103,301]` | 65 |
| 11 | `[1162,739,1366,1041)` | `[1160,737,208,306]` | `[104,8]` | `[104,304]` | 61 |

The source head marks are central dark-hair top pixels, independently located inside each body rather than copied from the cell's highest alpha (which can be a raised hand). Feet anchors use the lower edge of the primary α≥32 shoe silhouette. Renderer measurements for all twelve frames keep the normalized feet at `(140,346)` and head anchors between y=54 and y=65; approved idle/front frame 0 is `(143,59)`. The differing arm extents remain visible and are not mistaken for head movement.

The action is registered as `traveller.catch.front` in `assets/characters/complete-animation-regions.json`: 12 frames, 20 fps, non-looping. That is a nominal 0.60-second visual one-shot. The view starts its visual clock on a rising model `catch_pose` and advances that clock only by changes in `snapshot.elapsed`. The actual normal eligibility window remains the model's 0.38 seconds (`ASSIST_CATCH_WINDOW` is 0.58 seconds); the view clock does not affect catch qualification. Because it follows model elapsed, pausing freezes the animation clock. The test checks that a normal model catch window can expire before all twelve visual frames have played, and that the view still reaches every frame.

A retry resets the model's elapsed and catch pose. The view now treats a backwards model elapsed value as a round reset: it clears the active visual one-shot and its elapsed time, and stores the previous catch-pose value as a scalar instead of reading it back from the model's mutable cached snapshot. This prevents an aliased snapshot from hiding a new rising catch pose. A fresh reach then starts at frame 0; the model eligibility window is unchanged. The view test covers a retry during the reach, an idle interval, and a fresh reach. Pausing still freezes the visual timer because elapsed does not advance.

The catch frames are cached when `configure_avatar` refreshes the avatar, not created per rendered frame. The view requests each frame through `AvatarRenderer` with the current appearance and equipment dictionaries. The catch manifest has a single full-body base image per frame and no `variants` or `layers` entries. However, `AvatarRenderer.texture()` still applies its existing appearance pipeline to an authored frame: outfit palette, appearance details, species marks, hair, and the equipped hat overlay. The head anchor from the selected manifest frame positions hair/hat; frame variants can supply their own head/feet anchors. The underlying garment silhouette, printed details and chest camera are baked into the v4 body and cannot change shape via palette alone.

## Native-v5 front-pose comparison

The CPU review sheet `.review/hat-v5-front-idle-reach-return-compare.png` documents why v3 was rejected: actual full-body crops from `.review/sg20-normal-v5.mp4` at 10.00 s (before catch 4), 10.45 s (reach), and 10.70 s (returned/front) compared against the renderer's then-current idle/catch textures. It is a frame extraction and headless renderer comparison, not a new runtime capture. The concrete idle/catch references from that pass are `.review/renderer-idle.png`, `.review/renderer-catch0.png`, and `.review/renderer-catch5.png`; all three were rendered by `AvatarRenderer.texture()` before v4 replaced the manifest entry.

The v4 CPU comparison is `.review/hat-v4-avatar-reference-and-variants.png`, with individual PNGs `.review/idle-approved.png`, `.review/v4-tide-catch0.png`, `.review/v4-tide-catch5.png`, `.review/v4-coral-straw-catch0.png`, and `.review/v4-gold-flower-catch5.png`. The atlas strip is `.review/hat-v4-catch-allframes.png`. These are 280×360 textures produced headlessly by the actual `AvatarRenderer`; the variant renders confirm the existing hair/outfit/hat overlays still compose on catch art. Idle is 199×293 visible pixels, catch frame 0 is 197×295, and catch frame 5 is 216×303 because its hands extend outside the torso silhouette. All catch feet anchors are `(140,346)` and all anatomical head anchors fall from y=54 to y=65, against idle's `(143,59)`. The view tests now protect the shared source scale, head range, baseline, full-canvas clipping and complete twelve-frame cache. Both v13 normal and quarter-speed native logs observed the complete catch sequence: normal movie frames 102–136 and quarter frames 305–438. Root reviewed both full normal- and quarter-speed footage, including catch and walk frames, and accepted the basic default character presentation. Wardrobe variants remain outside this review.

The smallest path to full wardrobe-matched catch art is data-only: author twelve synchronized full-body regions per new outfit silhouette, then add an outfit-keyed `variants` object to each corresponding catch frame with its source, alpha-bounded region, and feet/head anchors. `CharacterAnimationLibrary._frame_for_equipment()` selects that region using the same equipped outfit already passed by the view, and the existing renderer applies appearance/hair/hat treatment afterward. For a detachable item that should not replace the full body, add twelve ordered manifest `layers` entries with source region, canvas-relative offset, `z`, and an `equipped` selector; the animation library composites those parts before the shared-canvas normalization. This keeps every part in the same frame clock without changing `AvatarRenderer` or gameplay code. Each new full-body frame still needs matching timing, body scale and anchors; independently fitted poses would cause visual size/foot jitter. The current v3 source visibly keeps the traveler's chest camera accessory; the hands are empty and are not posed holding it.

## Rejected and provisional iterations

The generated v1 `C:/Users/stanl/.codex/generated_images/01a12b04-74ea-79a2-8750-6c7f7653b695/exec-16833757-1654-4d08-b3bc-136bd8e3eefd.png` and v2 `C:/Users/stanl/.codex/generated_images/01a12b04-74ea-79a2-8750-6c7f7653b695/exec-cdc86e02-75ec-4b2f-972b-d02e1f3b2011.png` sheets were rejected because an extra orange hand appeared around the camera, reading as a phantom third hand. V3 at `C:/Users/stanl/.codex/generated_images/01a12b04-74ea-79a2-8750-6c7f7653b695/exec-131be348-103a-46da-ab3a-68546510fa02.png` removed that artifact, but Root then rejected its face, body and shoe proportions as identity drift from the approved idle. V4 at `C:/Users/stanl/.codex/generated_images/01a12b04-74ea-79a2-8750-6c7f7653b695/exec-4cae61ed-e9c2-4b44-a7aa-8030faf37c8a.png` restores closer face/body proportions and is the current candidate. Each source is 1448×1086 RGBA. In v4, frames 0–1 are the low/anticipation pose, 2–8 lift and extend both hands, and 9–11 bring the arms back down. V13 normal and quarter-speed native captures verified all twelve catch frames and both directional eight-frame walk cycles in the real round; formal and private practice each completed six center catches. Root still needs to review the v13 footage; this does not certify all wardrobe silhouettes, three fully animated NPCs, or park-private exit.

The manifest-driven view test checks twelve non-null cached textures, the declared 20 fps rate, and that every catch index appears while the model is stepped. A separate v13 post-draw observation also captured all twelve catch and all sixteen left/right walk indices during actual input-driven rounds at both speeds. Neither check certifies natural-looking interpolation, every outfit silhouette, or the chest camera's visual fit for all outfits; Root reviewed both v13 runs and accepted the basic default character presentation; outfit-wide silhouette coverage remains unverified. Contact sheets are `pm/Snapland-small-game/images/SG-20-hat-v13-normal-catch-poses-00-11.png`, `...quarter-catch-poses-00-11.png`, and the corresponding normal/quarter `walk-poses-left-right-00-07.png` files. This does not prove every wardrobe silhouette or establish the three-NPC scene target. Root reviewed the actual v13 footage and accepted the basic default presentation; this does not certify all wardrobe silhouettes or the three-NPC scene target.

## Primary-source notes and design decisions

These are notes from the linked official documentation, not claims that the documents were used to create the art.

| Primary source and observed fact | Applied here | Deliberately not copied |
|---|---|---|
| [Godot: 2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html) documents both separate frame images and sprite-sheet frames, and shows frame rate control and code-driven play/stop. | Keep the catch action explicitly named, frame-counted, timed, and one-shot in the existing avatar manifest/view path. | Do not replace the view with a second animation system or change the gameplay eligibility timer to match art duration. |
| [Walt Disney Animation: Animation process](https://www.disneyanimation.com/process/animation/) names timing, clear staging, anticipation, follow-through, and secondary action as principles animators use. | Review the action as a readable low pose → reach → return sequence; verify the interaction remains the first read. | No claim that the generated twelve frames embody or prove a complete set of animation principles. |
| [Spine: Slots](https://us.esotericsoftware.com/spine-slots) explains that attachments are grouped in slots and that draw order controls which attachments appear in front. | Treat accessory overlap and the extra-hand rejection as a layer/occlusion consistency check during source review. | Do not introduce a rig, slots, or inferred accessory layers into the current full-body raster sequence. |
| [Aseprite: Animation](https://www.aseprite.org/docs/animation) describes a timeline for frames/layers/cels, preview, frame tags, and frame-specific durations. | Keep a named twelve-frame action with an explicit non-looping rate and inspect the entire range, not only its first cell. | No assertion that this asset was authored or edited in Aseprite. |
| [Krita: Animation Timeline Docker](https://docs.krita.org/en/reference_manual/dockers/animation_timeline.html) describes a current-time scrubber, playback/frame-rate controls, cached frames, and onion skins for comparing neighboring poses. | The future native review should inspect neighboring poses and playback at ordinary and reduced speed; texture frames stay cached at configuration time. | No claim that Krita or onion-skin tooling was used to produce or certify this image. |
| [OpenAI Academy: Creating images with ChatGPT](https://openai.com/academy/image-generation/) recommends small, specific revisions to preserve consistency while refining an image. | Preserve the iteration record: v1/v2 rejected for a specific hand artifact; v3 rejected for identity drift; v4 remains provisional after measured pose alignment. | Do not treat iterative generation guidance as evidence of frame-to-frame identity or runtime motion quality. |

## Files and review boundary

- Source atlas: `assets/characters/traveller-catch-front-v4.png` and its Godot `.import` sidecar; rejected v3 is retained separately.
- Frame regions: `assets/characters/complete-animation-regions.json`, only the `actors.traveller.catch.front` entry.
- Runtime evidence references: `game/minigames/hat_rescue_view.gd`, `game/tests/test_hat_rescue_view.gd`, and `game/tests/native_hat_rescue_review.gd`.
- Gameplay intent and timing: `design/runtime/hat-rescue-design.md`.

This record documents provenance and current behavior only. V13 normal-speed and quarter-speed native runs both passed, including full catch and walk cycles. Root has reviewed the complete normal- and quarter-speed footage and accepted the basic default presentation. Wardrobe silhouettes, broader NPC population, and Park-private exit are not certified here. Wardrobe silhouettes, broader NPC population, and Park-private exit are not certified here.

## Exact v4 generation prompt

The prompt below is preserved verbatim; reference paths and SHA-256 values are in `.review/hat-v4-actual-prompt.txt`.

```text
Edit the second referenced image (12-pose reach atlas) using the FIRST reference as the strict canonical character model. Preserve the approved in-game traveller's face, body proportions, small shoes, blue-black swept hair with one cream forelock, teal jacket, red cuffs, cream shorts, brown side satchel and red camera. The old atlas is rejected: round eyes, aggressive eyebrows, oversized torso/boots, changing silhouette.
Create one transparent 4-column x 3-row atlas with twelve DISTINCT consecutive poses of a calm overhead hat-catching reach and return, left-to-right then top-to-bottom. Correct identity and proportions, do not redesign. Use the FIRST reference's narrow oval black eyes, modest tiny white glints, gentle expression, exact cream forelock shape and irregular swept blue-black hair silhouette. Avoid the old atlas's round white-rimmed eyes, angry brows, oversized boots and smooth generic cartoon finish. Match fine deliberate pixel clusters and crisp edges of the approved image; no painterly blur, glow, noise or gradients.
SAME scale and floor baseline in every cell. Canonical head/body ratio, shoulder width, torso length, short legs, small shoe dimensions. Hair, face, camera, shorts and boots stay identical through the sequence; only necessary motion changes them. Knees soften slightly in anticipation then straighten on reach. Plausible elbows, equal arm lengths, exactly two hands, five readable fingers per open hand. No extra hands near the camera. Camera hangs against chest on two dark straps throughout, hands do not hold it during reach. Calm same expression, head forward, no eye redesign.
Pose order: 1 hands settle just away from camera; 2 small knee anticipation/elbows begin bending; 3 forearms lift to chest; 4 elbows shoulder height; 5 open hands ear height; 6 reach upward with elbows slightly bent; 7 overhead full extension/open palms; 8 fingers close gently on imaginary hat/elbows soften; 9 elbows lower toward shoulders; 10 forearms toward chest; 11 hands settle beside camera; 12 canonical resting stance. Every consecutive drawing advances by a small readable amount: no duplicate drawings or sudden stretch. Do not draw a hat or action trail.
Transparent RGBA, equal-size 4x3 cells, feet aligned per row, at least 12% clear space around all highest hands/boots. No labels/text/grid/scenery/floor shadows/extra props. Whole body, hair tips, fingers and shoes complete, never touching cell edges.
```
