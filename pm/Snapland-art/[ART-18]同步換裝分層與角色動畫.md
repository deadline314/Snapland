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


# Commit — 2026-10-17 防止缺件混穿與修正側身換色

固定接續基準：main `1baf7dd098b3f01635c76f6364ca6db224468837`；分支：`codex/wardrobe-silhouettes`。

### 問題

底層仍會逐格選擇不完整的服裝候選，壞格才穿回原衣；珊瑚外套的避免背心特例只在正式主角入口，沒有形成共通防線。另在原生全身抽樣發現：正面內衣的保護區也套到側身，選珊瑚款後袖子中心仍大片是藍色。

### 改動

四件正式外套明確沿用原外套換色，不再選用歷史背心候選。真正輪廓替換先檢查整套必要姿勢；有缺件就保留原完整身體及對應位置，不在不同影格混穿。必要清單包含目前分開保存的八向行走，不能刪掉一整個缺少的動作就變成「完整」。

左右側走路／待機共 24 格有各自核對過的衣料標記，袖子與衣襬可正確換色，保持原畫與步態。其他動作的衣料處理不由這 24 格推論為完成；不同服飾輪廓仍依本票未勾選條件驗收。

### 研究與流程

本輪重新閱讀 Spine、Unity、Aseprite、Godot、Universal LPC、Spriter 六方資料，實際看過並保存兩張官方靜態插圖。採同一姿勢進度、明確衣物身份、製作端標記與整套檢查；方法、取捨、來源與界線見[服裝完整性研究](../../design/runtime/outfit-completeness.md)。

先檢查完整 148 格的衣料草稿，再逐格看原身體、相機、內衣與衣袖。全姿勢版本會誤標鏡片，亦有抬手／跨胸袖子漏標，已拒收；只採左右側走路與專用待機完整的 24 格。本流程的共通規則已整理回 User-guide，未把自動輸出當成批准原件。

![Spine 的服飾分類原圖，非遊戲素材](images/ART-18-reference-skins-20261017.png)
![Spine 的固定處與衣襬控制原圖，非遊戲素材](images/ART-18-reference-dress-20261017.png)

兩張為文件內靜態原始圖，並非整頁截圖或動畫播放驗收。[來源與雜湊](images/ART-18-reference-provenance-20261017.json)。

### 局部驗證

| 範圍 | 結果 |
|---|---|
| 整套服裝完整性 | 314 項通過；另一動作壞格、整段缺少、來源／定位／數值損壞皆保留原衣，修復重載可恢復 |
| 側身衣料 | 24 格、三個替換色共 72 組通過；標記外像素差為 0，三髮型外露衣料及捲髮遮擋另有獨立見證 |
| 製作工具 | 4 項回歸通過；重新輸出原畫後重建的衣料資料與正式檔逐位元一致 |
| 隔離 PCK | 沒有原始 PNG 的入口通過 316 項完整性檢查及 72 組衣料檢查 |

執行為 Linux Godot 4.7；以上無頭／PCK 的來源與像素檢查不代表原生動畫主觀品質、Windows 4.7.2 EXE 或整島驗收。

### 製作端檢視

洋紅色為衣料標記，下一列為珊瑚配色預覽，皆為製作端診斷圖，不是原生遊戲截圖。24 格均已實際檢視。

![右側完整行走衣料與配色](images/ART-18-side-materials-20261017-01.png)
![右側待機及左側行走衣料](images/ART-18-side-materials-20261017-02.png)
![左側其餘行走及待機衣料](images/ART-18-side-materials-20261017-03.png)

票況：進行中。本輪不把外套換色或安全性修正當成不同服裝輪廓完成。


## 2026-10-17 原生、固定引擎與輸出補驗

程式與製作圖提交：[b84746a](https://github.com/deadline314/Snapland/commit/b84746aea2329bc467ed3050faad85e739840357)。本輪使用正式島上角色與原步態，沒有採用全姿勢衣料拒收稿。

| 範圍 | 實際結果 |
|---|---|
| 正常速度原生 | 14 組真實按鍵移動、16 項檢查通過；包含行走時衣袖／手部保護區 RGBA 相同及停步配色見證 |
| 真正四分之一模擬時間 | 14 組移動、14 項檢查通過；使用已保存的固定配色見證版本，沒有擴稱為新的整區 RGBA 檢查 |
| 實際檢視 | 兩段 1280×720／30 FPS 影片解碼為 93 張全身樣本、9 張聯絡圖，全部實際看過；沒有宣稱連續播放每個編碼格 |
| Godot 4.7.2 | 取得與 CI 相同的官方 ed1daf0bf，乾淨匯入、服裝兩項、動畫庫、步態保留、八向步行與 432 格待機共六項局部測試通過，0 ERROR |
| Godot 4.7.2 匯出 PCK | 來源 PNG 隔離後，316 項完整性與 72 組衣料檢查通過；4.7 PCK 亦通過相同探測 |
| 完整 CI | 衣料修改前的 main `1baf7dd` 實際失敗：設計缺 SG-1 目錄，runtime 在既有腿部樣本來源中位數斷言失敗並逾時；未刪斷言、改選擇器或算成通過 |

原生仍是 Godot 4.7／llvmpipe，環境解析度與特效有明示降成本 fixture，人物合成維持 280×360。4.7.2 補驗是 Linux 來源與 PCK，沒有聲稱 Windows EXE、完整光影、原機器即時效能或真人試玩。暫停選單短暫遮住一個影片樣本，另保留原始角色像素 PNG。

![修正前：珊瑚款側身仍大片藍色](images/ART-18-side-20261017-before-blue-pixels.png)
![修正後：原生珊瑚側身與原姿勢](images/ART-18-side-20261017-normal-coat-pixels.png)
![正常速度實際島上取景，右側為人物合成預覽；另附 280×360 原始像素圖](images/ART-18-side-20261017-normal-world.png)

[正常速度影片](images/ART-18-side-20261017-normal.mp4) · [真正慢速影片](images/ART-18-side-20261017-quarter.mp4) · [正常原生報告](images/ART-18-side-20261017-normal-audit.json) · [慢速原生報告](images/ART-18-side-20261017-quarter-audit.json) · [完整驗收範圍與 SHA](images/ART-18-side-20261017-verification.json)。

[正常全身抽樣](images/ART-18-side-20261017-normal-frames-03.png) · [慢速全身抽樣](images/ART-18-side-20261017-quarter-frames-03.png) · [固定 4.7.2 輸出探測](images/ART-18-side-20261017-pack-4.7.2-material-report.json)。兩份 PCK 本身未提交或發布，票內保存來源與雜湊。

### 拒收例與品質防線

[鏡片／跨胸衣袖誤標草稿](images/ART-18-side-20261017-rejected-full-camera.png)、[抬手漏標草稿](images/ART-18-side-20261017-rejected-full-raised-arms.png) 與[第二輪修訂仍有誤標](images/ART-18-side-20261017-rejected-full-v3.png) 均為製作端拒收圖，未作為遊戲素材。乾淨匯入曾抓到型別推斷錯誤，獨立像素檢查另抓到 JSON 數字型別使有效標記未載入；修正後重新執行全部側身矩陣與兩版隔離 PCK。

本輪保存實際流程與結果，整票仍為進行中；不同服飾輪廓及完整動作品質繼續按原驗收判定。
