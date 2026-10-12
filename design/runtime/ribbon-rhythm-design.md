# 彩帶節拍：舞台、節奏與視覺來源

## 目標與差異

`game-006` 是正面觀看的 2.5D 小型歌舞廳演出。玩家依八拍完成左右踩步、躍起與兩次按住的彩帶橫掃；節拍時間線同時展示當前動作與接下來兩拍。它與噴泉跳拍的近距離水池、三次單一跳躍目標不同：本作把左右位移、短促跳躍、持續輸入、夥伴鏡像和完整舞台彩帶編成一段表演。

舞台以深色天鵝絨簾幕、扇形簾楣、黃銅台口、斜向木地板與踏腳燈構成。四盞固定燈的色溫隨 dawn、noon、dusk、night 改變；光束不移動、不晃動分數。地板的三組弧形踏點分開左、中、右落腳區。演奏者和鏡像夥伴是畫面中心，彩帶在身後沿方向、跳躍圈和持續橫掃畫出不同弧線。彩帶只在動作完成或按住期間出現，沒有通用粒子噴發。

全身角色使用 AvatarRenderer 的既有資產。實際可用的動作為八方向 walk、front jump、front wave，以及舊動作圖集的 idle 和 celebrate；manifest 明確只為 jump 提供 front 方向，wave 也只有 front。沒有 dance 動作。左／右步使用實際 walk 方向，躍起使用八張 authored front jump，持續橫掃則使用既有 front wave 靜態姿勢，讓彩帶承載掃動。夥伴沿用玩家外觀，鏡像繪製並換成對比服裝。角色不會播放新造的舞蹈姿勢，也不把鏡像夥伴說成另一套動畫。

## 八拍輸入與計分

| 拍 | 輸入 | 表演 | 留按 | 重拍 |
|---:|---|---|---:|:---:|
| 1 | 左 | 左踩步 | 點按 | 是 |
| 2 | 右 | 右踩步 | 點按 | 否 |
| 3 | 跳 | front jump | 點按 | 否 |
| 4 | 左 | 左側彩帶橫掃 | 0.34 秒 | 是 |
| 5 | 右 | 右踩步 | 點按 | 否 |
| 6 | 跳 | front jump | 點按 | 是 |
| 7 | 右 | 右側彩帶橫掃 | 0.40 秒 | 否 |
| 8 | 左 | 收步 | 點按 | 是 |

八拍時間固定，首拍在 1.02 秒，後續每 0.94 秒一拍。一般判定窗為拍心前後 0.27 秒，拍心 0.105 秒內是精準；輔助模式把可接受窗放寬到 0.46 秒、留按長度誤差放寬到 0.24 秒。每次正確精準得 100 分，合拍得 60 分，重拍再加 25 分。八拍中至少六拍正確才算一般成功；漏拍、錯方向、過早輸入或提早放開都會記錯。錯方向不會自動跳過本拍，玩家可在本拍結束前重新輸入。

惡魔成功需要八拍全數精準、所有重拍正確、零錯誤且未開輔助。輔助只放寬輸入與留按容差；提示仍是靜態動作圖示、文字、重拍標籤和進度線，玩家必須親自輸入八拍。沒有動作的等待只能以失敗結束，不會自動得分或勝利。模型每次只接受最多 0.25 秒的時鐘推進，拒絕非有限時間值並快取穩定 snapshot。

## 操作畫面與可讀性

設計座標為 1280×720；上方 130px 保留標題、分數、八拍進度和事件，下方 80px 保留 A/D、方向鍵、Space 與滑鼠按鍵。台口操作區限制在 y=142..628；角色的頭頂和鞋底均在操作區內。上下縮放保留比例並置中，滑鼠座標先換回設計座標。左右、跳躍的形狀按鈕有直接訊號，也可用方向鍵或 A/D、Space／上鍵／W；按下和放開各自傳出訊號，支援留按。

降低動態時停止彩帶生長、角色循環幀與所有裝飾動作。固定在畫面上的當前目標、後兩拍、方向形狀、重拍標記、剩餘進度、分數與留按量尺仍提供相同資訊。命中後的彩帶停在當前完成弧線，無震動、閃白或自動演出。

## 一手資料與取捨

以下連結均為遊戲作者、發行者、平台或引擎的官方頁面；六張 ART-21 核准圖例已逐張實際檢視。這是頁面文字和靜態畫面的桌面研究，沒有把它描述成試玩，也沒有從靜態圖推斷動畫。

| 實際閱讀／檢視 | 可直接支持的觀察 | 在 Snapland 採用的原則 | 明確不移植 |
|---|---|---|---|
| [Nintendo：Super Mario Party Jamboree minigames](https://www.nintendo.com/ph/switch/a7hl/minigame/index.html)；[ART-21 圖例](../../pm/Snapland-art/images/ART-21-ref-mario-party.png) | 官網把橋面落腳、相機取景、影子重疊等規則分開說明；圖例可見分割視窗、準心、時間和比分的位置。 | 讓動作圖示與空間目標直接對應，資訊放在舞台外緣。 | 不複製四人分割畫面、角色、美術或小遊戲規則。 |
| [Panic / Playdate：b360](https://play.date/games/b360/)；[ART-21 圖例](../../pm/Snapland-art/images/ART-21-ref-b360.png) | 官方頁描述帶旋轉變化的打磚塊玩法，列出方向鍵／曲柄控制；圖例將狹長遊玩區與分數欄分開。 | 一個明確的輸入對應一種可讀路徑；保留緊湊的計分層級。 | 不採用黑白小螢幕、狹小比例、旋轉或高速難度。 |
| [Lucas Pope：Return of the Obra Dinn 設計說明](https://obradinn.com/media/prerelease.html)；[ART-21 圖例](../../pm/Snapland-art/images/ART-21-ref-obra-dinn.png) | 作者說明 1-bit 抖動、固定解析度及替代輸出模式，並指出長時間觀看可能不適。 | 媒材和觀看舒適度需一起決定；主要資訊不押在複雜動態上。 | 不採用 1-bit、抖動、低解析或第一人稱調查畫面。 |
| [Drool：Thumper](https://thumpergame.com/)；[ART-21 圖例](../../pm/Snapland-art/images/ART-21-ref-thumper.png) | 官方將其描述為高速、有物理感的 rhythm-action，並提到 2D 與 VR 表現。 | 節奏類遊戲的鏡頭節奏應服從動作特性；本作以穩定正面舞台承載多種手勢。 | 不採用高速前進、暴力主題、眩光或 VR 鏡頭。 |
| [Ben Esposito / Annapurna：Donut County](https://donutcounty.com/)；[ART-21 圖例](../../pm/Snapland-art/images/ART-21-ref-donut-play.jpg) | 官方用「地洞」物理規則概括遊戲，圖例的場景物件和可互動洞口共同構成視線中心。 | 讓規則可見於場景：本作以腳步、木地板和實際彩帶軌跡表現動作。 | 不移植洞口、吞噬、物理下墜或其角色美術。 |
| [Enhance：Lumines Arise](https://lumines.game/)；[ART-21 圖例](../../pm/Snapland-art/images/ART-21-ref-lumines-play.jpg) | 官方說明方塊、分數和音樂節拍線如何連動；畫面把盤面、計分與舞台環境同時呈現。 | 以節拍時間線帶動視覺事件；音效可由 `note_played_serial` 對接，必要節奏仍可看見。 | 不採用霓虹街景、背景影像、強烈閃爍或其方塊玩法。 |
| [Microsoft Xbox Accessibility Guideline 103：多感官線索](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/103) | 平台指引建議重要遊戲線索使用多種感官管道，避免只靠聲音或只靠畫面。 | 音樂節拍有時間線、方向形狀和重拍文字，音訊不是唯一判斷來源。 | 不把震動或聲音作為必要輸入回饋。 |
| [Microsoft Xbox Accessibility Guideline 104：字幕與提示](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/104) | 平台指引說明重要非語音音訊可用文字或畫面資訊補充。 | 重拍、錯拍、長按和結果都有可見文字，不用聽音效才能理解。 | 不加與遊戲操作無關的字幕層。 |
| [Godot CanvasItem 文件](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html) | 2D CanvasItem 可在 `_draw()` 中繪製，並以 `queue_redraw()` 安排更新。 | 舞台幾何、透視木板、簾幕、燈束與絲帶路徑以原生 2D 繪圖組合。 | 不把效果交給額外外掛或全螢幕後處理。 |
| [Godot InputEvent 文件](https://docs.godotengine.org/en/stable/classes/class_inputevent.html) | 引擎把輸入表達為事件；按下和放開是分開的狀態。 | view 分別發出 `action_pressed` 和 `action_released`，讓留按時長可被模型判定。 | 不以自動節拍播放代替實際輸入。 |

## 實作介面與驗證界線

模型 API：`reset(assisted, time_phase)`、`press_action(action)`、`release_action(action)`、`step(delta)`、`snapshot()`，另有 `retry()`。snapshot 提供固定八拍、節拍音訊序號、兩拍預告、評級、得分、錯誤、成功條件與完成彩帶。view API：`configure_avatar(appearance, equipped)`、`update_frame(snapshot, time_phase, reduced_motion)`、`screen_to_design(point)`、`playfield_rect()`、`bounds()`、`avatar_bounds_for_pose(pose)`，並發出按下／放開訊號。

局部 headless 測試涵蓋過早與錯向、按住重複、短留按、重試重置、完美八拍、輔助模式仍須輸入、閒置不勝、快取、時鐘上限和非有限時間；view 測試涵蓋設計座標、縮放、所有選用姿勢邊界、鍵鼠訊號及降低動態時保留的提示。這些自動測試只證明模型與座標／訊號契約；沒有被描述成原生遊戲試玩、畫面品管或 GPU 驗收。
