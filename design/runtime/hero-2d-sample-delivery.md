# 主角 2D 樣本使用與重製

2026-10-16；ART-29。只包含獨立主角樣本，正式島嶼未接入，單髮型骨架動態另見 [ART-30 交付](hero-2d-hair-sample-delivery.md)。

## 操作

先執行 `python tools/hero_2d/run_review.py --export-only --smoke-export`，輸出 `build/hero-2d-sample-release/Snapland-Hero-2D-Sample.exe`，可直接開啟。方向鍵或 WASD 移動，Space 拍照；右側按鈕可換兩種髮型、帽子、兩件外套、正常／慢速及暫停。此樣本不載入正式島嶼或玩家收藏。

## 重製素材

以 Python 3.12 安裝 `tools/hero_2d/requirements-authoring.txt`。`python tools/hero_2d/register_sources.py` 讀取保留的 2D 原件並重建作者資料，再執行 `python tools/hero_2d/author_pack.py` 重建執行素材。若調整定位，應編修來源註冊與固定人物基準規則，再重新輸出，不逐格依透明外框或鞋底置中。原圖、提示詞、來源雜湊、裁切範圍、頭部錨點和前景遮擋都保留在 `assets/characters/hero-2d-v1/`；生成候選和採用來源的狀態分開記錄。

## 局部驗證與證據

- `python -m unittest tests.test_hero_2d_assets tests.test_hero_2d_authoring -v`：素材與作者工具 9 項。
- `python tools/hero_2d/run_contract_tests.py`：隔離專案匯入、姿勢／部件及 1280 張實際合成圖格。
- `python tools/hero_2d/run_review.py`：原生輸入事件巡覽，另錄正常與四分之一模擬時間。需要 Godot 4.7.2、畫面裝置、ffmpeg；設定 GODOT_BIN 指向引擎。
- `python tools/hero_2d/run_review.py --export-only --smoke-export`：需要官方 Windows 匯出範本，預設畫面啟動擷取；這個選項本身不驗證操作。

每個原生入口都使用絕對隔離存檔與獨立使用者目錄，按序執行，勿同時重建同一個暫存專案。原生狀態 PASS 不能替代親自播放正常／慢放、看全身圖格與輸出版本。驗收範圍及檔案雜湊見 [ART-29 報告](../../pm/Snapland-art/images/ART-29-2d-verification.json)；[影片與圖格](../../pm/Snapland-art/[ART-29]製作主角完整換裝動作樣本.md)。

## 2026-10-16 ART-31 最新行走回歸

原逐格追蹤 1–3 像素並不能修好來源內部的頭、眼、脖子不一致。現以同方向固定頭頸分件取代，保留肩膀、相機、手臂及腿的原畫；換裝與髮帽同步讀取這個頭部。舊「12 張身體圖集不變」結論已失效，不能再當最新驗收。

本輪八組外觀共 512 張行走格納入實際原生合成像素檢查，另有正常／四分之一速度的固定根點對照與原生輸入錄影。完整製作連續重跑兩次，21 檔一致。兩個獨立輸出均已更新。[目前驗收與範圍](walk-pixel-stability.md)；Commit-1／舊頭部追蹤報告屬歷史失敗版本，不代表此版通過。
