# 四時段自由切換與時段拍貼

MAIN-9 將日夜切換擴充為可隨時選擇的四個時段。這是固定時段外觀切換，不是讓真實時鐘推進、跳過遊戲日或改變遊戲時限。所有遊園活動仍可在任何時段進行。

## 研究與採用

以下官方遊戲支援、更新說明、引擎文件與平台文件已閱讀實際頁面；觀察只用於設計比較，不宣稱本作已具備來源中的全部系統。

| 來源 | 實際內容 | Snapland 的取捨 |
|---|---|---|
| [Nintendo《Animal Crossing: New Horizons》官方介紹](https://www.nintendo.com/us/whatsnew/animal-crossing-new-horizons-free-update/) | 島上時間與季節跟隨現實，清晨捕蟲、日落釣魚等活動讓時段有可讀氛圍；同頁亦介紹可收集的 Gyroid。 | 採時段有明確景色和收藏記憶的想法；不以現實時間鎖住 Snapland 活動或收藏。 |
| [Disney Dreamlight Valley 官方 Dapper Delights 更新說明](https://disneydreamlightvalley.com/news/update-aug-21-2024) | 更新放寬村民日程，讓玩家在任何時段都能拜訪；內容亦列衣櫃收藏、自訂穿搭預設、拍照姿勢與拾取記憶物件等功能。 | 讓時段只改場景氣氛，不關閉角色或活動；將額外收藏限於指定拍照站，避免把時間切換變成全域免費領取。 |
| [Disney Dreamlight Valley 官方 Jungle Getaway 更新說明](https://disneydreamlightvalley.com/fr/news/update-oct-9-2024) | 更新說明記載獅子王領域加入日夜循環，景色隨時間切換。 | 參考以環境光影呈現時段差異；Snapland 使用手動固定時段，避免等待循環才能看景。 |
| [Minecraft Bedrock `/time` 官方命令](https://learn.microsoft.com/en-us/minecraft/creator/commands/commands/time?view=minecraft-bedrock-stable) | 官方命令支援查詢、增加及指定遊戲時間，含 day、sunrise、noon、sunset、night、midnight 等名稱；命令需權限。 | 採用清楚命名的時段預設，將直接選時做成一般遊戲 HUD 功能，不要求輸入命令或開啟作弊。 |
| [Minecraft Bedrock Editor 官方時間選項](https://learn.microsoft.com/en-us/minecraft/creator/documents/bedrockeditor/editorworldoptions?view=minecraft-bedrock-stable) | 世界編輯選項提供 Day、Noon、Sunset、Night、Sunrise 等預設，也可選自訂時間和正常／鎖定日照循環。 | 以四個容易辨識的時段選項取代精細時鐘；四段外觀可自由切換，遊戲流程與計時不受影響。 |
| [Godot 4.5 `Environment` 文件](https://docs.godotengine.org/en/4.5/classes/class_environment.html) | `WorldEnvironment` 的 Environment 資源控制背景天空或顏色、環境光、霧與後處理，影響最終場景呈現。 | 把四段色調和環境光設定集中為共用時段資料，讓世界場景使用同一份定義。 |
| [Godot 4.2 `DirectionalLight3D` 文件](https://docs.godotengine.org/en/4.2/classes/class_directionallight3d.html) | DirectionalLight3D 模擬日光或月光的平行光；原點位置不影響方向，節點基底決定光線方向，並可選擇是否顯示於天空。 | 時段資料除了天空與環境光，也定義主光顏色、強度和方向；不以挪動光源原點假裝太陽移動。 |
| [Steamworks 成就與統計官方文件](https://partner.steamgames.com/doc/features/achievements?l=english&title=partner.steamgames.com) | 成就需定義名稱與圖示；解鎖後透過 SetAchievement 和 StoreStats 儲存，Steam 亦會保留離線修改等待同步。 | 四張時段拍貼完成時使用既有成就接點排入同步佇列；本機存檔仍保存 Snapland 收藏與貨幣。 |

## 玩家行為

玩家可透過 HUD「時段」按鈕或 T 鍵在凌晨、中午、傍晚、晚上之間自由切換。當前時段及代表時間清楚顯示；切換會更新共享時段定義，使場景天空、環境光與主光採用相應設定。時段選擇即時保存，讀取舊的 `settings.day_time` 時將 `day` 對應中午、`night` 對應晚上，也接受既有布林值的日／夜對應。缺失或無效值回到中午。

玩家在中央廣場的導覽合照點開啟時段面板後，可收集目前時段的紀念拍貼。收集會暫時隱藏 HUD 與面板，拍攝 320×180 的場景 PNG，將檔案存入個人進度的 `photos/`，並把路徑保存在收藏的 `frames` 中。只有擷取與進度保存都成功才發放每段一次的 20 枚海島幣；取消、錯時段或寫入失敗不發獎，重複領取會被拒絕。四張全收集後解鎖「四時留影」成就。時段拍貼以獨立 ID 顯示在時段面板與拍貼收藏的紀念區，不納入普通或小惡魔拍貼門檻。全域 HUD 和 T 鍵都能選時段，但只在既有導覽合照點顯示收藏按鈕。

小遊戲開始時讀取當前時段作為該局視覺狀態；若遊戲中開啟時段面板，暫停局內計時，套用新選擇後返回時恢復遊戲。切換不重設局面、計時、獎勵或一般收藏資格。時段與四張收藏必須通過既有進度保存驗證；損毀的時段欄位採安全預設，舊拍貼、成就與貨幣照常載入。

## 驗收界線

資料驗證、啟動檢查或靜態截圖不能替代實際遊玩驗收。原生檢查需覆蓋四段照明、HUD 和 T 鍵、切換時遊戲暫停與恢復、在導覽合照點隱藏 UI 拍攝並存檔四張 PNG、拍貼面板與相簿縮圖、錯時段／取消／重複領取均不發獎、成就待同步、舊日夜欄位遷移，以及普通／小惡魔拍貼計數不變。
