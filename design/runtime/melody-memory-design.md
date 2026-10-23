# Melody Memory: runtime design and research

Research date: 2026-10-12. This is a written-source and still-image review. I did not play the cited games, watch trailers, or treat source-page screenshots as evidence of a play test.

## Runtime design

Melody Memory is a two-dimensional close-up of a hand-cranked seaside music box. The camera looks across a joined harbor workbench, with a perforated paper roll held in a small wood-and-brass case above four large playable objects. The set uses different materials and silhouettes: a fan-ribbed shell reed, a flared glass tide bell, a rectangular driftwood block and a laced harbor drum. The composition has no character stage, flower pads, shared backdrop card or scrolling lane. A paper ribbon shows note height and the short/long spacing while the phrase is being played; it clears before the player's turn. During play, the player hears and reads the phrase, then reproduces it with primary keys 1–4, secondary A/S/D/F, or pointer taps.

Three authored phrases contain 3, 5 and 7 notes. They use repeated notes, short gaps and held gaps, so the task requires remembering pitch and rhythm rather than responding to a random sequence of identical beats. The phrases remain constant across retries, which lets the player learn the musical shape. The model begins by playing phrase one; after the final cue there is a 1.15-second quiet read pause before input. A wrong instrument gives feedback, pauses, then replays the same phrase from its first note. A correct note at an imperfect time still advances and earns ordinary progress; it receives a lower score and loses perfect-phrase status. A note outside the broad ±0.70-second acceptance window is still accepted if its instrument is right and is graded as an error. Each phrase allows two manual replays before its first attempt. There is no timer or unattended success. The four primary controls are keys 1–4, with A/S/D/F as a secondary keyboard mapping, or pointer taps.

Ordinary completion requires all three phrases to be performed. The devil result requires all notes to be correct and within the ±0.22-second precise window, zero timing or pitch errors, and an unassisted run. Assistance keeps the same note content, read pause and completion goal while widening the forgiving timing window from ±0.70 to ±1.00 seconds. Each phrase permits two manual replays. A short debounce ignores simultaneous/chorded second key presses without starting another note. Reduced motion removes decorative movement only: the active instrument remains plainly highlighted and the punched-note rhythm remains static and readable. The note sound and highlight use the same monotonic `note_start_serial` event. The session/audio owner should consume each new serial exactly once and map `current_cue` to the existing `assets/audio/note_0..3.wav`; the model and view never own or load audio.

The API is `reset(assisted, time_phase)`, `step(delta)`, `play_note(index)`, `replay_phrase()` and `snapshot()`. `snapshot()` reuses one dictionary and its nested arrays. `heard_notes` is populated during the listen phase and cleared for the active attempt. `cue_index`, `current_cue`, and `note_start_serial` expose the cue event without giving the answer away during play. `MelodyMemoryView` exposes `note_requested(index)` and `replay_requested` pointer signals; keyboard mapping is handled by the caller. It also exposes safe rectangles, shape names, actual visible-artwork bounds and atlas-content bounds for layout tests. At startup, `ResourceLoader` resolves the imported `Texture2D` and caches four `AtlasTexture` quadrants sharing that imported resource. Nearest filtering and complete 627×627 regions preserve each cell without per-frame image creation, file loading or alpha reads. This uses the normal Godot editor/export import remap. If the imported resource is missing or invalid, one warning names its exact `res://` path and the view uses its procedural instrument drawings. The fallback drawings also have bounded, measured shadow and shape extents. The session consumes each new `note_start_serial` once and routes notes through the existing audio assets; the model and view own no audio. Practice preserves the same musical rules but does not change formal collections or progression.

## Primary sources actually read

1. **Milton Bradley / Hasbro, [Simon (1978) official manual](https://www.hasbro.com/common/documents/3f4e2ca0206011ddbd0b0800200c9a66/620962835056900B10D1688756D7BA4A.pdf).** The manual describes repeating growing random signals and offers 8, 14, 20 or 31-sequence skill levels; its instructions also end a sequence when the player waits more than five seconds. I used it to compare the classic growing-sequence structure, while choosing authored melodic/rhythmic phrases and no punitive short deadline.
2. **Hasbro Games, [Simon product instructions](https://instructions.hasbro.com/en-us/instruction/simon-game).** The current product page describes four light/sound pads, repeat-the-pattern play, longer sequences and solo or group play. This supports keeping audio and visible instrument identity paired, but the fixed phrase design intentionally provides a learnable musical composition rather than random length growth.
3. **Nintendo, [Rhythm Heaven Groove official product page](https://www.nintendo.com/en-ca/store/products/rhythm-heaven-groove-125680/).** The publisher page describes following rhythm and a single-player mode using rhythm-based spells. I used that narrow written description to keep the performance prompt focused on reproducing a beat. I did not infer timing feel or visual staging from videos.
4. **Enhance, [Lumines Arise game and accessibility page](https://lumines.game/about-the-game/).** Its accessibility section says players can reduce some effects and motion to make the playfield more readable, and it describes an optional No-Stress rule adjustment. I used this as support for making reduced motion a full-clarity display mode and keeping assistance separate from perfect-run eligibility.
5. **W3C WAI, [Understanding WCAG 2.3.3: Animation from Interactions](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions).** The criterion says non-essential interaction-triggered animation can be disabled; the explanation distinguishes essential information from unnecessary motion. I kept the sound-note mapping, current cue and rhythm marks visible in static form.
6. **Godot Engine, [4.7 input examples](https://docs.godotengine.org/en/4.7/tutorials/inputs/input_examples.html).** The official docs identify mouse button events and their position/button fields. The view uses one down-event hit test in design coordinates, while the root owns the A/S/D/F mapping and model calls.
7. **Godot Engine, [4.7 CanvasItem drawing API](https://docs.godotengine.org/en/4.7/classes/class_canvasitem.html).** The drawing reference documents the primitive-based 2D draw calls used for the shell ribs, bell silhouette, wood grain, drum lacing and paper roll. This keeps the stage asset-free and geometry-testable.

These are primary publisher, standards-body and engine-documentation sources. They informed rule and legibility choices; this implementation does not claim to recreate their art or establish how their games feel in play.

## ART-21 still images inspected

I opened the six local ART-21 reference images at their supplied resolution with `view_image` on 2026-10-12. Observations below are limited to visible still content and do not claim motion or play experience.

- `ART-21-ref-mario-party.png`: the page capture shows four small Camera-Ready frames with reticles, timers and scores around a sample photo. I retained the idea of separating interaction focus from edge information, not its multi-view layout.
- `ART-21-ref-b360.png`: a white-on-black pixel playfield sits beside a narrow status rail. I retained the clean split between action and state, while scaling every instrument and label for the 1280×720 Snapland frame.
- `ART-21-ref-obra-dinn.png`: the still uses hard-edged ship geometry and strong light/dark separation for close observation. I retained clear silhouette/value separation, not its dithering or monochrome treatment.
- `ART-21-ref-thumper.png`: a low foreground beetle sits against a bright vanishing point and long track lines. I did not use forward motion or speed effects; the fixed music roll instead makes note order spatially legible.
- `ART-21-ref-donut-play.jpg`: a central dark hole and tilted building make the physical rule dominate the composition. This supported making the music box and instruments the scene, rather than placing four generic targets on a backdrop.
- `ART-21-ref-lumines-play.jpg`: the central square board remains distinct from a right-side score rail amid dense signage. I retained board/status separation and rejected dense light clutter around the smaller rhythm marks.

## Why this direction is original to Snapland

The reference sources describe repeatable patterns, rhythm play, reduced-effects options, and different ways to frame a playfield. None presents this exact combination of authored 3/5/7 seaside phrases, short/held pitch intervals, an unspooling perforated music roll, hand-crank framing, and four materially different physical instruments. The design applies the sources' broad information principles to Snapland's harbor materials and keeps the musical content, silhouettes, rhythm notation, scoring and stage composition original.

The supplied `assets/minigames/props/melody-instruments-v2.png` atlas was made with the built-in image-generation tool and inspected as a still image. Root performed a separate alpha-threshold QA (alpha ≥64) on the four cells: shell (121,95)–(559,598), bell (152,97)–(466,608), slit drum (99,126)–(617,534), and hand drum (130,69)–(511,522). Each complete cell is cached and rendered at a consistent square scale; the testable alpha-content bounds are mapped into design coordinates and checked to clear the key plaques. This is asset inspection and geometric QA, not native GPU screenshot validation.

## Validation boundary

Headless tests cover finite phases, phrase completion, wrong-note retry, late-note grading, replay limits, cache reuse, cue serials, imported atlas regions, measured artwork bounds, reduced-motion cues and the game-012 session/model boundary. The native review fixture at `game/tests/native_melody_memory_review.tscn` launches through Main's actual game-012 station, then drives observed cues with key or pointer input and verifies pause/retry and non-collecting practice. Pause and retry evidence is latched synchronously from the real button `pressed` callbacks, after the session's own handlers; this avoids comparing against a pre-pause sample or assuming the first cue has not started before a retry click completes. Finished results are accepted only with the matching session instance ID, with result/model/ledger data copied during the synchronous signal before Main frees the session. The formal fixture captures bounded listen, active, and result frames; when movie recording is enabled it forces rendering during waits, and pointer completion still requires the matching natural result latch after Main frees the session. It is authored but has not been run in this subtask; a native fixture does not establish human listening quality or audio timbre, which require a separate real-device review.

原生 fixture 的所有輪詢期限依 `Engine.time_scale` 換算牆鐘時間：`遊戲秒數 / max(time_scale, 0.05)`，並設一小時上限及整段 180 遊戲秒的有限 watchdog。四分之一速度時每回合 55 秒的解題額度為 220 牆鐘秒，整段 watchdog 為 720 牆鐘秒；這只調整 QA 等待期限，原生操作、音符判定、精確分數與暫停／重試／結果驗收不變。

### Root native checkpoint, 2026-10-12

The Main fixture was run on the local GPU at 1.0 and 0.25 engine time scale, with separate isolated saves. Both runs passed natural keyboard formal completion (300 points and ordinary/devil photos), actual pause/resume/confirmed retry, then assisted reduced-motion pointer practice (300 points). The private-practice comparison covers photos, achievements, quests, pending platform achievements, wardrobe reward records and coins. Normal footage is 2848/60 = 47.47 seconds; quarter-speed footage is 11254/60 = 187.57 seconds. Root viewed the normal performance and final result, and the quarter-speed second phrase and final result in the local video player. This is visual/native-input validation; it does not establish human listening quality or a full first-time lesson/leave/reentry flow.

The lesson's listening and performing screenshots are unmodified frames at seconds 16 and 11 of the normal native movie. The first captures real punched notes and the lit wood instrument; the second shows the player-turn prompt after the music roll has cleared. The third lesson image is the actual formal 300-point result. Root reran the exact checkpoint's Session (53 cases), model (35), view (48), tutorial-panel and 13-lesson/39-step screenshot/control preflight checks after replacing these images; all passed with no script/parse errors. The earlier tutorial preflight stall was not used as a passing result.


### 2026-10-20 Score explanation correction

The live session result still described the retired +25-per-note/+100-per-phrase rule while the model and successful native play awarded precise +20 / close +12. Session now formats the explanation from the same two model constants used by accepted note inputs. No scoring/timing/qualification change. The model suite also compares advertised numeric grades and public summary total against actual precise/close note inputs (39 checks total); existing view/Session lifecycle coverage passes 54 checks. Actual mouse opening at 800×600 and 1280×720 is rendered and inspected; this is not an audio review. Full welcome-game integration hit its existing 90-second limit and is being measured separately under MAIN-2, not waived.

## 2026-10-23：示範／記住／演奏／合奏與樂器音色（SG-27）

### 問題

四件樂器共用四個純正弦音，聽不出貝殼簧片、玻璃潮鈴、漂木音板與小港鼓的差別；完成一句只有文字，沒有音樂回饋；記住階段紙帶清空卻沒有說明要記幾個音；結算只有一列「演奏音符得分」。

### 改動

- **樂器音色**：保留原四個音高（C5、E5、G5、C6），改為遊戲自有合成音色：簧片撥奏、玻璃鐘的非整數泛音、漂木的短木質音加槌擊聲、小港鼓的鼓皮下滑音與拍擊聲；只在遊戲內播放，跟隨音效音量與暫停。
- **四段指示**：紙帶上方「1 示範／2 記住／3 演奏／4 合奏」標出目前階段；記住與演奏時紙帶顯示該句音數的問號格，已演奏的格子點亮。
- **合奏回放與終曲**：第一、二句完成後，四件樂器以原節奏合奏回放剛完成的樂句（加上和聲），再示範下一句；第三句完成後播放終曲合奏與收尾和弦，再進結算。終曲中輸入不計分。
- **結算**：每句一列分數，資格說明列出本次精準音數與失誤。

### 來源

沿用本文件前段已讀的官方 Simon 規則、Nintendo Rhythm Heaven、Enhance Lumines、W3C 動態可及性與 Godot 文件，以及六張跨方向官方圖例。本輪另讀 Nintendo《Rhythm Heaven Groove》商店頁（「聽拍子與顯示速度的提示」，採用：示範後才要求輸入）與 Godot 音訊同步文件（同一音訊路徑播放即時音）。沒有試玩上述作品；沒有實際試聽音色。
