# [MAIN-3] 建立可執行遊戲與原生驗證

> 狀態：進行中（base SHA：c1b7b19）

## 內文

### 需求

讓 Snapland 可由 Godot 啟動，並在 CI 真正執行遊戲測試。

### 來源

使用者於 2026-10-11（Asia/Taipei）要求從上島開始實作主區域、迎賓大道全部小遊戲及共用系統；其他園區先做路口。每項實作前研究業界實例並保存圖例；本票是可執行第一版，品質以實際驗收為準。

### 驗收條件

- [x] Godot 可啟動遊戲且遊戲腳本無解析錯誤。
- [ ] CI 執行實際遊戲測試，缺少引擎或測試不能略過。

### 測試流程

1. 啟動遊戲，進入本票內容，依畫面提示實際操作。
2. 核對本票每項驗收條件，測試返回、重試、重開與輔助情境。
3. 保存原生畫面截圖與局部測試摘要；無法確認的項目保持未勾選。

---

# 跟其他票的關係

- Blocks：MAIN-4、MAIN-5、MAIN-6、MAIN-7、ART-1、ART-2、MIC-1、ST-2、ST-3、SG-2、SG-3、SG-4、SG-5、SG-6、SG-7、SG-8、SG-9、SG-10、SG-11、SG-12、SG-13
- Blocked by：無
- Related：MAIN-1、SG-1、ST-1

---

## 開始基準

c1b7b19；feature/island-first-park。

# Commit-1

## 內文

問題：先前只有設計資料，無法啟動遊戲。

改動：現在可開啟上島與迎賓大道，缺少引擎或測試時會明確失敗。

驗收：本機7組runtime與Windows GPU啟動／退出通過。遠端CI已觸發但因帳戶付款／支出限制未啟動，該条件保持未勾選。

分支：`feature/island-first-park`；開始基準：`c1b7b19`；[程式 commit](https://github.com/deadline314/Snapland/commit/f2d6b84919a91d534082660a12aec5a9b44eaa2c)。

### 測試結果

| 項目 | 結果 |
|---|---|
| 受影響局部驗證 | 本票相關runtime與主場景整合通過 |
| 原生畫面 | GPU擷取並查看；程式化操作驗收 |
| 遠端CI | 帳戶限制，工作未啟動；未重試 |

### 研究與圖例

[核心與成就研究](../../design/runtime/core-research.md)。圖例為審閱參考，不是本作遊戲素材或試玩證據。

![業界參考](../Snapland-art/images/ART-1-reference-octopath.jpg)

### 截圖

![本票原生畫面](images/MAIN-3-startup.png)

[整組驗收、票況與存檔事故紀錄](../first-playable-delivery.md)。

Related：MAIN-18（驗收入口辨識與失敗收束）。
