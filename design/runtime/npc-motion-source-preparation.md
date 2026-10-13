# ART-17 NPC motion source preparation

This note records the measured candidate inputs and the current limits of the ART-17 NPC motion work. The turnaround images and their normalized crops are preparation materials, not production-approved walk-cycle art.

## Measured candidate sources

`assets/characters/npc-motion-regions.json` declares only `left` and `right` views for each of the three roles. It normalizes the strongest-alpha character bounds with nearest-neighbour sampling onto a 280×360 canvas, with the soles at row 346. Original PNGs are retained unchanged; the source metadata records matching source and normalized RGB streams, and SHA-256 hashes identify the exact inputs.

| Role | Candidate source | Normalized body height | Approx. source height at configured pixel scale | Input SHA-256 |
| --- | --- | ---: | ---: | --- |
| Ticket attendant | `ticket-turnaround-candidate-v2.png` | 320 px | 2.133 m | `28dc7ba7d57ba447bc72a0ef5fbd44beb6077a43c79f41974635bf7cdcce1798` |
| Imp | `imp-turnaround-candidate-v1.png` | 260 px | 1.733 m | `135842ab8564fc68f0c29ea8224658ca21c7df4eb6320efd1f9b427a017663c0` |
| Announcer | `announcer-turnaround-candidate-v1.png` | 320 px | 2.133 m | `9541a1b771bb9dff8991681fc4e0d5a843f8d1dd0a5b3f7328696a41760e4af9` |

These heights describe the measured normalized candidate bounds, not accepted in-game proportions. The imp is intentionally normalized smaller than the two human roles; use its own measured limb and boot anchors rather than reusing either human role's measurements. The JSON stores per-view hip, ankle, sole, limb-envelope, skin-sample, boot, and garment-guard measurements used by the preparation tests.

The original full prompts were not retained, and the image-generation model identifier is unknown. The available prompt summaries are reconstructed descriptions, not verbatim prompts. Do not cite a model name or present those summaries as exact source prompts; this is missing provenance, not a claim that the tool hid its inputs.

## Runtime scope

The prepared gait source supports only measured left/right views. It does not establish eight-direction NPC movement, and no missing front, diagonal, or back views are mirrored or inferred. The candidate sheets are static turnaround views rather than authored walk cycles. Runtime leg motion is procedural, driven by measured actor displacement and the role-specific limb/boot regions; the original PNG pixels and protected garment regions remain the source of the rendered appearance. Authored front-facing idle, greet, interaction, and personality actions continue to come from the existing character animation library and NPC activity scheduler.

The working runtime activates the measured left/right candidates and short lateral routes for all three roles. These remain candidate gait sources, not authored walk cycles; front walk-candidate rows are not evidence of approved locomotion. Root accepted standalone NPC review v5 for normal and quarter-rate observation, but that result covers the standalone fixture only. The tenth Main-native review matched its expected source frame but was visually rejected for an imp lower-body/hand cutout gap. After the source/limb correction, Root visually reviewed all 21 captures from the eleventh Main-native review across the three roles in three contact sheets and found the former hand/hip gaps absent. Its normal 74.433-second and quarter-rate 297.683-second recordings both played through to completion in CUA video. This is limited review of source, route, head/feet framing and limb presentation, not approval of natural authored walk cycles, every action/appearance combination, or additional gait directions.

## ART-17 delivery boundary

For an atomic candidate delivery, include the measured source assets and provenance, the region manifest and source provider, the procedural gait/runtime integration, the related CPU tests, and the versioned native review fixture and report. The relevant current files are:

- `assets/characters/ticket-turnaround-candidate-v2.png`, `assets/characters/imp-turnaround-candidate-v1.png`, and `assets/characters/announcer-turnaround-candidate-v1.png`
- `assets/characters/npc-turnaround-provenance.json` and `assets/characters/npc-motion-regions.json`
- `game/world/npc_motion_sources.gd`, `game/world/npc_walk_motion.gd`, and the required rig/activity/world integration files for the final accepted implementation
- `game/tests/test_npc_motion_sources.gd/.tscn`, `test_npc_walk_motion.gd`, `test_npc_activity.gd`, `test_npc_world_activity.gd`, plus any directly affected rig tests
- `game/tests/native_island_npc_motion_review.gd/.tscn` and `design/runtime/island-npc-motion-review.md`
- This preparation note and the versioned review report/captures, clearly labeled as candidate evidence

CPU source-measurement tests establish data validity and preservation contracts; they do not establish visual quality. A real Hero `_ready` CPU regression injects one invalid prepared direction, confirms all eight views use their complete original RGBA source, then rebuilds and confirms recovered coverage. NPC CPU source tests likewise verify measured input and preservation only. The eleventh Main-native evidence reviewed the corrected integrated NPC source/route/limb presentation within its documented scope; it does not establish authored full walk-cycle quality or full action/appearance coverage.

## 2026-10-14 review status

The eleventh integrated NPC capture remains the latest source/route review: Root watched its 74.433-second normal and 297.683-second quarter-rate clips to completion and reviewed all 21 role/phase PNGs in three contact sheets. The previously reported hand/hip gap was absent. These are bounded checks of source consistency, head/feet framing, route presentation, and the reviewed limb silhouettes; they do not approve the turnaround candidates as authored walk cycles, establish NPC eight-direction gait, or cover every action/appearance pairing. The ART-17 ticket records the review scope and links to the evidence.

The separate dialogue-hold regression passed GPU execution with exit 0 and zero ERROR. Root reviewed its open, post-dialogue idle, and pause captures with the guide's head, hands, and feet visible. It recorded 113 changed rig-foot-pose frames, 0.320 m of procedural rig travel, and 0.496 m of guide-root path during the post-close sample; the pause sample remained frozen. Root watched the 7.467-second normal and 29.850-second quarter-rate videos through to completion; frame 443 is the pause-capture point, not the total movie length. This is scripted fixture evidence with declared player placement, camera framing, and hidden player visuals. It does not establish full character-action coverage. See the [dialogue report](../../pm/Snapland-art/images/ART-17-dialogue-accepted-report.json) and [log](../../pm/Snapland-art/images/ART-17-dialogue-accepted.log).

The island route also has a final real-input delivery set: 5,500 simulated frames, 178.545 m, and nine screenshots with no fixture teleport/recovery or ERROR. Normal (91.667 s) and quarter-rate (366.617 s) video playbacks both reached the end. Root reviewed the nine-image contact sheet and full-size guide/dock-return images, not all nine original screenshots individually at full size. Delivery videos are compressed normal 30 FPS/1280 width (CRF 28) and quarter-rate 15 FPS/960 width (CRF 30, 1.6 Mbps cap); original 60 FPS movies remain private. The Movie Maker output is offline; none of these frame rates or durations is an in-game performance benchmark. The [route report](../../pm/Snapland-art/images/ART-17-island-motion-finalproof-report.json), [log](../../pm/Snapland-art/images/ART-17-island-motion-finalproof.log), and [contact sheet](../../pm/Snapland-art/images/ART-17-island-motion-finalproof-contact.png) accompany the videos linked in the ART-17 ticket.
