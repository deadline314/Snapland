# [MAIN-2] 建立設計驗證與定時CI

> 狀態：進行中

## 內文

### 需求
讓已交付的設計能持續檢查編號、收藏、任務、連結與一致性；每小時與受影響內容變更時自動執行完整可用測試，局部驗證可獨立執行。

### 來源
使用者於 2026-10-06 的 Snapland 對話要求依業界案例整理的樂趣核心重整設計並按票交付；設計基線見 design/06-roadmap/open-questions.md。

### 驗收條件
- [ ] 園區、小遊戲、劇情與物品有可獨立執行的相關驗證。
- [ ] 完整驗證偵測缺漏、重號、錯誤依賴與收藏鎖死，包含反例檢查。
- [ ] CI 有每小時排程、變更觸發與手動執行，失敗時明確回報。
- [ ] 交付說明區分設計驗證與尚未存在的 Godot 遊戲測試。
- [ ] 有本機驗證與 CI 設定截圖，完成後遠端分支可查。

### 測試流程
1. 閱讀交付規格並逐項對照驗收條件。
2. 執行受影響範圍的設計驗證，確認有效資料通過、錯誤資料能被拒絕。
3. 比對文件與截圖，預期全部條件可追溯且沒有虛報實際遊戲試玩。

---

# 跟其他票的關係
- Blocks：無
- Blocked by：無
- Related：ART-31、ART-18

---



# 2026-10-17 接續：角色來源校準回歸

固定基準：main `dc32c1480301da70c9f2faf0009ad42f1217f17e`；分支：`codex/character-ci-source`。

CI 在既有角色來源校準的固定長度斷言失敗並逾時。本輪先核對固定畫布的已登錄位移與量測標記，保留原斷言及完整來源回退；不以修改預期值、忽略測試或恢復被否定的拆腿動畫處理。

已比較 Godot、Unity、Aseprite、Phaser、libGDX、Spriter 六方的原點、原尺寸、裁切偏移與換件方法，重看既有 Unity 定位前後原圖。[研究與座標契約](../../design/runtime/source-registration-contract.md)。此段是開始與原因紀錄，不是 CI 通過或遊戲試玩。

### 本輪改動與結果

主角原畫已校正，舊量測仍使用校正前座標，造成共同平移後的相對鏈長改變。現依既有來源位移一次轉換量測副本；獨立鞋圖與借用色樣各守自己的座標。來源、根點與正式 2D 步態不改，重建不累加。

Godot 4.7.2 八項局部回歸、真實損壞來源恢復、乾淨匯入、13 項 Python 啟動器檢查通過；舊固定鏈長斷言保留並恢復通過。世界整合確認正式島上沒有拆腿 rig。完整[摘要／雜湊／範圍](images/MAIN-2-source-registration-20261017-verification.json)，[修正前](images/MAIN-2-source-registration-20261017-before-probe.json)與[修正後](images/MAIN-2-source-registration-20261017-after-probe.json)。世界整合有既有材質不支援遮擋的 WARNING，無 ERROR；沒有本輪美術試玩或 Windows 驗收。

MAIN-2 原驗收仍未全完成；SG-1 缺檔不能略過。較新的 ART-18 CI `38965270551` 在舊候選檢視斷言停止，接續另於 ART-18 修復，不宣稱全套 CI 成功。

### Commit

- [f35e341](https://github.com/deadline314/Snapland/commit/f35e3412ce9f92b51d2e796b06aae6e3b77aed1f)：同步量測與已登錄畫布位移，新增獨立座標／重建反例。共通流程已補入 User-guide。
