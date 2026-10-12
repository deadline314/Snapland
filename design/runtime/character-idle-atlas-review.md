# ART-17 票票待機圖集研究與退件紀錄

本文保留不等距動畫圖集的實際閱讀紀錄、v1 候選量測及原生畫面審查結果。下列技術來源只記錄閱讀正文；未把其影片或插圖描述為已觀看。素材數量、切圖與錨點測試不能取代角色動畫的原生視覺審查。

## 圖集處理方法來源

| 一手來源 | 實際閱讀內容 | 本案取捨 |
|---|---|---|
| [CodeAndWeb TexturePacker：Keep animation alignment with trim](https://www.codeandweb.com/texturepacker/knowledgebase/keep-animation-alignment-with-trim) | 閱讀逐幀裁掉透明邊緣時，如何用原始尺寸與裁切偏移維持動畫位置。未觀看影片或圖片。 | 可讓每幀使用不同完整裁切框，但必須保留對齊資料；不能只交沒有錨點的裸 PNG。 |
| [Aseprite：Slices](https://www.aseprite.org/docs/slices/) | 閱讀 slice 的範圍、名稱、自訂 pivot 與 JSON 匯出說明。未觀看影片或圖片。 | 使用逐幀可審閱範圍與支點，不以等分格線猜切。 |
| [Unity 6.2：Automatic slicing](https://docs.unity3d.com/6000.2/Documentation/Manual/sprite/sprite-editor/automatic-slicing.html) | 閱讀正文第 125–136 段的透明區域切片、自訂或共用 pivot。未觀看影片或動畫。 | alpha 分析只作尋找主體的工具；弱透明邊緣仍需人工檢查，不能以自動切片代表美術驗收。 |
| [Godot：AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html) | 閱讀 region、filter_clip、margin 和整數區域設定說明。未觀看影片或圖片。 | 保持整數切框、格間隔離及共同畫布；沿用既有角色載入器，不新增另一套 runtime。 |
| [Phaser：Textures](https://docs.phaser.io/phaser/concepts/textures) | 閱讀 spritesheet 固定格與 atlas 個別框的差異、sourceSize、spriteSourceSize、anchor/pivot 範例，包括腳底 pivot。未觀看影片或動畫。 | 採個別完整框配共同畫布和腳錨點概念；不逐幀縮放角色。 |
| [Spine：Region attachments](https://esotericsoftware.com/spine-regions) | 閱讀 region 矩形附件、sequence 同尺寸要求，以及以 key 指定序列幀的說明。未觀看影片或動畫。 | 原始圖集可採不同區域，但輸出角色畫布與腳錨需固定；不扭曲全身來假造姿勢。 |

以上六項是正文閱讀紀錄，並非對來源動畫或圖像的審美驗收。角色動畫整體方向另見[角色動畫與換裝研究](character-animation-wardrobe.md)，其中列出八個不同來源的實際閱讀範圍；該文件既有的閱讀紀錄與參考截圖保留不動。

## v1 候選量測

候選原始圖為 1047×1503 RGBA、16 個人物。以 alpha≥64 找到 16 個互不相連的主體區域，再把每個框擴至包含身體周圍三像素內的弱 alpha 邊緣；框為 174–185×295–305 px，鄰框至少留 69 px 水平、62 px 垂直間隔。原始圖逐位元複製，SHA-256 為 `7f08663951befc803aa6976cdb156e09dfab1d6a504d0ddd9991218fe29f5d1b`。逐格區域及量測記錄隨證據包的 JSON 保存。

沿用既有角色圖集載入器的可變區域、共同 `source_scale=0.572`、320×460 畫布和腳底 y=448 錨點，headless 測試通過 90 個結構／定位檢查。這只證明區域和定位可讀取，不證明姿勢品質。

| 比較對象 | Alpha≥64 身高 | 平均值與幀間範圍 | 畫布 padding 左／右／上／下 |
|---|---:|---:|---:|
| 舊票票 idle | 386–389 px | 387.50 px，差 3 px | 40–45／47–52／59–62／9–12 px |
| 新票票 idle_look_queue v1 | 380–393 px | 387.31 px，差 13 px | 43–50／42–50／56–68／10–12 px |

候選平均身高與舊待機幾乎一致，但逐幀高度差達 13 px；下方透明邊距只有 10–12 px，低於原始 brief 的 12% padding 目標。腳錨相同不能消除輪廓跳動或接地觀感問題。

## 原生審查與退件

Root 以原生 1280×720 畫面錄製並播放了正常速度與慢速影片至結尾：正常素材 102 格、60 FPS、1.7 秒；慢速素材 342 格、60 FPS、5.7 秒。逐格證據各 16 張，共 32 張，另有 8 張聯絡表。Root 實際查看全部逐格截圖並播放兩段影片；這是美術檢視，不是完整遊戲試玩或四角色驗收。

v1 **退件，不可整合正式圖集或 manifest**：

- 相較已核准身份參考 `ticket-front-actions-v2.png`，新頭髮輪廓較平順、少了原有碎髮，身份輪廓不符參考。
- 新幀身高跳動 13 px，舊待機為 3 px；平均身高相近沒有解決幀間呼吸感不穩。
- 角色看向左右隊伍的意圖不清楚，多數影格仍是相近的中性站姿，原生慢速播放也未呈現清楚完整的待機小動作。
- 腳下 padding 只有 10–12 px，沒有達到 brief 的 12% 邊距目標。

證據檔只用來追溯這次退件，並以 `ART-17-queue-rejected-*` 明確標為未採用。更後續生成或未審內容不納入本紀錄。原始素材、正式角色 atlas、runtime 與 manifest 未由本次交付修改。現有 ART-17 動畫品質與完整覆蓋驗收項目維持未完成。
