# 主角單髮型 2D 骨架樣本交付

2026-10-16，ART-30。主 Session 接受本次獨立樣本，原本島嶼、其他髮型及 NPC 尚未套用；不是使用者親自試玩或整島驗收。

## 操作與輸出

`build/hero-2d-hair-sample-release/Snapland-Hero-2D-Hair-Sample.exe` 可直接開啟。方向鍵或 WASD 移動，Space 拍照；按鈕切帽子、髮尾動態、正常／四分之一模擬速度與暫停。右側為跟隨當格頭部的近看，左側保留完整人物。髮根與帽子跟隨頭部的逐格位移；「髮根固定」是相對頭部固定。只有外側髮尾輕微回擺，保留原八方向人物與全身動作。

## 可重現驗證

使用 Godot 4.7.2，GODOT_BIN 可指定官方引擎。所有入口經既有啟動驗證器並配置絕對路徑的隔離存檔，依序執行，同一暫存專案不可並行重建。

- `python -m unittest tests.test_hero_2d_assets tests.test_hero_2d_authoring tests.test_hero_2d_hair_gpu_report -v`：9 個素材／製作檢查及 4 個缺漏證據回歸。
- `python tools/hero_2d/run_contract_tests.py`：原姿勢、圖層與 1280 合成格。
- `python tools/hero_2d/run_hair_review.py --contracts`：乾淨匯入、動態與骨架檢查，640 張 CPU 休止合成精確一致。CI 也執行此項。
- `python tools/hero_2d/run_hair_review.py --gpu-contracts`，再 `python tools/hero_2d/check_hair_gpu.py .review/hero-2d-hair-20261016/gpu-contracts`：固定身體姿勢的實際 GPU 截圖比較，要求完整四組；不是操作試玩。需要製作工具依賴與顯示裝置。
- `python tools/hero_2d/run_hair_review.py --normal` 與 `--quarter`：原生事件巡覽及 30 FPS 錄影。慢速是實際四分之一模擬時間，不是影片減速。需要 ffmpeg。
- `python tools/hero_2d/run_hair_review.py --export --smoke-export`：官方 Windows 匯出範本與獨立預設畫面啟動。
- `python tools/hero_2d/run_hair_review.py --export-controls`：直接由獨立輸出的預設場景接受原生事件巡覽。需先匯出；不依賴 release 不支援的場景覆寫。

所有結果在 `.review/hero-2d-hair-20261016/`。重跑影像巡覽會把同名舊紀錄移入其 history，避免把前版影片和新版狀態混用。製作暫存會完整重建，缺少必要來源直接失敗；原完整換裝樣本使用另一個暫存及輸出目錄。

## 本輪證據與界限

正常 56.8 秒／1704 格、慢速 214.133 秒／6424 格，1280×800、30 FPS，均以播放速度 1× 分段檢視。主 Session 另外檢查兩種帽狀態全部八方向的全身／頭部原生截圖，重看左側走路、轉向、戴帽和拍照；暫停、關動態、反向及輸出啟動有實際截圖及狀態證據。不是每一電影格逐一人工審查。

128 個明確頭部點修正先前 1–3 像素的相對滑移，12 張身體圖集不變。GPU 四組固定姿勢比較中，髮根／帽子受保護內部像素動態前後差為零，髮尾區有可見像素變化，收斂後回到休止圖；CPU/GPU 透明混色可有 1–2 色階差，不能宣稱整張 GPU 與 CPU 原合成逐位元一致。髮尾頂點可見位移的數值預測約 0.8–3.2 像素，與實際 GPU 像素比較分開報告。

[驗收範圍、影片規格與來源雜湊](../../pm/Snapland-art/images/ART-30-verification.json)、[正常錄影](../../pm/Snapland-art/images/ART-30-normal-normal.mp4)、[慢速錄影](../../pm/Snapland-art/images/ART-30-quarter-quarter.mp4)、[票據與截圖](../../pm/Snapland-art/[ART-30]製作主角髮尾骨架動態樣本.md)。完整遊戲套件由 CI 執行，本輪局部檢查不代表全專案通過。
