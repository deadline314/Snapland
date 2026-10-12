# Ribbon Rhythm Main acceptance review

`game/tests/native_ribbon_rhythm_review.tscn` exercises the production game-006 path through the real welcome-park station, station menu, `Session`, `RibbonRhythmView`, model and Main result screen. It is a windowed native fixture and requires an isolated absolute `SNAPLAND_SAVE_PATH`; a headless run fails with exit status 1. Root owns the GPU run and visual recording.

The formal route begins at 1× with a wrong Right-key press on the visible Left cue. The model records that real error without advancing or answering for the player. The fixture pauses with the live HUD button, confirms retry through the real confirmation button, and copies the model, Session, note cursor and score ledger synchronously inside the confirmation signal. It asserts exact zeros before another frame runs. Then it plays all eight authored actions with keyboard events, holding the two ribbon sweeps for their authored durations. The final result must be an unassisted devil clear: eight precise gestures, zero errors, eight ledger entries, four strong-beat bonuses and 900 points. Main must persist the ordinary and devil collection records.

The second route enters actual station-menu practice with assistance and reduced motion enabled. At engine time scale 0.25× it uses pointer presses and releases on the visible left, center and right controls. It still sends all eight actions and holds both sweeps; assistance never supplies an answer. The expected result is ordinary success, no devil eligibility, and unchanged photos, achievements, quests, coins and wardrobe data because the run is private practice.

All game actions use `Input.parse_input_event` through the View's production GUI path. Model state and result scalars are copied synchronously inside signals before Main's queued Session deletion can cross an `await`. Movie capture calls `RenderingServer.force_draw` on every fixture frame. The fixture has only been parser/headless-guard checked here; Root should run its native GPU flow and inspect the captures for cue readability, hold timing, layout and pointer targeting.


## Root 原生驗收 — 2026-10-12

Root 重跑模型 42 項、畫面契約 28 項、共用 Session 53 項。v4 兩次原生操作均無 ERROR：正式 900 分，八個實際輸入、兩次留按；暫停／恢復、確認重試歸零，私人練習含輔助及降低動態，收藏、成就、任務、貨幣、衣櫃與平台待同步資料不變。

第一部完整影片 2439 幀／40.65 秒：正式動作 1×，私人動作 0.25×，結果截圖等待 1×。第二部 4171 幀／69.5167 秒：正式與私人動作 0.25×，結果等待 1×。上述時間是各部完整影片長度，並非正式回合時長。Root 播放第一部取自 4–8 秒的正常動作短段，看到跳躍、踏步及留按；第二部正式 25.20 秒／450 分與私人 61.47 秒／550 分，看到角色手腳完整、提示位於頭頂上方。正常 6.90 秒原始畫格亦顯示正式 450 分和完整鞋底。

早期影片提示遮住角色頭部，該版被拒收；v4 已移至上方並加入提示與角色／節拍面板的實際矩形隔離檢查。現有步行、跳躍、揮手仍被重用，不能據此宣稱專屬舞蹈、全部 NPC 動作、音樂試聽或完整首次教學已通過。
