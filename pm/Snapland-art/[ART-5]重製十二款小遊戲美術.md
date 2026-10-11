# [ART-5] 重製十二款小遊戲美術

> 狀態：進行中

## 內文

### 需求
十二款小遊戲有符合玩法的完整場景、角色道具與目標視覺，消除空背景與純幾何佔位感。

### 來源
2026-10-11（Asia/Taipei）使用者要求繼續完善島嶼與小遊戲，改善簡陋美術；研究業界實例而不照抄，建立自己的風格並持續完成本批。

### 驗收條件
- [x] 十二款遊戲均有主題場景與具體道具、清楚的操作目標
- [x] 各款遊戲的視覺變化符合玩法且不遮住命中範圍
- [x] 十二款原生操作與成功結果均有畫面證據

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

問題：小遊戲需要各自清楚的場景、目標與道具，避免空背景讓操作對象難以辨識。

改動：十二款小遊戲各自配置符合玩法的場景與道具，並整理結果拍貼畫面，使目標保持清晰。

驗收：原生自動輸入逐一啟動十二款遊戲並進入成功結果；所有路線和結果檢查通過。這是自動化驗收，並非玩家試玩成功。

| 畫面證據 | 說明 |
| --- | --- |
| [遊戲 01](images/ART-5-game-01.png) · [結果 01](images/ART-5-result-01.png) | 原生靜態畫面 |
| [遊戲 05](images/ART-5-game-05.png) · [結果 05](images/ART-5-result-05.png) | 原生靜態畫面 |
| [遊戲 09](images/ART-5-game-09.png) · [結果 09](images/ART-5-result-09.png) | 原生靜態畫面 |

全十二款路線與對應結果截圖：[01](images/ART-5-game-01.png)／[結果](images/ART-5-result-01.png)、[02](images/ART-5-game-02.png)／[結果](images/ART-5-result-02.png)、[03](images/ART-5-game-03.png)／[結果](images/ART-5-result-03.png)、[04](images/ART-5-game-04.png)／[結果](images/ART-5-result-04.png)、[05](images/ART-5-game-05.png)／[結果](images/ART-5-result-05.png)、[06](images/ART-5-game-06.png)／[結果](images/ART-5-result-06.png)、[07](images/ART-5-game-07.png)／[結果](images/ART-5-result-07.png)、[08](images/ART-5-game-08.png)／[結果](images/ART-5-result-08.png)、[09](images/ART-5-game-09.png)／[結果](images/ART-5-result-09.png)、[10](images/ART-5-game-10.png)／[結果](images/ART-5-result-10.png)、[11](images/ART-5-game-11.png)／[結果](images/ART-5-result-11.png)、[12](images/ART-5-game-12.png)／[結果](images/ART-5-result-12.png)。

程式交付：[Commit b1a7637](https://github.com/deadline314/Snapland/commit/b1a76372a84756bb40f1e4682d3751d966d68aa5)（分支 `feature/island-first-park`；固定基準 `92e885390967bff3abbde3cf52716076124b1383`）。

### 最新輸出驗證
Windows輸出於Intel Arc B580原生GPU完成圖集、NPC、場景動畫與遮擋資源冒煙檢查，12款場景所需素材均載入，無ERROR；此檢查不代表真人試玩、完整換裝動作、每姿勢或試聽驗收。

### 程式與證據提交
分支：feature/island-first-park。更新至最新main後的本票提交：[53a9dc3](https://github.com/deadline314/Snapland/commit/53a9dc3e15be759e647209c623aaef72c61918f0)。
