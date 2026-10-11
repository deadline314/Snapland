# Snapland

以單人遊園為中心的HD-2D拍貼收藏遊戲，預留1–4人同機與P2P。現在有 Godot 4.7.2 的上島與迎賓大道可玩第一版。

## 遊玩

Windows 預覽包在本次交付的 `build/`，雙擊 `Play-Snapland.cmd` 可啟動並把預覽存檔獨立保存。開發環境安裝官方 Godot 4.7.2 後執行 `launch-game.cmd`，或用 Godot 匯入 `project.godot`。WASD／方向鍵移動，E／Space 互動，Esc 返回；滑鼠與鍵盤可操作選單。碼頭開場可跳過與重播，沿棧橋進中央廣場，再往上走進迎賓大道。

本版包含十二款獨立小遊戲、十八個普通收藏來源、十二小惡魔收藏、遊戲內成就、任務、設定與存檔。其他九區有路口及施工提示。船上序章、其他園區內部、異空間完整內容與多人仍屬後續範圍。Steam adapter 保留接口，目前沒有連線到正式 Steam 成就。

## 遊戲驗證

`python tools/run_game_tests.py` 執行真實 Godot 的乾淨匯入、啟動及受影響 runtime 測試，缺少引擎或腳本錯誤會失敗。測試使用獨立暫存 profile，不覆寫玩家進度。

原生 GPU 截圖：`godot --path . -- --capture`。驗收時另設 `SNAPLAND_SAVE_PATH` 到測試檔案；截圖模式自動退出。設計研究、來源與驗收限制見 [本輪設計](design/runtime/DESIGN.md) 及 [票券入口](pm/README.md)。

十二款原生自動操作驗收：指定獨立 `SNAPLAND_SAVE_PATH` 後執行 `godot --path . res://game/tests/native_review.tscn`，需要 GPU。它輸入鍵鼠事件並保存結算畫面，屬程式化驗收，不能代表真人的樂趣或音樂聽感評價。

本版原創圖形與聲音沒有使用研究頁的商業遊戲資產。引擎授權見 [Godot license](https://godotengine.org/license)；字型與第三方授權隨預覽包提供。

閱讀 [設計入口](design/README.md)、[需求票](pm/README.md) 與 [工作規範](AGENTS.md)。

## 局部驗證
python tools/verify_design.py --scope park
python tools/verify_design.py --scope games
python tools/verify_design.py --scope story
python tools/verify_design.py --scope items

完整可用驗證由 GitHub Actions 在變更及每小時排程執行，包含 Godot runtime；排程只在 workflow 合併預設分支後生效，並可能受 GitHub 排程延遲影響。設計資料測試與原生遊戲驗證分開報告。既有設計缺 `design/02-minigames/catalog.json`（SG-1），因此 games／links／all 的設計 CI 目前仍會失敗，不代表本版十二款 runtime 缺檔。
