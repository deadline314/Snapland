# [MAIN-3] 建立可執行遊戲與原生驗證

> 狀態：完成

## 內文

### 需求

讓 Snapland 可由 Godot 啟動，並在 CI 真正執行遊戲測試。

### 來源

使用者於 2026-10-11（Asia/Taipei）要求從上島開始實作主區域、迎賓大道全部小遊戲及共用系統；其他園區先做路口。每項實作前研究業界實例並保存圖例；本票是可執行第一版，品質以實際驗收為準。

### 驗收條件

- [x] Godot 可啟動遊戲且遊戲腳本無解析錯誤。
- [x] CI 執行實際遊戲測試，缺少引擎或測試不能略過。

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


# 2026-10-20 結案：實際CI入口與拒絕略過

本輪已確認主線可實際啟動，Godot4.7.2乾淨匯入exit0、0ERROR；三尺寸原生介面與Main實際鍵鼠流程另有ART-23～26及MAIN-14證據。原程式f2d6b84已在origin/main；早期「只有feature／CI帳戶未啟動」不是目前狀態。

[主線b1c7405的CI](https://github.com/deadline314/Snapland/actions/runs/39327871481)：引擎安裝、結果／入口契約、實際來源／髮根／待機檢查均執行成功，再執行真正Godot runtime並正確回報測試失敗。full-suite的設計與Python工作成功。這證明CI確實執行，不是全套遊戲綠燈；後段接帽素材差異仍由MAIN-2／ART-17／SG-20處理。

用未改動的正式腳本做兩個獨立反例：不存在的GODOT_BIN返回1；包含project.godot但缺正式測試的隔離小專案也返回1，沒有NOT APPLICABLE或成功略過。23項入口／完成契約另已通過，正式92項及原90／240秒上限不變。

[缺引擎反例](images/MAIN-3-runtime-guard-20261020-missing-engine.log) · [缺測試反例](images/MAIN-3-runtime-guard-20261020-missing-suite.log) · [實際結果](images/MAIN-3-runtime-guard-20261020-verification.json) · [當前原生尺寸／導覽證據](../Snapland-art/images/ART-23-verify-20261020.json)。本票按「能啟動且CI真的執行、不能略過」結案；其他美術、內容及全域失敗不隨之結案。
