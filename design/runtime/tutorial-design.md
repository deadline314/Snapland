# MAIN10 教程面板與資料設計

## 目的與範圍

提供可略過、可重看、可逐步閱讀的園區與 12 款迎賓小遊戲圖文教程。教程內容須準確描述現有鍵盤與滑鼠操作、一般目標和成功條件；正式遊戲截圖稍後由主 session 實拍並放在 `res://assets/ui/tutorials/`。缺圖時顯示清楚的文字占位與檔案路徑，不能畫成假截圖或宣稱已完成截圖驗收。

這一部分只負責教程資料、逐步面板與明確訊號，不負責開啟／暫停遊戲 session、判定練習結果、授予分數或收藏。主 session 與小遊戲整合由其他工作負責。

## 元件與資料流

- `game/data/tutorials.json` 保存 `schema_version: 1` 和 13 個 lesson：`park`、`game-001` 至 `game-012`。每課有 2–3 步；每步包含短標題、目標、實際輸入、可觀察成功條件、預定截圖路徑和替代文字。
- `game/ui/tutorial_catalog.gd` 載入並檢查資料，提供 `lesson_ids()`、`get_lesson(id)` 與 `validation_report()`。回傳資料採副本，缺課／壞資料明確報告，不以空內容偽裝有效課程。
- `game/ui/tutorial_panel.gd` 顯示當前一步、截圖或缺圖占位、目標／輸入／成功條件、進度與操作按鈕。它只發出意圖訊號，不直接操作 game session 或存檔。

主 session 建立面板後呼叫 `open_tutorial(target_id)`；`target_id` 為 `park` 或 `game-001`…`game-012`。`step_changed(target_id, zero_based_step, step_count)` 可供外層同步進度。導覽按鈕和方向鍵只改本地步數。

面板提供 `skip_requested(target_id)`、`practice_requested(target_id)`、`start_requested(target_id)`、`replay_requested(target_id)`、`close_requested()`。外層自行將 skip/start 接到原有挑戰流程；practice 只代表玩家提出練習請求，不代表練習沙盒、正式計分或任何收益已實作。開啟面板的外層須將園區輸入／遊戲處理與正式回合計時暫停，收到 start 或 skip 後再依既有流程恢復；practice 時外層也須保持正式 session 不計時。

## 截圖與缺圖行為

每一步的 `image` 僅能指向 `res://assets/ui/tutorials/` 下預定正式截圖，例如 `game-001-step-01.png` 或 `park-step-01.png`。面板先檢查 `ResourceLoader.exists()`；存在時用保留長寬比的 `TextureRect` 顯示並提供替代文字。不存在時輸出含 lesson、步數及完整資源路徑的具體警告，顯示「正式遊戲截圖尚未提供」占位與可讀教學文字。警告按面板實例與路徑去重。不得讀取 `pm/` 的研究匯出圖，也不建立或修改 PNG。

## 操作與無障礙

面板使用現有 `paper_ui.gd` 色票、主題和字體。標題 24 px、步驟說明 18–20 px、標籤至少 16 px。圖片使用 `KEEP_ASPECT_CENTERED`；右側教學文字放入獨立 `ScrollContainer`，長文不擠壓底部操作列。下一步、上一步、重看、練習、略過、開始與關閉皆為可聚焦 Button；Tab／Shift+Tab 移動焦點，Enter／Space 啟動，左右方向鍵切換步驟，Escape 發出關閉請求。面板收到操作鍵時標記為 handled，避免傳入底下玩法。降低動態設定不改變面板狀態或強迫過場；此面板不新增自動播放或補間動畫。

## 內容真實性

12 款遊戲教程以 `welcome_games.json` 的 id、名稱、一般目標和普通成功條件為準，以 `session.gd` 的實際事件分支核實鍵鼠輸入。教學不更改或承諾遊戲計分。園區教程只描述目前 HUD 公開的 WASD／方向鍵移動、E／Space 互動、C 衣櫃、T 時段、F 招呼、P 拍照與 Esc 暫停；不把教程文字當成新遊戲功能。

## 驗收與測試

資料測試載入正式 13 課，檢查 id、每課步數、必要欄位、圖檔命名根目錄和畫面文字不是空白。面板測試使用真實資料並驗證開課、首末步界限、前後切換、重看、略過／練習／開始／關閉訊號、焦點初始狀態、Escape 已消耗，以及缺圖 fallback 會保留目標／輸入／成功文字並產生具體診斷。測試不得聲稱已拍攝正式截圖或已測練習收益。
