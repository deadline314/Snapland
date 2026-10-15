# 2D 行走固定根點與分件驗證

2026-10-16，ART-31。保留原本像素畫風；沒有新增人物 3D 模型，也沒有用拆腿、轉鞋或全身網格製造步態。

## 原因與現在的處理

原島嶼每張圖依當格鞋子中心重新置中，揮動中的腳因此被誤當角色根點。主角左向末格有 12 像素水平校正差，後向有 9 像素垂直差；NPC 左右行走的腰部原先分別有 39／41 像素水平範圍。獨立樣本另有頭、眼、脖子不一致的 1–3 像素變動，僅讓頭髮追其中一個點仍會抖。

現在先固定整個週期的角色畫布與地面，再從同方向第一個原畫姿勢取出剛性的頭頸分件。肩膀、背包、手臂、相機與腿仍使用各格原畫；頭頸切線已收回原島嶼 178–185、獨立樣本 193–197 像素，避免把肩背一起切入頭部。NPC 保留原本已正確的 448 像素地面高度，只消除錯誤水平置中。頭部量測、頭寬與換髮遮罩每方向共用同一頭部，衣服和擺臂不再參與髮型縮放。所有附件標記也同步來源的根點平移。

原島嶼站立目前共用該方向的落腳定格，起停不再切換到大小不同的另一張頭像。原獨立待機／眨眼素材保留，可用明確的來源檢視模式檢查；**它不是目前島上站立的眨眼動畫**。髮尾骨架仍限於 ART-30 的主角單款髮型樣本，沒有宣稱已接進島上或所有 NPC。

## 來源與覆蓋

| 來源 | 序列／行走格 | 狀態 |
|---|---:|---|
| 原島嶼主角八方向 | 8／64 | 已接回既有島嶼合成入口 |
| 獨立主角：兩件衣物 × 兩款髮型 × 兩種帽狀態 × 八方向 | 64／512 | 兩個獨立 2D 樣本共用修正後素材 |
| 阿浪 NPC 左右行走 | 2／8 | 保留已採用的兩個方向 |
| 阿浪與售票員正面候選 | 2／16 | 僅做圖格檢查，仍未採用為島上行走 |

共 76 序列、600 張行走合成圖格；另輸出原始主角畫布與 24 張待機圖供檢查。沒有合格行走來源的 NPC 繼續站立，不以位移或候選素材冒充完成。

## 驗證界線

- 實際原生 CPU 合成輸出固定在同一畫布，逐格比對可見頭部像素。舊版 76 組失敗，新版 76 組通過；這不是鏡頭追蹤、宣告錨點相等或遊戲試玩。
- 下半身與原始來源按已登錄整數校正逐像素比較：所有透明輪廓及不透明顏色必須相同。Godot 匯入器會補近透明邊緣的隱藏 RGB，這些補色不算人物位移。另獨立量測已採用 NPC 腰部圖案與鞋底；腰部剩餘原畫擺動不超過 8 像素，鞋底全部為 448。把下半身故意偏一像素仍會失敗。
- 檢查器拒絕缺序列、缺格、空清單、錯誤畫布、錯誤來源雜湊及可把下半身藏掉的切線。固定頭部不能靠凍結整個人物通過。
- 髮尾 GPU 比較涵蓋八方向 × 有帽／無帽共 16 組，核心、髮根及帽子受保護像素不變，髮尾有可見回擺與收斂。這與 CPU 數值預測分開記錄。
- 原島嶼使用原生按鍵、距離相位和停止保持，外觀及空地位置是明列的驗證設定。正常／慢速分開執行，慢速實際改變模擬時間；不能把影片播放器減速算進來。
- 固定參考線影片是合成圖格對照，正常為一週期／秒、慢播為一週期／四秒；它們不是原生操作影片。分段播放及圖格檢視不聲稱每張電影格均經人工審查，也不聲稱使用者已試玩。

## 重現

依序執行，同一個製作暫存專案不能同時重建；所有 Godot 入口使用隔離存檔。

```text
python tools/hero_2d/register_sources.py
python tools/hero_2d/author_pack.py
python tools/walk_stability/run_audit.py --tag source --raw
python tools/walk_stability/build_registered_walks.py .review/2d-walk-stability-20261016/source assets/characters/walk-stability-v1
python tools/walk_stability/run_audit.py --tag registered
python tools/walk_stability/build_owners.py .review/2d-walk-stability-20261016/source .review/2d-walk-stability-20261016/registered assets/characters/walk-stability-v1
python tools/walk_stability/run_audit.py --tag contracts --test
python tools/walk_stability/check_frames.py .review/2d-walk-stability-20261016/registered
python tools/walk_stability/check_registration.py .review/2d-walk-stability-20261016/source .review/2d-walk-stability-20261016/registered assets/characters/walk-stability-v1
```

來源擷取的 `--raw` 是離線製作入口，不能把已修正圖格再次累加校正。根點圖集生產額外需要 OpenCV／NumPy／Pillow；原生 CI 固定根點契約不依賴 OpenCV。重跑請使用新的 tag，保留前版失敗證據。

[ART-31 驗收](../../pm/Snapland-art/[ART-31]修正全部二維行走像素偏移.md)、[換裝樣本](hero-2d-sample-delivery.md)、[單髮型骨架樣本](hero-2d-hair-sample-delivery.md)。完整遊戲測試由 CI 執行；本輪局部通過不冒充全專案通過。

## 本機隔離試走入口

已更新的原島嶼可由 `build/ART-31-Preview/Play-Island.cmd` 開啟；髮尾限定樣本用同資料夾的 `Play-Hair-Sample.cmd`。兩個入口各有獨立進度位置，不指向玩家既有存檔。這些是當次本機輸出，不是遠端保存的可執行檔。

原島嶼入口已以普通開啟、保存和正常退出流程檢查，結果為 `PASS: game startup and clean shutdown`；[實際紀錄](../../pm/Snapland-art/images/ART-31-launcher-smoke.log)。打包內容沿用本票已核對的輸出雜湊，沒有將未提交試作混入。
