# ART-12: NPC 站位與個性待機研究

## 來源與取捨

| 一手來源 | 實際觀察 | 對 Snapland 的取捨 |
|---|---|---|
| [Godot AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html) | 一般用途的動畫播放器能管理多個動畫資源；屬性更新在 process frame；比 Tween 適合較有時序的動畫 | 用一組註冊完成後不再增長的 loop tracks 管理活動節奏；不用每個 process frame 建 Tween/Animation |
| [Godot AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) | 狀態機與混合圖可在較複雜的動畫間混合，仍引用 AnimationPlayer 的動畫 | 目前像素角色活動是少數離散 routine，先不用額外混合圖或骨架；素材成長後再評估 |
| [Godot SpriteBase3D](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html) | Sprite3D 是 3D 場景中的 2D texture；`shaded` 讓燈光照到 sprite；billboard 用於對鏡頭朝向，shadow pass 上 billboard 的面向有注意事項 | 保留既有 Sprite3D 與像素圖集、nearest filtering、受光材質；避免用無可見效果的 world-yaw 軌道假稱角色轉身 |
| [Godot NavigationAgent3D](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html) | 需先有 navigation data；父節點仍須每個 physics frame 以路徑結果移動。RVO avoidance 也有計算成本 | 目前公園沒有 NavigationRegion/NavigationMesh；三位 NPC 先安排短、可預期的路線與空間，不加重型全場尋路 |
| [Godot Navigation Regions](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationregions.html) | NavigationRegion 以 NavigationMesh 定義可走區，需與 navigation map 同步 | 不為只有三個、固定布景角色建立整個導航網格；活動使用有限範圍並遠離主通道 |
| [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html) | 角色移動由腳本控制；常見碰撞移動透過 physics step 的 `move_and_slide()` | 若驗收真要 NPC 走動，使用低速、可控的地面 waypoint/物理步進，而非讓 billboard Sprite3D 任意漂浮；路線不可侵入玩家通行區 |
| [Godot Label3D](https://docs.godotengine.org/en/stable/classes/class_label3d.html) | 3D 文字可選受光；停用 depth test 時會畫在所有物件前面 | 名牌留在固定角色附近並避免 `no_depth_test`；走動 NPC 的互動位置/標籤錨點要跟角色一起更新 |
| [Game Accessibility Guidelines: Avoid sudden movement](https://gameaccessibilityguidelines.com/avoid-any-sudden-unexpected-movement-or-events/) | 指引建議避免非必要的突然、大幅動作與事件 | 降低動態時關掉位移、跳躍與大幅動作，但保留角色清楚的基礎姿態和必要互動提示 |
| [Aseprite Tags](https://www.aseprite.org/docs/tags/) | 命名動畫區間可以標出幀序列與循環 | 新的 pose/frame 如果要加入，按 `idle`、`service`、`dance`、`walk`、`wave` 等明確命名，不把一次性動作塞入待機 loop |

## 站位與活動草案

現有角色位置為售票員票票 `(-5, 0, 7)`、小角 `(-3, 0, -15)`、阿浪 `(3, 0, -15)`。後兩位落在迎賓大道中央且接近拱門輪廓。建議改至大道兩側、例如票票 `(-5, 0, 7)`、小角 `(-5.5, 0, -23)`、阿浪 `(5.5, 0, -23)`；最終座標須以原生相機畫面與 walkway collider 實測，不可僅以座標推定無遮擋。

活動控制器使用 `register_actor(sprite, role, frames, activity_root, interaction_point, seed)` 註冊。每組四張 `Texture2D` frame 被直接重用，不在逐影格建立 `Image`、`Texture` 或 Tween；一個 scene-scoped `AnimationPlayer` 播放 role-specific texture/route 軌道。根節點置於地面，Sprite3D 保持當前約 `y=1.2` 的視覺高度，Label3D 與接觸影子都作為 root 子項。

票票在固定服務位置保持原 idle pose，約每六秒播放一次短的遞票/服務四幀；小角以約 3.33 fps 循環四個腳底固定的舞姿；阿浪以 5 fps 走姿沿開放側道往返，活動 root 僅沿本地 x 軸移動 ±0.6 m 並在回程翻面。四幀如包含側步需保持原像素腳底列一致。已有的局部 shader gesture 可以與原生 pose 結合，但不再額外加全身 bob/rotation。

互動點由世界的 `points` 記錄靜態 `position`；註冊時傳入原有 Dictionary reference，控制器按移動 root 的 global position 更新同一記錄與原始偏移。Nameplate 和接觸影子隨 root 移動，不覆寫玩家碰撞。固定短路線不使用 NavigationAgent，因數量少且場景沒有 navigation data；實際路線仍需原生確認兩端沒有撞建築或擠壓玩家通道。

場景降低動態時 AnimationPlayer 停止並還原角色初始 idle texture、flip、root 與互動點；必要的人物/臉部可讀性保留。對話/選單把活動暫停時同一玩家暫停，返回後繼續；角色或場景退出時停用其軌道並還原基準。重入場景時建立新管理器並只註冊一次。

管理器與 headless 測試已支援四幀/API、路線上下限、腳底高度、互動點更新、模態暫停、降低動態與清理；測試從 root 生成並保留來源的 `npc-actions-v1.png` 圖集及 JSON 區域表載入 `AtlasTexture`，並檢查各角色四幀共用畫布與快取。現有區域表仍需確認連通透明邊界與腳底對齊；完成後還需以原生畫面/短片確認票票手持道具貼手、臉與腳不變形、阿浪不被建築遮住且玩家能自由通行。研究與 headless 都不是遊戲畫面驗收。
