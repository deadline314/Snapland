# 短髮與捲髮的島上動態

2026-10-17，ART-34。保留既有二維角色、全身八方向步態與固定 280×360 畫布。未新增生成人物，不把玩家偏好推測當成調查結果。

## 本輪閱讀與取捨

以下六方官方文字已開啟閱讀，另重讀 Spine 權重與 Celestial Circus 的資產分層說明；沒有播放來源影片。

| 來源 | 核對與採用 | 限制／不採用 |
|---|---|---|
| [Spine Physics constraints](https://eu.esotericsoftware.com/spine-physics-constraints) 及 [Celestial Circus](https://ja.esotericsoftware.com/spine-examples-celestial-circus) | 受約束髮束的慣性、回復、阻尼、重設及長度；髮束分層與隱藏重疊。 | 不能把同一設定套所有髮長，也不讓整顆頭受物理影響。原 spine-physics 舊網址讀取失敗，改讀正式 constraints 頁。 |
| [Godot Jiggle](https://docs.godotengine.org/en/stable/classes/class_skeletonmodification2djiggle.html) 及 [Cutout](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html) | 關節可各自覆寫剛性、阻尼；逐幀與局部骨架可共存。 | 沿用已有穩定彈簧，不在本輪更換求解器。Cutout 文件註明未完整更新 4.7。 |
| [Unity Sprite Swap](https://docs.unity3d.com/Packages/com.unity.2d.animation@10.0/manual/CharacterParts.html) | 保持相對 pivot、骨架與替換部件定位。 | 不按每款髮型可見外框重新置中。 |
| [Aseprite Slices](https://www.aseprite.org/docs/slices/) | 明確畫布、pivot、部件資料。 | 不把 trim 後外框當角色根點。 |
| [Phaser Textures](https://docs.phaser.io/phaser/concepts/textures) | 圖集 frame 與來源畫布資料分開。 | 不依來源剪裁尺寸獨立偏移播放。 |
| [Spriter 換圖](https://www.brashmonkey.com/spriter_manual/swapping%20the%20image%20of%20a%20sprite.htm) | 替換圖需有相容 pivot。 | 不用獨立時計追頭部動畫。 |

## 實作決定

離線匯出正式合成器的已定位髮圖透明度，扣除最後覆回的臉與前景遮擋，形成明確歸屬資料。定位計算與正式合成共用，避免另寫一套近似縮放。人工逐方向量測根、末端與選區，再編譯三束互不重疊的取樣區。執行時不以 RGB 判斷髮色；色彩、膚色、帽子與衣服不影響歸屬。

只在全部 200 個走路／待機姿勢聯集的外輪廓四像素帶讓出可動部分，內側保留原圖重疊。捲髮下緣部分蓋在背包及肩上，該處沒有可供運動的隱藏原畫，因此維持固定，改選可獨立活動的外側髮束。短髮動態增益 0.52、捲髮 0.72，各束再調整；這些是依本專案比例設定的起始值，品質以像素與正常／慢速錄影驗證，並非官方建議的通用參數。

各款使用自己的八方向描述與歸屬。除原走路來源外，也核對髮圖圖集、斜向清單與頭部歸屬來源；來源變動則安全保留完整人物，不能繼續套舊切割。降低動態直接使用原圖。既有其他種族的部件仍保留完整原圖，避免把尚未核對的耳朵、角或尾巴宣稱已覆蓋。

## 重現

使用隔離存檔與 `SNAPLAND_HAIR_AUTHOR_DIR` 執行 `tools/island_avatar/export_hair_ownership.gd`，取得兩款八方向的實際合成與已定位髮層。歸屬快照存入 `island-hair-alternate-owners-v1.json`，`python -m tools.island_avatar.import_hair_ownership --input-dir <export-directory>` 編譯歸屬，再以 `python -m tools.hero_2d.author_alternate_hair` 重建兩款綁定描述。原畫與圖集雜湊均保留。

驗收結果、實際觀察方式及雲端環境限制隨交付寫入 ART-34，不能以這份方法文件替代驗收。

髮圖依合成器相同的 alpha < 0.4 門檻計算可見像素指紋；Godot 匯入器會填補低透明邊緣的隱藏 RGB，該區原本就被合成器清除。原始檔雜湊也保留，並未用變更門檻接受可見像素誤差。髮尾的完整合成 RGBA 會因後方肩膀擺動而有微小變化，因此定位回歸比較已定位的純髮層，而非把合理的半透明疊色差異誤判成偏移；真正輸出仍另逐像素比對原合成器，要求休止與收斂誤差為零。

## Windows 清單換行

原環境是 Windows；素材清單若經 Git 轉成 CRLF，原本直接核對檔案位元組會把相同內容誤判成來源變更，導致替換髮型動態停用。JSON 清單以 LF 正規化後核對指紋，二進位 PNG 與可見像素檢查維持原規則；其他內容改動仍會拒絕。離線歸屬指紋也採相同換行規則。

已將兩份實際依賴清單改為 CRLF，重新從乾淨專案依既有 Windows Desktop 設定匯出 PCK；再從沒有原始素材的隔離探測目錄完成 96 組及額外 200 格的原生渲染比較。另有 Windows 換行後完整製作資料重建相同的回歸。這是文字格式與資源包回歸，沒有宣稱在 Windows 4.7.2 EXE 執行。
