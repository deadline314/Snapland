# 原畫局部修正與完整依賴重驗

2026-10-21，ART-17；先讀 User-guide。這次是在製作其他方向衣物前發現主角斜前右走路第4格：相機前已有兩隻手，背包下卻另畫了一隻拳頭。先修來源，再做衣物，避免把錯誤烘進新外觀。

## 研究與取捨

延續並重讀[六方換裝製作研究](outfit-completeness.md)，方法適用同一套角色來源／部件同步問題。本輪讀取官方文字，重用此前實際看過、已附票的 Spine 靜態圖；未觀看網站動畫，沒有採用外部人物素材。

| 團隊／資料 | 用在本次的決策 |
|---|---|
| [Godot Cutout](https://docs.godotengine.org/en/stable/tutorials/animation/cutout_animation.html) | 原格與局部附件可共存；保留原本逐格手腳，不改造成整身骨架。頁面標示未更新至4.7，實際API以4.7.2原生驗證為準。 |
| [Spine Skins](https://en.esotericsoftware.com/spine-skins) | 身體、髮與帽維持明確部件身份；換裝前先核對固定原畫。參考圖見原研究，不把整個生成的人物換進來。 |
| [Unity Sprite Swap 10.0.3](https://docs.unity3d.com/Packages/com.unity.2d.animation@10.0/manual/SpriteSwapIntro.html) | 相容骨架與單一播放來源是必要條件，不能讓新外觀各自重新定位身體。最初誤用舊SL前綴URL未成功，之後正確頁面已讀。 |
| [Aseprite CLI](https://www.aseprite.org/docs/cli/) | 區分逐格trim與固定crop。此次只用固定280×360格、指定矩形替換，不依透明輪廓重置中心。 |
| [Spriter Character Maps](https://www.brashmonkey.com/spriter_manual/what%20are%20character%20maps.htm) | 同尺寸及命名利於替換／回溯；保存原格、修正片與對照，而不是整組覆蓋原檔。最初簡化URL未成功，已讀正式手冊頁。 |
| [Universal LPC現行README](https://raw.githubusercontent.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator/master/README.md) | 動作／體型擴充會有覆蓋缺口；修一格不能當成全角色完成。舊fork頁指出搬遷，已跟到現行資料；不採用其角色或授權混合素材。 |

## 原畫與可重建修正

本次沒有採用生成候選的整個人物。本次 imagegen 回傳1106×1422候選，按固定整張尺寸對應280×360後，只取 `[68,218,37,47]`，包含透明RGBA完整替換。原人物不縮放、不平移；頭 `[0,0,280,185]`、腳 `[0,300,280,60]`、相機與兩手 `[115,202,88,55]` 完全保護。採用修正片與提示／候選原圖均保存。

`tools/walk_stability/source_repairs.py` 在離線烘焙的固定root與頭頸處理後重播已審閱修正。修正表逐項保存原格／修正片PNG SHA、輸入／輸出可見RGBA指紋及保護區；重疊、超界、輸入或輸出改動、重複格與未批准狀態均拒絕。原始88張來源不改，重建不會把第三隻手帶回來。這是原畫局部修正，不是執行期猜手／換色／遮住手。

來源格有1566個RGBA像素改變，全部位於指定矩形。實際Godot重新匯入後，矩形外另有72個RGB不同的像素，全是alpha0；沒有矩形外可見色或alpha改變。其餘七格及三髮型其餘21張結果保持原始RGBA。來源指紋整格改變，所以重新登記唯一一格頭部所有權，不放寬指紋。

即使修補位於身體，也重新實際匯出兩種替代髮型的身體alpha聯集與依賴。髮根、髮尾、髮束所有像素及切割範圍逐項證明未變，只有斜前右的身體聯集與其指紋改變。這個步驟不能因「沒有改頭」而省略。

## 實際驗證與證據界線

- 137項Python通過；六組正式角色套件通過，完整渲染器162.65秒小於原240秒、其他原90秒門檻不變。
- 88原始PNG全部與原來源雜湊相同；十二組重建圖集的alpha及不透明RGB與當前正式來源相同，獨立root／原畫四肢稽核通過。第一次編譯在寫輸出前缺少cv2停止，保留記錄；在私人venv恢復`opencv-python-headless==4.13.0.92`後使用同一批來源完成。
- 實際Main以S/D移動，原速與真正Engine.time_scale0.25各14組：三髮型×四帽、降低動態、重建Main；每組觀察八張距離選格、移動至少2單位並停回idle，另驗暫停／恢復。第一組繪製完整世界，其後隱藏3D／HUD，右側鏡像同一個Main的實際Sprite/GPU髮；外觀、開闊位置與續玩狀態是fixture，不冒稱衣櫃UI或全世界光影驗收。
- 原速80.49秒、慢放131.06秒，均exit0／0ERROR。無聲固定20FPS影片分別639格31.95秒、1881格94.05秒，完整解碼並查看28張postdraw畫面及三髮型24姿勢對照，不聲稱連續看完影片或硬體FPS。
- 完整3D逐外觀的第一版在13組後120秒逾時，未完成整體驗收；第二版原速完成、慢放停步檢查失敗。第三版保留時間／像素／距離門檻，以有界等待觀察真正停步，避免用十個渲染frame誤當固定遊戲時間。拒收記錄保留，不把第一次部分圖當通過。
- 玩家乾淨stage的Linux release實際啟動自己的Main、畫出十二款場景並正常退出：25.30秒、0ERROR；獨立PCK用另個乾淨探針專案測三髮型×四帽實際GPU及24組髮型／方向指紋，4.03秒、0ERROR，無散落原PNG、工具或測試。後者由編輯器載入玩家PCK，與真正release啟動分開記錄。非Windows、真人遊玩、試聽或衣櫃完整驗收。

先前ART-18 `d39de0f` 的遠端CI已核對實際93次Godot執行／93次完成、128項Python、五個設計範圍，名稱／順序／原時間門檻一致。它涵蓋新衣袖來源檢查，不涵蓋本次後續修圖或MAIN-9建置修正；本次局部與新CI另記。

[全部範圍、來源與SHA](../../pm/Snapland-art/images/ART-17-source-hand-20261021-verification.json) · [修正前三髮型與修正後](../../pm/Snapland-art/images/ART-17-source-hand-20261021-three-hair-before-after.png) · [可重現來源與拒收記錄](../../pm/Snapland-art/images/ART-17-source-hand-20261021-sources.zip)。ART-17仍依原完整角色條件進行中。
