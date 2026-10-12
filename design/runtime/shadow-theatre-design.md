# SG-24 shadow theatre: geometry and presentation

## Player experience

The player operates a brass point lamp on a miniature harbor-side paper theatre. The folded wooden stage, paper mascot, and marked wall remain fixed. The lamp moves horizontally and toward or away from the puppet. Its real cast shadow changes position and scale on the rear wall. The player compares that shadow with a printed outline and presses Space or the shutter to take a plate. Each plate records the actual geometric error; an incorrect plate is a miss.

Three rounds use distinct lamp solutions and increasingly tight ordinary tolerances (0.135, 0.112, and 0.090 projected units). Ordinary play succeeds with at least two qualifying plates. The devil result requires all three precision plates, no misses, and no assistance. Assistance widens the geometric tolerance while retaining actual lamp movement and shutter input. A 60-second clock, bounded frame step, retry reset, invalid-number rejection, and timeout failure keep the run deterministic.

## Projection contract

Use world coordinates with X horizontal, Y vertical, and Z increasing from lamp to puppet to wall. The cutout vertices are fixed on the puppet's XY plane at `puppet_z`; the wall lies at `wall_z`; the lamp is a finite point `(x, y, z)` with `lamp.z < puppet_z < wall_z`. For each puppet vertex `p`, compute the wall intersection of the ray from lamp `l` through `p`:

` t = (wall_z - l.z) / (p.z - l.z)`

` projected = l.xy + (p.xy - l.xy) * t`

The puppet mesh's light-facing front face and Godot SpotLight3D use the same fixed cutout and moving lamp. The extruded prop is centered 0.045 units toward the wall, so its light-facing face sits exactly on `puppet_z`; every round's target outline is calculated from the same equation at its authored solution lamp position. The visible emitter mesh occupies the exact same world position as the actual SpotLight3D. The wall outline is a static double-ink registration mark, not a second movable shadow. The model caches target and current cast vertices and their stable snapshot dictionary; only a lamp update or round transition recalculates the bounded vertex set.

The view builds its finite geometry at initialization: a subtly fibred cardboard mascot with shadow-neutral ink details and separately colored deck boots, grooved and grained timber frame, folded sea-glass curtain wings, brass rails and stand, a luminous glass emitter, one shadow-casting SpotLight3D, and a double-width target print for each round. Four restrained ambient fills lift dawn, noon, dusk, and night materials while the single brass point source remains the only shadow-casting light. Night uses a lighter blue-green environment fill so the parchment, timber, folds, and mascot retain separate values without emissive fake highlights or a second shadow. Per-frame presentation updates only lamp/light transforms, palette, and visibility. The marker vertices come from the model's target projection. The 3D shadow itself remains the renderer's result, so geometry, lamp distance, and shadow direction stay causally connected. A small SpotLight3D source size softens the penumbra while low shadow bias keeps the physical edge close to the paper cutout.

## Controls, scoring, and safeguards

- Left/right or A/D moves lamp X; up/down or W/S moves lamp distance. The view emits a two-axis continuous control request and a shutter request; Space and the raised brass `定影` button share that same request, while other playfield clicks move the lamp. Session remains the input owner.
- A held pointer moves the lamp in X and lamp distance through `screen_to_design()` and `setlamp_target()`.
- `setlamp_target(Vector2(x, z))` clamps finite coordinates to the authored rail. `continuous_axis(x_axis, depth_axis, delta)` clamps axes, delta, and the resulting position.
- A shutter grades every corresponding outline vertex against the target vertices. Round tolerances tighten from 0.135 to 0.112 to 0.090 projected units; a stricter threshold earns the precision plate. Assisted play widens both thresholds but does not move the lamp or record a plate on the player's behalf.
- A shutter outside the ordinary threshold records a miss and advances the round. Completion requires two qualifying plates. A timeout before all rounds are resolved is a failure. Retry rebuilds the round ledger, timer, and starting lamp position.
- Non-finite positions and deltas are ignored; a near-zero lamp-to-puppet denominator yields non-finite vertices, which are graded at maximum error and cannot qualify a plate.

## Presentation and safe area

The composition is a close, fixed three-quarter miniature theatre, distinct from the other welcome games' side-view portrait cards, flat top-down crossing plan, kite plane, and fountain portrait. The stage uses dark harbor ink, sea-glass teal, warm paper, ochre wood, and small coral accents. The puppet is a flat hand-cut prop, not a new reusable NPC. Four time phases change the environment ambient fill and lamp color while preserving shadow contrast. The camera frames the entire playfield below the shared HUD: output is 1280×720, with interactive stage geometry contained in design Y 136–684. The marker, cast puppet, lamp rail, and camera's full projected stage bounds are exposed for integration checks. HUD-safe Y is 0–130. The camera views the stage from negative Z toward positive Z, so the nameplate's `Label3D` rotates its local +Z front toward negative Z; this prevents the back-facing mirrored lettering visible in the first native capture.

## Research actually reviewed

The following first-party references and local captures were read or inspected for this direction. The cited games inform framing, control clarity, scale, or causal feedback; none is a request to copy their art or mechanics.

1. Nintendo, [WarioWare: Get It Together!](https://www.nintendo.com/us/store/products/warioware-get-it-together-switch/) — official description of short microgames and distinct character abilities. Adopted: compose framing around the action verb.
2. Nintendo, [Super Mario Party Jamboree minigames](https://www.nintendo.com/ph/switch/a7hl/minigame/index.html) — official game descriptions and the local ART-21 page capture. Adopted: make spatial roles and alignment legible at a glance.
3. Nintendo, [Mario Party Superstars 1-vs-3 minigames](https://mariopartysuperstars.nintendo.com/minigames/1-vs-3/) — official list of different minigame verbs; page text was available in search results, while the direct page timed out. Adopted only the high-level point that play staging should teach a game's role.
4. Annapurna Interactive, [Donut County](https://annapurnainteractive.com/games/donut-county) — publisher description of a physics puzzle whose central rule reshapes the scene. Adopted: let the actual object relationship create the main spectacle.
5. Panic / Playdate Catalog, [b360](https://play.date/games/b360/) — official control and rotational brick-breaking description; local ART-21 capture visually inspected. Adopted: give a signature control a visible motion path.
6. Enhance, [Lumines Arise](https://lumines.game/) — official description of a beat-swept board; local ART-21 capture visually inspected. Adopted: reserve clear space for target and score information.
7. Drool, [Thumper](https://thumpergame.com/) — creator description and local ART-21 image inspected. Adopted: choose camera intimacy to fit the action; rejected its aggressive palette and speed.
8. Lucas Pope, [Return of the Obra Dinn prerelease notes](https://obradinn.com/media/prerelease.html) — creator notes on fixed display modes; local ART-21 image inspected. Adopted: keep the important silhouette readable against a stable display field.
9. Godot Engine 4.7, [3D lights and shadows](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html) — read the Omni and Spot sections. Adopted: use one narrow-angle SpotLight3D to keep a genuine shadow and avoid the larger cost of multiple omni shadow maps.
10. Godot Engine 4.7, [Light3D class](https://docs.godotengine.org/en/4.7/classes/class_light3d.html) — read shadow enable, bias, opacity, and blur properties. Adopted: enable a single visible real-time shadow and keep blur close to default so the outline stays measurable.
11. Godot Engine 4.7, [Introduction to 3D](https://docs.godotengine.org/en/4.7/tutorials/3d/introduction_to_3d.html) — read the Camera3D, SubViewport camera ownership, and ambient light sections. Adopted: give the mini-theatre its own Camera3D inside its SubViewport and control fill light through WorldEnvironment.
12. Godot Engine 4.7, [Basis class](https://docs.godotengine.org/en/4.7/classes/class_basis.html) — read the coordinate convention. Adopted: use Godot's +X right, +Y up, and +Z back convention explicitly when aiming the camera and lamp.

The local [ART-21 visual diversity review](../../design/runtime/minigame-visual-diversity-review.md) records six inspected official game captures: *Super Mario Party Jamboree*, *b360*, *Return of the Obra Dinn*, *Thumper*, *Donut County*, and *Lumines Arise*. Its image exhibits are in `../../pm/Snapland-art/images/`. The local [minigame presentation diversity survey](../../design/runtime/minigame-diversity-survey.md) also records the inspected official source text and evidence limits. No game was played for this task; these sources support design direction, not runtime claims.

## Integration API

`ShadowTheatreModel` owns round state and exposes `reset(assisted, time_of_day)`, `continuous_axis(horizontal, depth, delta)`, `setlamp_target(Vector2(x, z))`, `step(delta)`, `capture()`, `snapshot()`, `projection_for(lamp_position, puppet_vertices)`, and `round_solution(round_index)`. Snapshot keys include `lamp_position`, `cast_vertices`, `target_vertices`, `shape_error`, `round`, `rounds`, `qualified_count`, `misses`, `time_left`, `score`, `assisted`, `finished`, `success`, and `devil`.

`ShadowTheatreView` emits `axis_requested(horizontal, depth)`, `lamp_target_requested(target)`, and `shutter_requested`. Integration calls `present_state(snapshot, time_phase, reduced_motion)`, reads `texture()` for the mini-theatre surface, uses `shutter_button()` for the mouse control, and maps pointer coordinates with `screen_to_design(screen_position)`. `playfield_rect()`, `hud_safe_rect()`, `geometry_bounds()`, and `projected_geometry_bounds()` expose safe framing. The view owns no gameplay score or result state.

鍵盤移燈提供 Shift 細調：按住 Shift 配合方向鍵／WASD 時，水平與深度軸均以普通速度的四分之一移動；放開後回復普通速度。這讓玩家在第三輪的小誤差門檻前逐步微調，同時保留原本的投影幾何、精準門檻及依實際誤差給分。它不會吸附到目標位置，也不代替玩家定影。

物理投影渲染採獨立 `own_world_3d`，避免共用園區的環境光與燈；位置光影圖固定 2048、僅一個分區配置單張 1024 shadow map。紙面維持不透明逐像素光照並接收影子，環境填光限制在 0.32–0.38，SpotLight 能量 1.6，保留紙色與投影的明暗差而不把角色過曝成白色。反射罩的封閉裝飾端蓋不參與投影遮擋，紙偶仍是原本的雙面立體 caster，幾何／判定／分數沒有改。這依 [Godot Viewports 官方說明](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html) 與 [BaseMaterial3D 陰影及環境光旗標](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html) 配置；引擎實測原本 atlas 為 2048，問題不應歸因為 atlas 是 0。

劇場使用固定 50 度斜視、5.60 高度的正交鏡頭，透過真正的前後景視差，把前景完整紙偶與燈座和後方較大的投影分開；光源、紙偶、牆面座標及模型射線都不動。紙偶是唯一可投影的立體物件，紙面、裝飾框、布簾、木甲板與燈座都只接收光、不投影，避免自我遮蔽的斜紋與無關的裝飾影子干擾判讀。

## Root v6 實際觀察紀錄

Root 已在隔離存檔的視窗環境執行：正常速度 438 幀／7.3 秒、四分之一速度 1368 幀／22.8 秒，兩者原生輸入與 ledger 檢查結束為 exit 0。Root 檢視第 3 輪投影、慢速正式結果 1326 分，以及正常私人回合 500→1000 分的影形移動與慢速正式回合 0→422 分的接近印記過程；基本物理投影已可辨，完整美術仍待後續檢視。

009 圖文教學的三張圖片直接使用目前四分之一速度 v6 的第 1／3 輪定影前截圖與正式結果 1326 分截圖，PNG 位元組未修改；標題、替代文字與 Shift 細調說明由既有教學文字欄位呈現。這些證據只記錄上述遊玩和物理投影觀察，不代表已驗完整教學導覽、離開路徑或全面美術。
