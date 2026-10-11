# Eight-direction authored walk cycles

## Goal

Use eight separately authored views and eight authored frames per view. Keep the existing four-direction idle/action assets and wardrobe overlays compatible. The renderer quantizes actual world travel to one of eight compass sectors and advances the walk cycle by distance, so blocking, frame rate, or a held input cannot make the feet cycle while the avatar is not travelling.

## Reference notes and decisions

1. The University of New Mexico's Animation I walk-cycle lesson divides a step into contact, down, passing, and up, and describes the weight landing at down before the next contact ([lesson](https://swardson.com/unm/animation1/mod13-walkcycle.php)). Adopt: treat an 8-frame cycle as two repetitions of those four landmarks and check frame order around the loop. Reject its 24-fps/three-frame-per-key timing: these authored frames have their own stylized spacing and must follow actual distance travelled.

2. Pixel Joint artist r1k's hand-drawn pixel-art example says to block the two furthest-apart contact poses first, then add the middle poses; it uses eight frames for two steps ([walk-cycle thread](https://pixeljoint.com/forum/forum_posts.asp?PD=0&TID=25020)). Adopt: preserve the artist's eight distinct cels and verify both contact pairs differ. Reject generating intermediate directions by mirroring or rotating a cardinal sprite: that would discard the authored silhouette and camera-facing details.

3. Aseprite's animation guide treats frames, layers, tags, and per-frame duration as editable timeline data, with onion-skin preview for checking adjacent drawings ([animation guide](https://www.aseprite.org/docs/animation)). Adopt: keep frame index and direction as explicit atlas metadata and validate every extracted cel. The atlas is a runtime sprite sheet, so do not require an Aseprite project or runtime timeline.

4. Aseprite tags can play forward, reverse, or ping-pong ([tag guide](https://www.aseprite.org/docs/tags/)). Adopt forward looping because the authored eight frames represent a full alternating two-step gait. Reject ping-pong: it would reverse the contact/down/passing/up order and make a planted foot move backward through its impact.

5. Godot's `SpriteFrames` supports a frame-specific relative duration and explicit linear or ping-pong loops ([SpriteFrames reference](https://docs.godotengine.org/en/4.7/classes/class_spriteframes.html)). Adopt explicit eight-frame loop coverage and test every cel. Reject time-only playback as the locomotion clock: a duration-only clock keeps cycling through wall collisions and while actual travel is zero.

6. Godot `CharacterBody3D` distinguishes requested velocity from real velocity and exposes actual travel with `get_position_delta()` after `move_and_slide()` ([CharacterBody3D reference](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)). Adopt actual horizontal displacement per physics tick as the phase input; ignore vertical grounding motion. This lets a collision pause the gait instead of advancing it from intended input.

7. Godot `AnimationTree` `BlendSpace2D` supports continuous and discrete blending and can carry the current playback position across discrete animation changes ([AnimationTree guide](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)). Adopt the continuity goal—keep the same gait phase when changing direction. Reject visual cross-fading: for hand-drawn full-body pixel art it overlays two viewpoints and creates an un-authored in-between image. Select one nearest 45-degree sector with a small angular hysteresis instead.

## Runtime behavior

- Map the camera-relative world movement vector to eight sectors spaced by 45 degrees. Retain the previous sector until the vector crosses its boundary by a small hysteresis margin; use a deterministic initial sector when movement first starts. Do not derive facing from noisy input when actual travel is blocked.
- Accumulate actual horizontal distance. Convert distance to phase in a full eight-frame loop using an authored stride-distance constant; wrap modulo eight and select an integer frame. Walking stops advancing below a small distance epsilon, but keeps the current direction and phase for the next movement burst.
- Keep idle, action, and walk states separate. Four existing action poses remain available; map an eight-way heading to the closest supported action heading (front/back/left/right), documented and tested. An action temporarily owns the visible pose; distance phase may remain held underneath it.
- Keep palette, hair, hat, and species composition cached. The render cache remains bounded; do not create `Image`/`ImageTexture` objects every physics frame. Warming may be lazy, but every new direction/frame must render from its authored atlas cel.
- Maintain one shared feet baseline across all directions and all eight frames. Atlas metadata is generated from the supplied source sheets; no input art is rotated, cropped by guessed grid cells, or rewritten.

## Current implementation

- `assets/characters/walk-regions.json` selects the front/back, side, front-diagonal, and back-diagonal source sheets. The renderer loads each imported `Texture2D`, validates every region and anchor, clears alpha below 0.4, and fits the cell at a common 444-pixel source scale. It positions pixels with the recorded cell-center and foot anchors on the 280×360 render canvas.
- Idle holds contact cel 0 with both feet grounded for the retained eight-way heading. Walking selects all eight atlas cels. The four existing action poses keep their original front/back/left/right art; diagonal gestures resolve vertically to front or back. Direction-specific diagonal hair and hats load from `assets/characters/diagonal-parts.json`; species details use the nearest authored cardinal part pending dedicated species variants.
- The park updates heading only from post-slide, post-boundary-clamp horizontal displacement. A 5-degree margin holds a heading through small boundary noise. The gait wraps each 2.8 world units of actual travel and the eight-frame phase remains stored while stopped or acting. This keeps requested movement and elapsed time out of the animation clock.
- Walk textures are composed lazily and share the renderer's 128-entry least-recently-used texture cache. Palette edits apply on the fitted source image before the result is cached.

Focused checks: `game/tests/test_avatar.gd` exercises all 64 authored walk cels, directional idle, per-view hair/hat choices, palette/equipment changes, cache bounds, and the four actions. `game/tests/test_avatar_walk.gd` checks all eight heading sectors, boundary hysteresis, distance-phase invariants, a live headless movement tick, and modal blocking. These are headless runtime checks, not a native visual review.

## Validation

The focused headless test will verify all 64 direction/frame cels are non-empty and distinct where authored; all directions preserve the foot baseline; heading quantization covers eight sectors with stable boundaries; equal travel produces equal phase regardless of elapsed-time partitioning; zero/blocked movement holds the current frame; distance wraps after one stride; and appearance/equipment still changes the cached render without exceeding its bound. World integration checks that measured displacement drives the walk phase and the legacy four action poses still resolve. Native/GPU review is separate and will not be claimed as a headless pass.

## Consistency corrections actually reviewed

Root viewed the native eight-heading hair/hat/species galleries and pose grids. The second front-diagonal hair column turned into a strict opposite profile and hid the right-travelling face; runtime composition now mirrors the authored three-quarter component. Per-cel front-diagonal head offsets follow the measured source skin-face centroid so fixed overlays do not cover shifted faces. These are placement corrections, not proof of identical anatomy. The rejected diagonal walk atlas and reason remain in walk-provenance.json. Generation used Codex image_gen, not local ComfyUI. Every accepted direction still requires visual inspection of camera, satchel, cream hair streak, shoes, face and palette through the loop.
