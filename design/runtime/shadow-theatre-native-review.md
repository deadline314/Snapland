# Shadow Theatre native Main review

Run `res://game/tests/native_shadow_theatre_review.tscn` in a windowed Godot build with an absolute, isolated `SNAPLAND_SAVE_PATH`. The fixture enters the real game-009 station through the park and menu, then uses held arrows plus Space for three formal precise rounds. It verifies pause freeze, resume state, the confirmed retry's synchronous exact reset, result score rows and ordinary/devil photos. A second menu launch uses assist and reduced motion in private practice, moves the lamp by real pointer clicks, and presses the on-screen shutter button; the four progress dictionaries and coin balance must remain unchanged.

The on-screen shutter and Space share `ShadowTheatreView.shutter_requested`; clicking elsewhere in the playfield remains the lamp-position control. The fixture latches finish data synchronously by instance ID because Main removes the completed Session during that signal. It never assigns model, grade, score, or collection state. GPU captures are left to the native reviewer; headless checks cover the view signal and safe button bounds.

Fixture 只點擊可見且可用的 HUD 按鈕：先點暫停、再點 RetryButton，再從實際顯示的確認面板取 ConfirmAction，避開預先建立但隱藏的同名控制。最終結果在匹配 instance ID 的同步 finished 回呼擷取；所有期限依 time_scale 換算，速度下限 0.05、單次上限一小時，整段 watchdog 為 180 遊戲秒。四分之一速度時 result 12→48 秒、modal 5→20 秒、導航 30→120 秒、watchdog 180→720 秒；鍵盤幀數上限也隨速度縮放，原生操作與判定不變。

Fixture 在三輪正式 Space 定影與三輪私人滑鼠快門之前各等待 frame_post_draw，再拍攝真正的 3D 光源、紙偶、牆面與投影。渲染設定及幾何檢查可在 headless 驗證，但實際影子是否可見與清楚仍須由視窗 GPU 截圖審視，不能用輸入成功或模型 ledger 取代。

## Root v6 實際觀察紀錄

Root 已在隔離存檔的視窗環境執行：正常速度 438 幀／7.3 秒、四分之一速度 1368 幀／22.8 秒，兩者原生輸入與 ledger 檢查結束為 exit 0。Root 檢視第 3 輪投影、慢速正式結果 1326 分，以及正常私人回合 500→1000 分的影形移動與慢速正式回合 0→422 分的接近印記過程；基本物理投影已可辨，完整美術仍待後續檢視。

009 圖文教學的三張圖片直接使用目前四分之一速度 v6 的第 1／3 輪定影前截圖與正式結果 1326 分截圖，PNG 位元組未修改；標題、替代文字與 Shift 細調說明由既有教學文字欄位呈現。這些證據只記錄上述遊玩和物理投影觀察，不代表已驗完整教學導覽、離開路徑或全面美術。
