# 票票 K1 靜態比較與退件紀錄

日期：2026-10-12。證據包固定基準：`909356b551f280810f860417b1629fa2b5398d45`；分支：`feature/island-first-park`。

**透明清理與完整全身的靜態檢查通過，K1 姿勢因身份與像素風格不一致退件。** 本次保存的是 Root 實際查閱的兩張原生靜態比較圖、執行 log 與唯讀像素量測，不是動畫、換裝或遊戲試玩驗收。候選不加入正式角色 atlas／manifest，ART-17 維持進行中。

## 製作與驗收界限

K1 v2 是內建 imagegen 的編修候選。透明清理由使用者已授權的本機 ComfyUI 核心 CPU 圖像節點執行：只處理 alpha，沒有載入模型或進行本機模型 GPU 生成。原生 GPU 僅用於顯示、擷取並比較三张單一全身姿勢。證據包不包含服務程序、工作環境列印或資料庫備份。

比較圖使用實際 1280×720 視窗：核准站姿 `ticket/idle/front/0`、核准扶鏡框 `ticket/idle_gesture/front/1` 與 K1 清理候選。前兩者透過既有動畫圖庫取得 normalized texture，各以一次量得的 alpha≥64 可見高度設定比較倍率；K1 使用固定 `200/1011`，不是依整張畫布 fit-to-bounds。三者均為 200px 核心身高，鞋底基線 540px，完整手腳留在畫面中。這是單張姿勢的顯示比較尺度，不是逐幀動畫縮放。

保存的 measurements 記錄**實際截圖基準**為 `63e2d06df43382be860cafafdf2d40eff308692e`。本證據包從固定 `909356b` 建立並保存原件，沒有在新基準重跑 GPU；兩個基準的用途分開記錄。

![Root 實際查閱的 cream 原生靜態比較](../../pm/Snapland-art/images/ART-17-K1-static-comparison-cream.png)

![Root 實際查閱的 ink 原生靜態比較](../../pm/Snapland-art/images/ART-17-K1-static-comparison-ink.png)

## 四項主要身份／像素差異

下列輪廓、比例與畫風觀察來自 Root 實際查看上述原生 PNG，不是 alpha 報表自動產生的美術結論。

1. **體型與頭身比例**：同 200px 身高下，右欄 K1 肩、躯幹更窄，露出的小腿更長。由 bbox／倍率可算核准站姿整體寬約 118px、K1 約 106px；整體寬亦受手位影響，不能單靠這個寬度判定身體比例。原生畫面中的體型變瘦仍是明確退件原因。不同來源解析度本身不構成身高漂移證據。
2. **髮束與像素團塊**：核准稿有較厚實的碎髮階梯邊、塊狀明暗與不規則髮束；K1 變成較流暢的大髮束、長渐層與插畫線邊。縮到遊戲顯示高度後，仍像縮小插畫而非原角色的像素團塊。
3. **臉、眼睛與鏡框**：K1 臉部相對較小、眼睛更圓，鏡框和瞳孔的比例與核准稿不同。扶外側鏡腿的手位清楚且沒有遮住鼻口，但正確手位不能替代身份一致性。
4. **鞋形與衣物細節**：K1 靴頭較圓、鞋身較細，寬白踝圈和金色方扣更顯眼；核准稿是較寬厚的靴子和較克制的細節。原稿已有小五金與淺色踝部細節，本次不宣稱整個配件憑空新增。

## 透明清理與唯讀像素核對

核心 CPU workflow：反轉載入遮罩取得 alpha，以 `alpha>32/255` 取核心，擴張 2px，再乘回原 alpha 並依節點的反向遮罩規則合回 RGB。尺寸與 RGB 均保持；全體低 alpha 被直接硬閾值刪除的做法未採用。

| 檢查 | 結果與界限 |
|---|---|
| 原／清理圖尺寸 | 都是 1024×1536。 |
| RGB 改變 | 0px；透明清理沒有重畫人物。 |
| alpha 改變 | 24632px；整體最大減量 16，不能說全部只減 1。 |
| 原 alpha≥64 核心 | 355645px 中 925px 變動，減量全為 1；與浮點量化截斷相符，未驗證節點內部 tensor 轉換。 |
| 原 alpha≥128 | 全部 353818px 完全保留。 |
| 完全清成透明 | 13168px，原 alpha 最高 16。 |
| 核心 bbox | alpha16／32／64／240 邊界都不變；alpha64 為 `[258,311,796,1322)`。 |
| 完整透明邊界 | 原 alpha1 bbox `[0,51,1000,1482)`；清理後 `[256,308,798,1325)`，四邊 12% 通過。 |
| 實際顯示 | Root 查看 cream／ink 原生 PNG，透明輪廓與全身完整通過；人物身份／畫風退件。 |

2px 擴張只按像素距離判斷，理論上仍可能移除離核心較遠的低透明度合法細邊；不能從 bbox 不變推論每個被刪像素都是光暈。本次合成與原生靜態圖的觀察支持輪廓清理通過，不延伸為動畫或全部後續姿勢的保證。

原生 log 記錄 exit 0／PASS、0 個 ERROR，另有一次直接讀取圖片不適合匯出用途的 WARNING。這是審查 fixture 的讀圖限制，沒有將它消音，也沒有宣稱打包驗收。未見 ObjectDB／resource leak 診斷。log 的使用者工作樹絕對路徑以 `[workspace]` 取代，其餘文字保留；來源與保存版本 SHA-256 差異在證據索引明列。

## 本次 Root 實際查閱的四個新來源

本節只記本次 Root 實際查閱的四個官方頁／原始碼來源。ART-17 原有研究來源及 Commit-3 的六來源退件研究沿用原票與原文件，不宣稱本次重新閱讀，也不加入第五個無關來源。

| 官方來源 | 本次閱讀用途與採用界限 |
|---|---|
| [ComfyUI nodes_mask.py](https://github.com/Comfy-Org/ComfyUI/blob/master/comfy_extras/nodes_mask.py) | 核對 InvertMask、ThresholdMask、GrowMask、MaskComposite 的遮罩處理；採核心遮罩加安全邊，不把它視為身份或動作生成。 |
| [ComfyUI nodes_compositing.py](https://github.com/Comfy-Org/ComfyUI/blob/master/comfy_extras/nodes_compositing.py) | 核對 JoinImageWithAlpha 的反向遮罩合成，避免把透明／不透明語義接反；只處理 alpha，不重畫 RGB。 |
| [Aseprite Color Mode](https://www.aseprite.org/docs/color-mode/) | 核對 RGB／RGBA 與索引色的差別；本次 PNG 以 RGBA alpha 評估，不從隱藏 RGB 判斷實際顯示。 |
| [Aseprite Transparent Color](https://www.aseprite.org/docs/transparent-color/) | 核對透明色與索引色語義，避免混淆 palette 透明索引和本次 RGBA 邊緣。這是閱讀紀錄，不是已使用 Aseprite 手繪動畫。 |

## 下一步的最少重畫

保留原核准 `ticket/idle/front/0` 為 K0 身份與站姿母圖；以同一核准全身姿勢只局部重畫畫面右側袖臂、肘腕和扶外側鏡腿的手，以及必要的遮擋區。核准 `idle_gesture/front/1` 用作手部／像素處理參考。維持原頭髮、臉、鏡框、胸徽、躯幹、腿、靴、包的像素與比例，維持接地；不以失敗 K1 作唯一母圖再生成 K0，也不旋轉貼上拆出的肢體。

下一張仍先以相同 200px 身高原生並排比較身份與輪廓。若局部修正仍改動頭、躯幹或鞋，停止擴展影格。即使新單張通过，仍須完整過渡、正常／慢放、自然重心與換裝同步驗收，不能由本次兩張靜態比較勾選 ART-17 動畫條件。

## 保存索引

[原生比較量測](../../pm/Snapland-art/images/ART-17-K1-static-measurements.json)、[原生 log（工作樹路徑去識別）](../../pm/Snapland-art/images/ART-17-K1-static-native.log)、[清理前 v2](../../pm/Snapland-art/images/ART-17-K1-static-source-v2.png)、[清理後候選](../../pm/Snapland-art/images/ART-17-K1-static-alpha-clean.png)、[Comfy workflow](../../pm/Snapland-art/images/ART-17-K1-static-comfy-workflow.json)、[Comfy execution](../../pm/Snapland-art/images/ART-17-K1-static-comfy-execution.json)、[原 alpha 量測](../../pm/Snapland-art/images/ART-17-K1-static-alpha-measurements.json)、[唯讀逐像素核對](../../pm/Snapland-art/images/ART-17-K1-static-pixel-audit.json)、[逐檔來源／保存雜湊索引](../../pm/Snapland-art/images/ART-17-K1-static-evidence.json)。
