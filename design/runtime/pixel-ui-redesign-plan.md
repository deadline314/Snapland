# 全遊戲像素UI Implementation Plan

> 執行：subagent-driven-development；使用者已授權並行派工及由主session驗收。GPU只由主session執行。

**Goal:** 全部現有遊戲介面改用精緻像素視覺並改善空間、固定操作與資訊層級。

**Architecture:** 保留Paper共用API但換成像素圖示與分層深海藍框架。Main只擁有固定標題、內容、操作列與導覽，專用面板擁有內容布局和必要的單一捲動。

**Tech Stack:** Godot 4.7.2、GDScript、現有完整中文Noto字庫、原角色與照片資產。

**Spec:** [pixel-ui-redesign.md](pixel-ui-redesign.md)

## Global Constraints

- 固定操作完整可見；800×450、1280×720、1920×1080與文字1.25倍必須驗收。重要操作維持44實際像素目標。
- 沒有不必要捲動或巢狀活動捲動區。參考圖片不得當作產品資產。
- 不改舊測試選擇器、不刪舊功能斷言、不加入known failure；舊內容API在新布局保留等價操作。
- 統一validated entrypoint、絕對獨立SNAPLAND_SAVE_PATH、逾時與完整ERROR檢查，不碰正式進度或備份。
- 不同工作者不改同一檔案，唯一main owner接入其他面板；每票固定基準為f1d2fee。

## Review Focus

1. 中文長標題／大型文字造成控制列或按鈕被切掉：布局測試測實際control rect，原生逐頁看字與邊界。
2. 空收藏、遺失照片與多頁資料：保持誠實空狀態、完整原圖、全部穩定ID與可操作頁碼。
3. 改分類後焦點停在已釋放節點：實際Tab與返回、類別切換後確認焦點與回呼。
4. 設定／外觀取消或重入意外寫入：真實隔離存檔保存／讀回及取消草稿驗證。
5. 小視窗容器minimum與viewport縮放互相累積：resize後等待布局穩定再測，原生800×450不靠縮字或省略主要操作。

## Task 1 — ART-23 shared shell

Files: `game/ui/paper_ui.gd`,`game/main.gd`,`game/tests/test_pixel_ui_shell.gd/.tscn`。

- 保留theme/label/button/card/plaque/adapt_menu API；新增set_text_scale/text_scale，使用整數像素圖示與明確焦點。
- 建立固定header/content/footer。PausePlayerPortrait使用目前角色資料；PauseActions保留全部主要操作與既有回呼，HUD在模態時隱藏、返回恢复。
- 新測試驗證三種尺寸、真實Tab遍歷、Escape、完整操作邊界和无捲動；原生截图若比例或資訊層級不合理，退件重做。

## Task 2 — ART-24 travel and collections

Files: `collection_book_panel.gd`,`photo_viewer.gd`,`island_map_panel.gd`,`achievement_stamp_book.gd`,`tutorial_panel.gd`,`test_pixel_ui_collections.gd/.tscn`。

- 固定分類／翻頁；小視窗每頁兩張拍貼，照片旁放名稱與狀態。長內容按實際容量分頁，既有AdaptiveMenuScroll查詢保留在真正的內容viewport，玩家無須滾動。
- 地圖12設施與9路口可選不傳送，選中詳情可讀；成就資格不變。教學保留實際截圖與重看。
- 驗证新布局＋舊travel-book、original-viewer與tutorial測試。不要把遺失資源預設畫面說成真照片。

## Task 3 — ART-25 customization

Files: `wardrobe_panel.gd`,`time_panel.gd`,`settings_panel.gd`,`game/core/progress.gd`,`test_pixel_ui_customization.gd/.tscn`。

- SettingsPanel.open(main,body)分聲音、遊玩與畫面、操作。ui_scale預設1.0、有限數值clamp1.0–1.25，既有存檔相容、錯誤值安全忽略。
- 換裝角色、分類與套用持續可見；基礎免費不限次、購買及取消原規則。四個時段選擇立即生效，不能改成新待套用機制。
- 驗证設定真正保存／讀回、草稿取消、八方向預覽、真實4時段ID與大字控制邊界；CPU通過後看原生換裝與每設定分類。

## Task 4 — ART-26 gameplay surfaces

Files: `minigame_hud.gd`,`island_game_invite.gd`,`photo_stage.gd`,`dialogue_panel.gd`,`test_pixel_ui_minigames.gd/.tscn`；Main內拍貼／結果布局由唯一main owner接入。

- 改HUD、pause、result、invite、dialogue、photo frame；signals、分數資料、教學與聲音接口保持一致。主要操作不用捲動才能到達。
- 使用既有HUD69檢查、邀請及對話整合回歸；原生擷取實際Main、練習session與有明示合成資料的結算，不能當成功通關證據。

## Primary verification and delivery

- 新增九個相關測試（含NPC同方向長幀與缺少側向素材的待機回歸），加進`tools/run_game_tests.py`，保留原選擇器與PASS／ERROR規則。只跑受影響局部套件，完整CI另行處理。
- 本輪局部執行器`.review/run_pixel_ui_check.py`透過`tools.godot_entrypoints.run_validated_godot`；每次使用不同profile、保存engine.log并判exit/PASS/ERROR。範例：`python .review/run_pixel_ui_check.py test_pixel_ui_shell cpu`。
- 原生fixture `game/tests/native_pixel_ui_review.tscn`，傳`--ui-size=800x450 --ui-scale=1.25 --ui-prefix=pixel-vN`；逐頁檢查、实际看截图，不把腳本開頁稱作真人試玩。
- 圖片、測試log和JSON報告放每票images，票寫問題—改動—驗收與遠端提交。每票只勾真過條件；來源／測試及主分支整合均不得假称完成。
