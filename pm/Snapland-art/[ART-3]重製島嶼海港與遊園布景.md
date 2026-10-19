# [ART-3] 重製島嶼海港與遊園布景

> 狀態：完成

## 內文

### 需求
遊園場景以潮汐紙劇場原創風格補足海港、主廣場、迎賓大道與九區路口的材質、建築、植栽、地標和日夜層次。

### 來源
2026-10-11（Asia/Taipei）使用者要求繼續完善島嶼與小遊戲，改善簡陋美術；研究業界實例而不照抄，建立自己的風格並持續完成本批。

### 驗收條件
- [x] 擴大的海岸有六處可辨立體地標、岩岸與遠景；模型、植栽、材質及夜燈經本輪原生畫面實際檢視。
- [x] 海港、廣場、迎賓大道均有可辨識地標、材質與前中後景
- [x] 九區路口有各自意象且文字清楚，遊園互動與動線正常
- [x] 日夜與降低動態設定皆可正常遊園並有原生截圖

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

![研究參考](images/ART-3-reference-octopath-ii.jpg)

---

# Commit-1

問題：島嶼原有海港布景缺少鮮明地標、材質層次與日夜氣氛。

改動：沿用「潮汐紙劇場」原創方向重整海港、廣場、迎賓大道與九區入口，並支援降低動態時的場景呈現。

驗收：隔離存檔原生檢查四方向移動、日夜、降低動態及九個入口互動；場景回歸記錄通過。此為原生自動輸入與畫面檢查，不代表玩家試玩。

測試與證據：原生場景／互動檢查 PASS；氣氛與遮擋檢查的三種遮擋測試位置屬審查設定。分辨率 1280×720，另含降低動態畫面。

| 畫面證據 | 說明 |
| --- | --- |
| [海港白天](images/ART-3-dock.png) · [迎賓大道](images/ART-3-avenue.png) · [主廣場日景](images/ART-3-day.png) | 原生畫面截圖 |
| [夜景](images/ART-3-night.png) · [降低動態夜景](images/ART-3-reduced-night.png) | 原生畫面截圖 |
| [九區入口一覽](images/ART-3-gate-harbor.png) · [糖果區](images/ART-3-gate-candy.png) · [天空區](images/ART-3-gate-sky.png) | 靜態畫面；全部九區另有截圖 |

程式交付：[Commit 6e94a6b](https://github.com/deadline314/Snapland/commit/6e94a6bff33644232ca5d121da19d6fb6ddee97b)（分支 `feature/island-first-park`；固定基準 `92e885390967bff3abbde3cf52716076124b1383`）。

### 最新輸出驗證
Windows輸出於Intel Arc B580原生GPU完成圖集、NPC、場景動畫與遮擋資源冒煙檢查，12款場景所需素材均載入，無ERROR；此檢查不代表真人試玩、完整換裝動作、每姿勢或試聽驗收。

### 程式與證據提交
分支：feature/island-first-park。更新至最新main後的本票提交：[d886ba7](https://github.com/deadline314/Snapland/commit/d886ba74574c7a45c0bb233512adfb3e662baa08)。

# Commit-2：完成擴圖的立體布景驗收

本輪針對使用者指出的簡陋場景重新製作海岸層次與六處 3D 地標。燈塔有三層環廊、欄杆和風向標；鐘亭、修帆所、觀星銅環、玻璃溫室與水車各有自己的輪廓和道具。岩壁、草頂、林隙及海上遠島讓空間逐段展開，維持原十二款遊戲、角色與九區入口。

首輪陶瓷岩壁、屋頂方向及擋住地標的植栽畫面拒收並保留；修正後已實際查看各目的地、既有廣場、白天、夜間與降低動態夜景。遠岸燈具會實際照到路面及人物，沿用活動燈光上限；降低動態停止水車但保留照明。

原生 Compatibility／llvmpipe 最終靜格 exit 0、0 ERROR；原生環線六處觀察與回碼頭成功，141.7 秒／10 FPS 影片完整解碼並看過七個抽樣，沒有宣稱人工完整播放、音樂試聽或角色動畫整票完成。地圖、遮擋、日夜與含兩條回程的真實物理往返四項局部驗證通過。既有海港、九區入口及日夜／降低動態證據仍保留；本輪結案範圍為場景布景，角色與完整光影品質依 ART-17／18、ART-1 接續。

[本輪七方研究與設計](../../design/runtime/coastal-exploration-expansion.md) · [原生環線影片與量測](../Snapland-main/[MAIN-11]完善迎賓大道探索動線.md) · [最終原生執行紀錄](images/ART-3-coast-20261020-engine.log)。場景程式已整合主線 [0ec93bd](https://github.com/deadline314/Snapland/commit/0ec93bd92ae0611c236c4aeaa1b0a04bedb341a7)。

| 原生畫面 | 證據 |
|---|---|
| 前後海岸 | [原版](images/ART-3-coast-20261020-before-west.png) · [最終版](images/ART-3-coast-20261020-west.png) |
| 拒收中間畫面 | [錯誤岩壁](images/ART-3-coast-20261020-rejected-west.png) · [錯誤溫室](images/ART-3-coast-20261020-rejected-garden.png) |
| 六處地標 | [修帆所](images/ART-3-coast-20261020-loft.png) · [鐘亭](images/ART-3-coast-20261020-bell.png) · [燈塔](images/ART-3-coast-20261020-lighthouse.png) · [觀星庭](images/ART-3-coast-20261020-north.png) · [溫室](images/ART-3-coast-20261020-garden.png) · [水車](images/ART-3-coast-20261020-wheel.png) |
| 日夜與降低動態 | [既有廣場](images/ART-3-coast-20261020-plaza.png) · [燈塔夜景](images/ART-3-coast-20261020-lighthouse-night.png) · [水車降低動態夜景](images/ART-3-coast-20261020-wheel-reduced-night.png) |
