# [ART-18] 同步換裝分層與角色動畫

> 狀態：進行中

## 內文

### 需求
衣服、帽子、頭髮與配件能分開選擇，又能隨主角站姿、待機、走路與各種動作自然同步。不同衣物有自己的輪廓；髮尾、衣襬與背帶適度隨動，帽子、頭髮、手和道具前後關係正確。

### 來源
2026-10-12 使用者要求研究業界如何處理主角服飾、配件與頭髮的動畫，認為可能需分開處理；此前要求紙娃娃購買／自訂服飾、基礎外觀免費無限更換，高像素 HD-2D 與角色一致性。

### 驗收條件
- [x] 比較至少六個來源的逐幀分層、骨架換裝、立體烘焙與次要動作，附來源、觀察和參考圖。
- [ ] 不同衣物能改變服裝輪廓，換裝不是只替同一件外套換色；基礎外觀仍可免費無限更換。
- [ ] 身體、服飾、頭髮、帽子與配件在同一動作進度和八方向下對齊；停走、轉向及動作中換裝不跳位、不露缺口。
- [ ] 帽子遮髮、前後髮束、背包背帶、手與道具的前後順序合理，沒有穿透眼睛、身體或飄離手掌。
- [ ] 次要動作只出現在合適部件，幅度與延遲合理；腳、臉、硬帽與相機保持形狀，不用整身伸縮代替呼吸。
- [ ] 逐衣物／動作／方向覆蓋檢查能指出缺件；素材不完整時安全顯示完整角色，不靜默套用錯誤方向。
- [ ] 原生換裝、正常速度、慢放、降低動態與輸出版本有可審閱證據。

### Research
已實際閱讀八方一手來源：Aseprite、Spine、Unity、Godot、Motion Twin、Universal LPC、Kenney、BrashMonkey。不同方法、閱讀段落、目前素材缺口、逐角色覆蓋與採用理由見[角色動畫與換裝研究](../../design/runtime/character-animation-wardrobe.md)。

![逐幀素材分層時間軸](images/ART-18-reference-aseprite-layers.png)
![可組合服飾參考](images/ART-18-reference-spine-mix-match.png)
![動作與部件分別輸出參考](images/ART-18-reference-lpc-generator.png)

三張皆為實際核對的網站參考截圖，未作為遊戲素材。文字閱讀與靜態截圖不算動畫播放驗收；未觀看教學影片。

### 測試流程
1. 主角在待機、走路、拍照、招呼和慶祝時逐一更換頭髮、帽子、服飾與配件。
2. 逐一觀察八方向以及不對稱服飾／配件，查看遮擋、銜接與完整輪廓。
3. 比較有風、無風、停止與轉向，確認只有適合部件產生次要動作。
4. 檢查缺少服飾姿勢時的完整角色預設、降低動態與輸出版本，附局部結果及原生證據。

---

# 跟其他票的關係

- Blocks：ART-17
- Blocked by：無
- Related：MAIN-8、ART-7、ART-8、ART-14、ART-15、ART-16、ART-34

---

# 開始

固定基準：affb6b1。分支：feature/island-first-park。需求登記已推送：[22e4fcb](https://github.com/deadline314/Snapland/commit/22e4fcb)。

# Commit-1

### 問題
服裝目前主要換色，部件缺少完整動作覆蓋與遮擋規則。

### 改動
記錄換裝動畫分層研究與驗收要求。

### 驗收
比較八方一手資料，實際核對並保存三張參考截圖；記錄逐幀分層、共用時序、逐格錨點與遮擋順序的取捨。服裝輪廓和整套動畫尚未製作，驗收保持未勾。

### 測試結果
研究文件與三張參考截圖實際核對，沒有聲稱完成遊戲動畫。

分支：feature/island-first-park。

### 截圖

[原生或研究證據：ART-18-reference-aseprite-layers.png](images/ART-18-reference-aseprite-layers.png)
[原生或研究證據：ART-18-reference-lpc-generator.png](images/ART-18-reference-lpc-generator.png)
[原生或研究證據：ART-18-reference-spine-mix-match.png](images/ART-18-reference-spine-mix-match.png)

### 程式與證據提交
分支：feature/island-first-park。更新至最新main後的本票提交：[3f87c63](https://github.com/deadline314/Snapland/commit/3f87c63ff57b93ae451276657651a0d6e922d8bb)。

## 2026-10-14 接續基準

固定開始 SHA：`4d0a2a814860e54243dd116bed54c564233c0aa0`。本輪接續既有角色完整動畫、服裝同步與島嶼聲音驗收；使用者要求持續修正實際問題，不能把階段素材或局部驗證當成整島完成。

## Commit — 2026-10-14 修正珊瑚外套的跨動作身份

**問題：** 衣櫃顯示珊瑚紅外套，但走路是外套，待機、招手與跳躍卻切成未完整製作的背心，角色衣著隨動作突變。

**改動：** 珊瑚紅外套在全部現有姿勢保持外套身份、配色與完整身體，不使用只有部分動作的背心。未批准的背心走路候選没有加入正式遊戲；本輪仍不把外套換色當成不同服飾輪廓已完成。

**驗收：** 本機檢查現有正面動作全部影格及八方向行走的首末影格，珊瑚與原色外套保持同一完整輪廓；髮帽貼合、四個坐姿及真實八方向行走回歸通過，0 ERROR。實際 Main 使用珊瑚外套完成八方向行走、完整招手／拍照／互動及動作中換裝，原生 exit 0、0 ERROR；主 Session 檢視六張全身姿勢聯絡圖。影片已保存供正常／慢放審閱，未以靜態圖宣稱全套動畫品質完成。

### 測試結果

| 項目 | 結果 |
|---|---|
| 原有角色功能與跨姿勢外套身份 | 通過；保留原有身份共用與快取上限檢查 |
| 髮帽貼合／坐姿／真實八方向行走 | 3 項局部檢查通過，0 ERROR |
| 珊瑚外套原生來源檢查 | 技術條件通過，完整招手／拍照／互動影格實際呈現 |
| 候選素材 | 側向背心候選跨格；重試又改變姿勢，均未採用 |

### 截圖與影片

![珊瑚外套跨姿勢實際畫面](images/ART-18-coral-jacket-consistency-v1-contact.jpg)

[正常速度](images/ART-18-coral-jacket-consistency-v1-normal.mp4) · [四分之一速度](images/ART-18-coral-jacket-consistency-v1-quarter.mp4) · [完整全身圖](images/ART-18-coral-jacket-consistency-v1-start.png) · [原生報告](images/ART-18-coral-jacket-consistency-v1-report.json) · [來源與編碼紀錄](images/ART-18-coral-jacket-consistency-v1-verification.json)

本輪開始基準：`4d0a2a814860e54243dd116bed54c564233c0aa0`；分支：`feature/island-experience`；票況：進行中。不同服裝完整輪廓、全部動作與輸出版本換裝仍需完成，相關驗收未勾選。

本輪程式與原生證據已推送：[48a8ab9](https://github.com/deadline314/Snapland/commit/48a8ab9580508dbb11cae6d269766d0512201091)。


# Commit — 2026-10-15 修正前斜閉眼換髮

### 問題
前斜方向的閉眼姿勢換成短髮／捲髮後會留下原瀏海、抬高髮頂，或露出頭皮缺口；這使待機與換髮不同步。

### 改動
同向中立姿勢只提供定位，表情仍取閉眼原稿。替換髮型回到原稿髮頂，補色只落在與臉相通的開口；缺少可靠定位或臉部開口時保留完整來源髮型。

### 驗收
兩個前斜方向的閉眼睫毛像素完整保留，沒有混入睜眼表情；短髮／捲髮的額頭、頭皮與鞋底局部回歸通過。Main 原生正常／四分之一模擬速度中檢查預設、珊瑚外套／草帽及短髮／花飾／精靈三組外觀。正常 60 張全身逐姿勢及編碼影片抽幀已檢查；這是新增五向待機的局部換裝回歸，整票驗收仍保持未勾選與進行中。

### 測試結果

| 項目 | 結果 |
|---|---|
| 閉眼原稿、頭皮、髮頂與鞋底回歸 | 先重現錯誤後通過，0 ERROR |
| 缺少定位／無臉部開口 | 先重現錯誤後保留完整原髮，0 ERROR |
| 既有八向走路髮帽與所有膚色／種族局部矩陣 | 通過；局部結果見 ART-17 的本批驗收摘要 |
| 原生五向待機與三組外觀 | 正常／慢速來源條件通過；ffprobe 30 FPS |
| 實際打包 | 五向預設外觀、重入、降低動態與暫停通過；普通包正常退出 |
| 完整遊戲套件 | 留 CI，本機未執行 |

### 截圖與影片

![前斜閉眼與短髮換裝](images/ART-17-directional-idle-20261015-diagonal-normal-cels-2.jpg)
![真正慢速模擬的閉眼姿勢](images/ART-17-directional-idle-20261015-diagonal-quarter-video-frames.jpg)

[正常影片](images/ART-17-directional-idle-20261015-diagonal-normal.mp4) · [四分之一模擬速度](images/ART-17-directional-idle-20261015-diagonal-quarter.mp4) · [完整局部驗收與隔離存檔證據](images/ART-17-directional-idle-20261015-verification.json)。

分支：`feature/island-experience`；固定開始 SHA：`ce86d3b`。本批與 ART-17 共用必要的閉眼姿勢修正，程式與證據提交：[3c6ae27](https://github.com/deadline314/Snapland/commit/3c6ae27c071290d12fc2f952ef036319f19257ce)。票況：進行中；沒有將外套換色當作不同衣物輪廓完成。
