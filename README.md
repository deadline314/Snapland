# Snapland

以單人遊園為中心的HD-2D拍貼收藏遊戲，預留1–4人同機與P2P。目前可玩 Godot 4.7.2 的上島、迎賓大道十二款及潮汐碼頭「浪間小艇」，共十三款獨立玩法。

## 遊玩

2026-11-13 已輸出包含十三款玩法、參與收藏與免費補拍的 Windows 預覽成品，完成三步補拍的實際鍵鼠、原圖與關閉重開、兩區獨立資源包取卡／讀檔，以及新遊戲／碼頭啟動與原十二款圖資載入檢查；執行檔不隨 repo 提交，結果與來源指紋附 [SG-29](pm/Snapland-small-game/[SG-29]提供免費補拍與參與收藏.md)。「浪間小艇」的實際物理與完整回合驗收見 [SG-28](pm/Snapland-small-game/[SG-28]實作浪間小艇與碼頭收藏.md)。這是程式化操作與資源驗證，角色動作與真人試聽仍依各票驗收。開發環境安裝官方 Godot 4.7.2 後執行 `launch-game.cmd`，或用 Godot 匯入 `project.godot`。WASD／方向鍵移動，E／Space 互動，Esc 返回；滑鼠與鍵盤可操作選單。開場可跳過與重播；收集六張不同普通拍貼後，可從迎賓大道前往潮汐碼頭。潮汐鐘可直接預覽漲退潮，兩端渡船與返回迎賓都免費，重開保留所在園區。

迎賓大道包含十二款獨立小遊戲、十八個普通收藏來源、十二小惡魔收藏、遊戲內成就、任務、設定與存檔。潮汐碼頭可探索燈塔岸線、沙洲與環岸步道，並從遊戲亭或地圖進入「浪間小艇」：W／上划槳、S／下反槳、A／D 轉舵、Q／E 側滑、空白鍵拿箱與交貨。自然結算可取得當地普通卡，浪峰側滑靠岸且不撞箱可取得小惡魔卡；輔助保留資格，練習與取消不取卡。其他碼頭玩法、故事與其餘八區依 [完整遊戲接續交付](design/runtime/full-game-delivery.md) 逐項製作。新遊戲從晚風號序章開始，可略過及重播；舊存檔不強迫重播。完整結局、異空間與多人接續擴充。Steam adapter 保留接口，目前沒有連線到正式 Steam 成就。

已開放玩法正常結算即可收藏普通拍貼，成績與勝負如實顯示；練習及中途取消不自動發卡。實際嘗試一次後，可從遊戲亭或相簿免費補拍普通／小惡魔卡：依序觀察示範、調整布景、按下快門。補拍會保存這次安排的布景與取得來源，並與真正達成挑戰分開記錄；重拍不重複發錢，也不覆蓋已收藏的原圖。

## 遊戲驗證

`python tools/run_game_tests.py` 執行真實 Godot 的乾淨匯入、啟動及受影響 runtime 測試，缺少引擎或腳本錯誤會失敗。測試使用獨立暫存 profile，不覆寫玩家進度。

完整 CI 使用四個必要遊戲批次，共用素材來源只檢查一次；本機預設仍跑全部。可用 `--shard-index 0 --shard-count 4` 執行其中一批（索引 0–3）；與 `--only` 不可混用，單批結果只代表該批。分批覆蓋與實測耗時見 [驗證分批](design/runtime/runtime-ci-shards.md)。

原生 GPU 截圖：`godot --path . -- --capture`。驗收時另設 `SNAPLAND_SAVE_PATH` 到測試檔案；截圖模式自動退出。設計研究、來源與驗收限制見 [本輪設計](design/runtime/DESIGN.md) 及 [票券入口](pm/README.md)。

十二款原生自動操作驗收：指定獨立 `SNAPLAND_SAVE_PATH` 後執行 `godot --path . res://game/tests/native_review.tscn`，需要 GPU。它輸入鍵鼠事件並保存結算畫面，屬程式化驗收，不能代表真人的樂趣或音樂聽感評價。

本版原創圖形與聲音沒有使用研究頁的商業遊戲資產。引擎授權見 [Godot license](https://godotengine.org/license)；字型與第三方授權隨預覽包提供。

閱讀 [設計入口](design/README.md)、[需求票](pm/README.md) 與 [工作規範](AGENTS.md)。

## 局部驗證
python tools/verify_design.py --scope park
python tools/verify_design.py --scope games
python tools/verify_design.py --scope story
python tools/verify_design.py --scope items

完整可用驗證由 GitHub Actions 在變更及每小時排程執行，包含 Godot runtime；排程只在 workflow 合併預設分支後生效，並可能受 GitHub 排程延遲影響。設計資料測試與原生遊戲驗證分開報告。[128款設計目錄](design/02-minigames/catalog.md)已補齊；其餘115款、多人體驗與全遊戲品質仍逐票實作／驗收。完整 CI 結果以對應提交的實際 Actions 為準。

角色最新交付見 [ART-34](pm/Snapland-art/[ART-34]擴充島上其他髮型動態.md)：三款人類髮型、八方向及四種帽狀態的局部驗收完成，正常／慢速影片、參考原圖及隔離資源包證據附票。雲端錄影降低環境渲染成本，不代表完整光影或原 GPU 效能驗收。
