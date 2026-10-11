# Snapland 工作規範

## 品質與交付
- 先讀適用規範與 pm-ticket。每項工作先開票再實作，使用者指示優先。
- git fetch origin 後，以各 pm 專案 origin/main 最大號 +1 開票；同時檢查当前分支既有號碼，避免自己重用尚未合併的號碼。開票立即 commit 並 push。
- 一需求一票。完成相關局部驗證、截圖放 pm/<專案>/images/，票加 Commit 段落、完成狀態與勾選驗收後逐票 commit/push。
- 使用 feature branch（預設 codex/），結束前 fetch，必要時 rebase origin/main。只移除已交付且確認可移除的舊分支。
- 作者 email 為 stanley890314@gmail.com；commit 訊息不加助理品牌署名或 Co-Authored-By。
- 提交前跑受影響局部測試；完整可用套件由 CI 在每小時及程式/規格變更時執行。
- 不把設計檢查、文件截圖或資料驗證描述成遊戲試玩成功。

## 設計基線
- 單人中心，1–4人同機與P2P可擴充；簡單AI可取得全內容。
- 至少100款基本小遊戲；當前128候選，異空間變體不湊數。
- 十區普通拍貼180開終區，每區12惡魔拍貼開當區異空間。收藏不消耗。
- 物品使用Steam相容固定定義；離線收藏與可交易經濟分開。

## 驗證命令
python tools/verify_design.py --scope park
python tools/verify_design.py --scope games
python tools/verify_design.py --scope story
python tools/verify_design.py --scope items
python tools/verify_design.py --scope links
python tools/verify_design.py --scope all
python -m unittest discover -s tests -v

Godot 執行專案使用 `python tools/run_game_tests.py` 驗證匯入、啟動、核心、小遊戲、劇情、音訊與整合；設定 `GODOT_BIN` 指向 Godot 4.7.2。CI 不允許缺少引擎或測試時安靜略過。直接執行會寫存檔的測試或截圖時，必須提供獨立 `SNAPLAND_SAVE_PATH`，不得使用玩家存檔。
