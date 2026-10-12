# SG-20 Hat Rescue native v13 evidence

## Frozen native runs

Root ran the candidate fixture through the real Main station and menu, with an isolated save and real keyboard/pointer InputEvents. No score, result, catch state, or position was injected by the fixture. Both runs exited 0:

| Run | Engine time scale | Frames / movie duration | Formal result | Actual post-draw observations |
|---|---:|---:|---|---|
| Normal | 1.0× | 1,943 / 32.3833 s | Six center catches, zero misses, 816 points; ordinary and devil outcomes | Catch indices 0–11 at movie frames 102–136; left and right walk indices 0–7, masks 255/255, completed frame 153 |
| Slow | 0.25× | 7,598 / 126.6333 s | Six center catches, zero misses, 816 points; ordinary and devil outcomes | Catch indices 0–11 at movie frames 305–438; left and right walk indices 0–7, masks 255/255, completed frame 504 |

After formal play, assist and reduced motion were enabled through settings and the real pointer route played private practice: six center catches, zero misses, 816 points, practice result, no devil result. The fixture compared photos, achievements, quests, visited locations, settings, appearance, equipped items, owned clothes, coins, wardrobe rewards, pending platform achievements, and intro state before and after; `tutorial_seen_games` was also checked when present. The compared progress snapshot remained equal.

The formal run also checked pause/resume and the retry reset synchronously at the confirming button event. Existing catch animation capture remained active and recorded all twelve frames. The new gait observation runs on `RenderingServer.frame_post_draw`, reads only the live presentation after rendering, and writes one full-screen image the first time each frame index is actually visible in each direction. It does not send input or advance the model. A run fails unless both directional masks are 255 and the total is 16 images.

## Logs, captures and media

Raw 60 fps native movies and full logs:

- `.review/sg20-normal-v13.avi` and `.review/sg20-normal-v13.log`
- `.review/sg20-quarter-v13.avi` and `.review/sg20-quarter-v13.log`

All 31 quarter-run post-draw images were preserved in `.review/hat-v13-quarter-captures/`; normal-run images are in `.review/hat-v13-normal-captures/`. Each set has 12 catch frames, 16 directional walk frames, and three result/mid-round images. The exact native fixture used for these runs has SHA-256 `A5B71E655EDD5DB40EEC089A2D641B2113B27108E85BE2F68DC195430DC99ED0`.

Compressed MP4s, cut from the actual AVI runs, and contact sheets are in `pm/Snapland-small-game/images/`:

- `SG-20-hat-v13-normal.mp4`, `SG-20-hat-v13-quarter.mp4`
- `SG-20-hat-v13-normal-catch-focus.mp4`, `SG-20-hat-v13-quarter-catch-focus.mp4`
- `SG-20-hat-v13-normal-walk-focus.mp4`, `SG-20-hat-v13-quarter-walk-focus.mp4`
- Normal and quarter catch contact sheets, plus normal and quarter left/right walk contact sheets.

The three tutorial screenshots are actual normal-speed v13 captures: a walking frame, the two-rescue mid-round frame, and the six-center 816-point result. Their captions describe the visible example rather than native test status.

## Verification and limits

The candidate Hat View headless test has 55 passing checks, including full directional frame caching, travel-driven phase, no phase advance while stationary, phase continuity on turning, retry reset, and cache reuse. The Hat model's 28 checks and shared Session's 80 checks were independently run by Root. This candidate includes the Hat model/view integration in Session, focused gameplay and input checks, the isolated native fixture, and evidence documentation; unrelated shared test function bodies are preserved.

Root played both complete v13 movies through to their endings and reviewed the normal/quarter catch and walk clips, all twelve catch poses, all sixteen directional walk poses, and full-size character frames. The default character remained full-body, consistent, and unobscured; the feedback panel cleared the head during the slow formal and practice sections. Basic visual acceptance for this default presentation passed. These runs do not verify first-time tutorial comprehension, Park's private-exit path, all fifty outfit silhouettes, or the separate three fully animated NPC target. Those remain open and the ticket stays in progress.
