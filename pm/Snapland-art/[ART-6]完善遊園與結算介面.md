# [ART-6] 完善遊園與結算介面

> 狀態：進行中

## 內文

### 需求
遊園介面、遊戲入口與结算沿用潮汐紙劇場風格，強化層級、收藏獎勵與鍵盤焦點。

### 來源
2026-10-11（Asia/Taipei）使用者要求繼續完善島嶼與小遊戲，改善簡陋美術；研究業界實例而不照抄，建立自己的風格並持續完成本批。

### 驗收條件
- [x] 遊園 HUD、遊戲入口、結算與收藏頁風格一致且層級清楚
- [x] 核對的模態頁面中，鍵盤與滑鼠操作可用，文字及控制項在常見視窗範圍內可見且不裁切
- [x] 主要介面有實際查看的原生截圖

### 測試流程
1. 查看票內研究來源、參考圖與實際觀察。
2. 啟動隔離存檔的原生遊戲，操作本票相關場景，核對驗收條件與截圖。
3. 切換日夜或降低動態、重開相關畫面，確認動線、文字、互動與獎勵正常。

---

# 跟其他票的關係

- Blocks：無
- Blocked by：無
- Related：ART-3、ART-4、ART-5、ART-6、SG-14

---

# 研究與參考

[本批設計與實際查閱觀察](../../design/runtime/visual-polish.md)。學習分層材質、日夜光影、清楚操作主體與一致的物料語言，重新設計 Snapland 的海港意象；參考圖不當遊戲素材。

![研究參考](images/ART-5-reference-crafted-world.png)

![研究參考](images/ART-5-reference-warioware.png)

---

# Commit-1

問題：遊園 HUD、入口、結果與收藏頁需要統一視覺層級，讓操作資訊、獎勵和焦點容易分辨。

改動：整理紙劇場介面風格，加入遊戲資訊、相片結果、收藏冊、成就、任務、設定與對話畫面。

驗收：HUD 與設定畫面經檢視；原生輸入在 800×600 與 1280×720 核對衣櫃／設定模態內操作控制項，邊界未裁切且鍵鼠回應通過。此結論限於核對頁面與尺寸，不代表所有介面均完成人工可及性審查。

測試與證據：layout-v4 原生檢查在 800×600 與 1280×720 驗證衣櫃及設定控制項邊界、鍵鼠操作；根任務查看兩張 800×600 截圖。這是介面檢查，不是玩家試玩。

| 畫面證據 | 說明 |
| --- | --- |
| [遊園 HUD](images/ART-6-hud.png) · [遊戲資訊入口](images/ART-6-game-info.png) | 原生靜態畫面 |
| [拍貼結果](images/ART-6-result.png) · [收藏冊](images/ART-6-album.png) · [收藏新增](images/ART-6-album-earned.png) | 獎勵和收藏畫面 |
| [任務](images/ART-6-quest.png) · [成就](images/ART-6-achievements.png) · [設定](images/ART-6-settings.png) · [設定 800 視窗](images/ART-6-settings-800.png) · [對話](images/ART-6-dialogue.png) | 原生靜態畫面 |

程式交付：[Commit 1e0b177](https://github.com/deadline314/Snapland/commit/1e0b177fc6e0827e0794fb22f53d4947d7d073e1)（分支 `feature/island-first-park`；固定基準 `92e885390967bff3abbde3cf52716076124b1383`）。

### 最新輸出驗證
Windows輸出於Intel Arc B580原生GPU完成圖集、NPC、場景動畫與遮擋資源冒煙檢查，12款場景所需素材均載入，無ERROR；此檢查不代表真人試玩、完整換裝動作、每姿勢或試聽驗收。
