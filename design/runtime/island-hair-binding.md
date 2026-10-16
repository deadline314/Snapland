# 島上角色定位與髮根綁定

2026-10-17（Asia/Taipei），ART-33。本輪先閱讀下列官方文件，再檢查 `372df05` 的實際角色入口。另實際檢視 Unity 的替換手掌錯位與修正兩張原圖；不宣稱看過教學影片或操作過其他引擎。

## 方法比較與選擇

| 一手來源 | 本輪實際核對 | 對 Snapland 的決定 |
|---|---|---|
| [Aseprite Slices](https://www.aseprite.org/docs/slices/) | Slice 的畫布範圍、pivot 與 JSON 匯出。 | 固定角色畫布與根點；外框大小不能決定每格根位置。 |
| [Spine 基本觀念](https://esotericsoftware.com/spine-basic-concepts)、[權重](https://eu.esotericsoftware.com/spine-weights) | 父子骨頭繼承變換、slot 分離遮擋順序、權重將部件綁到骨頭。 | 固定頭部根骨，只讓髮束末端有權重；遮擋順序與綁定分開管理。 |
| [Godot Cutout Animation](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html) | 父子部件、pivot、獨立 Z 順序與逐幀動畫可共存。文件註明部分教學未更新到 4.7。 | 保留原全身逐幀步態，僅在透明 2D 畫布上疊加局部髮束；不拆腿重造步態。 |
| [Unity Sprite Swap](https://docs.unity3d.com/Packages/com.unity.2d.animation@10.0/manual/CharacterParts.html) | 未綁相同骨架的替換圖可能因不同 pivot 跳位；自訂 pivot 的修正範例。 | 換裝與當格姿勢共用定位，不能各自重新置中；不靠獨立計時器追頭。 |
| [Phaser Textures](https://docs.phaser.io/phaser/concepts/textures) | Frame 的原始尺寸、裁切區、`sourceSize`、`spriteSourceSize` 與 pivot。 | 裁切若使用，必須還原原畫布與偏移；本輪直接保留 280×360 原畫布。 |
| [TexturePacker 對齊說明](https://www.codeandweb.com/texturepacker/knowledgebase/keep-animation-alignment-with-trim) | 搜尋回傳的官方說明：框架還原原始尺寸及 anchor 後可維持對齊；完整頁面開啟失敗。 | 不把 trim 外框重新置中當作動畫定位；不把此工具當素材自動修復器。 |
| [Spriter 換圖](https://www.brashmonkey.com/spriter_manual/swapping%20the%20image%20of%20a%20sprite.htm) | 替換圖依各自 pivot 對位，需在製作時設定相容位置。 | 製作時量測並保留方向專屬綁點，不以每張生成圖的中心代替。 |

這些是工具方法的比較，並非七款遊戲的實際試玩。既有 3D 角色方案已被否定，本輪不改角色身份、比例或畫風，也不生成新人物。

Unity 的實際範例中，換圖後手掌與手腕分離；修正相對 pivot 後才接合。以下是官方方法參考的原圖連結，未納入 Snapland 遊戲資產；檢視的是兩張靜態圖，不是示例動畫。

![Unity 官方換圖錯位範例](https://docs.unity3d.com/Packages/com.unity.2d.animation@10.0/manual/images/Pivot_Scene_GestureOffset.png)

![Unity 官方 pivot 修正後](https://docs.unity3d.com/Packages/com.unity.2d.animation@10.0/manual/images/Pivot_Scene_Fixed.png)

## 現況與處理

ART-31 已修正以每格鞋子重算中心造成的原島嶼跳位；ART-32 已接回固定頭頸的待機與眨眼。本輪先重跑原角色逐像素回歸。獨立髮尾樣本不能直接搬進島上：它使用另一套髮圖與座標，必須以島上真正使用的原圖建立綁定。

以八方向現有原畫及已審閱的頭髮像素歸屬，離線標定外側三束短髮。每束的根、末端與取樣區有明確資料；只從原頭髮歸屬中選取，不在執行時辨色、補頭皮或重新生成角色。原件雜湊不同時保留完整原人物。

髮束與靜態頭部保留原畫重疊區，僅在輪廓邊緣四像素範圍讓出可動髮尾；這是接縫下的原畫重疊，不是把斷裂抹糊。原圖內部也有微透明度，因此隔離畫布以原始 RGBA 覆寫保留區，而非重複 alpha 疊色；輸出仍為原 Sprite3D 使用的直通色彩與透明度。臉、帽子、相機、肩背及四肢維持原逐幀像素。帽子以實際配件透明度保護，不能用顏色相近來猜。骨架只影響獨立髮束，最後合成為原 Sprite3D 的同一張貼圖，沿用光照、接地、透視與建築遮擋。

動態由人物實際水平位移與同一物理時間驅動。換方向、換裝與瞬移清除舊動量；暫停凍結；停止後收斂。降低動態／停用直接回傳原圖。無繪圖裝置的 headless 執行保留原圖，不能拿該模式當作骨架畫面驗收。

## 覆蓋與驗收界線

本批先接微風短髮、人類外觀的島上步行與待機，含四種帽狀態及已測試的潮汐／珊瑚服飾配色。拍照、招呼、坐姿等單次動作保留其完整原畫與遮擋；其他種族部件、其他髮型和 NPC 仍使用完整原人物。ART-34 另追其他髮型的專用輪廓與動態，不能拿本款權重直接套用。

驗收比較原合成圖像的 RGBA 與骨架輸出的真正渲染像素，要求休止時完全一致、移動差異只在明定髮尾範圍、停止回到原圖，並以故意偏移一像素的負例證明能抓出錯誤。島上還須正常與真正四分之一模擬時間的輸入、起停、轉向、帽髮、拍照、暫停及降低動態回歸；完成情況與證據記在 ART-33，文件本身不是完成證據。

雲端使用 Godot 4.7／llvmpipe，與先前 Windows Godot 4.7.2 不同。32 組原始像素比較使用 Forward+ 的實際 2D 渲染；島上正常／四分之一速度則明列降低環境渲染成本的 fixture：3D scale 0.25、停用環境 SSAO／glow／太陽陰影，人物 280×360 合成不降解析度，另有原圖像素 inset。保留原 Sprite3D 材質、方向光與遮擋程式，但不把此錄影當作完整光影品質或原硬體即時效能驗收。
