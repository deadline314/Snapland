# [ART-7] 製作細緻像素角色與動作

> 狀態：進行中

## 內文

### 需求
島上角色使用細緻、高像素的 HD-2D 美術，保留使用者肯定的海港色彩與有個性的角色表情。換裝在島上可見，加入多方向步行、招呼、拍照、互動與慶祝動作。

### 來源
2026-10-11 使用者肯定兩張角色素材，尤其新版角色更有個性；要求高像素與更多動作。Nintendo Splatoon 開發者訪談強調角色行為與世界概念的一致性；不照抄其角色。研究與使用者選圖存入本票相關設計與圖片。

### 驗收條件
- [x] 島上角色細節來自高解析像素素材，具清楚髮型、眉眼與服裝輪廓。
- [ ] 四方向步行及招呼、拍照、互動、慶祝可在原生畫面觀察。
- [x] 衣服、帽子與膚色改變可在島上與衣櫃預覽辨識。
- [x] 日夜與降低動態下角色仍清楚，換裝不改移動碰撞。
- [ ] 素材缺失有可辨識安全預設，實際打包後素材可用。

### 測試流程
1. 原生視窗走四方向，觀察步態與新動作。
2. 切換不同外觀與服飾，檢查島上及預覽一致。
3. 打包版本檢查角色素材與日夜畫面。

---

# 跟其他票的關係
- Blocks：無
- Blocked by：無
- Related：MAIN-8、ART-8、ART-4

---

# 開始與研究

固定基準：4c320b9d6eef219d5ea90a9b96cb09ad7a68b3a5。研究與使用者選圖見 [本批設計](../../design/runtime/wardrobe.md) 與 [提示詞指南](../../design/runtime/art-prompt-guide.md)。

---

# Commit-1

問題：島上人物及換裝需要更清楚的高解析像素細節和可辨識的動作。

改動：加入多方向角色姿勢與招呼／拍照／互動／慶祝的正面單格姿勢，以及基礎外觀顏色和帽子預覽。四種動作姿勢不是動畫；目前服飾以換色呈現，尚非完整分層服裝。

驗收：原生角色姿勢與基礎外觀／帽子預覽已檢查；不宣稱四種動作已形成動畫或服飾已具完整分層。素材封裝與缺失素材安全回退尚未完成，因此最後一項保持未驗收；完整動作與服裝分層由 ART-17／ART-18 跟進。

測試與證據：原生全身姿勢 fixture 共 27 視角通過，其中包含三位 NPC 多姿勢及主角八方向待機、行走／拍照／招手／慶祝姿勢；根任務查看正常頭部與全身比例。這些是靜態構圖檢查，不是完整待機組或四種動作動畫。素材封裝未驗收。

| 畫面證據 | 說明 |
| --- | --- |
| [角色細節](images/ART-7-character-approved.png) · [畫廊臉部](images/ART-7-gallery-face.png) · [髮型](images/ART-7-gallery-hair.png) | 原生靜態畫面 |
| [拍照動作](images/ART-7-action-photo.png) · [互動](images/ART-7-action-interact.png) · [招呼](images/ART-7-action-wave.png) · [慶祝](images/ART-7-action-celebrate.png) | 動作靜態畫格 |
| [角色行走預覽影片](images/ART-7-walk-preview.mp4) | 使用者已看過並提出步態意見；不作通過宣稱 |
| [主角全身待機](images/ART-15-sprite-clearance-avatar-idle-front.png) · [行走姿勢](images/ART-15-sprite-clearance-avatar-walk-front_right-5-of-8.png) · [招手姿勢](images/ART-15-sprite-clearance-avatar-wave.png) | 原生全身靜態 fixture；不作動畫完成證據 |

程式交付：[Commit 6eb5644](https://github.com/deadline314/Snapland/commit/6eb5644eae2d10cfc15c7b05be9ead4cb9915b83)（分支 `feature/island-first-park`；固定基準 `4c320b9d6eef219d5ea90a9b96cb09ad7a68b3a5`）。

主角招呼、拍照、互動及慶祝目前各為单張姿勢；完整動作集合由 ART-17 追蹤。服裝目前主要換色，服裝輪廓和分層同步由 ART-18 追蹤，沒有用靜態姿勢或換色視為完整動畫／服裝。

### 最新輸出驗證
Windows輸出於Intel Arc B580原生GPU完成圖集、NPC、場景動畫與遮擋資源冒煙檢查，12款場景所需素材均載入，無ERROR；此檢查不代表真人試玩、完整換裝動作、每姿勢或試聽驗收。
