# SG-20 帽子救援原生 v12 驗收紀錄

## 原生流程結果

Root 以隔離存檔、真實 Main 車站／選單和 `Input.parse_input_event` 驅動 v12 fixture。正常速度錄影為 1,943 幀、32.3833 秒；四分之一速度為 7,598 幀、126.6333 秒，兩次都自然完成並通過 fixture。來源紀錄是 `.review/sg20-normal-v12.log`、`.review/sg20-quarter-v12.log`；原始 60 fps 錄影是 `.review/sg20-normal-v12.avi`、`.review/sg20-quarter-v12.avi`，MP4 成品保存在同資料夾。

正式回合由實際鍵盤操作完成六頂中心接住、零漏接、816 分，正常與小惡魔成果均通過。確認重試在同步事件時刻檢查精確歸零；暫停／恢復及結算生命週期也通過。隔離練習以輔助、降低動態和真實滑鼠操作接住六頂中心，816 分、不取得小惡魔成果；練習前後的照片、成就、任務、已訪地點、設定、外觀、裝備、衣物、貨幣、衣櫃回饋、平台待送成就及 intro 狀態快照一致。`tutorial_seen_games` 僅在該欄位存在時加入檢查。

正式回合實際渲染並觀察到 12 個伸手影格，mask 4095。正常速度出現在 movie frame 102–136；四分之一速度出現在 frame 305–438。`.review/hat-v12-quarter-catch-poses-00-11.png` 是這十二張原生 post-draw 全身擷取圖的標號接觸表；單張來源保存在 `.review/SG20-final-candidate/.review/native-hat-rescue-catch-pose-00.png` 至 `-11.png`。目前使用的 frozen fixture SHA-256：`8DB819D62F17B2302C300240C1DE98D20AF7AE24BB5E19AF88142C3EDF14F283`。

## 控制輸入修正與局部測試

v11 曾在慢速錄影中顯示方向鍵仍為按住狀態、但模型軸轉向；檢查發現場內滑鼠移動會把同一模型切換成 pointer-target。Session 現在在方向鍵按住時消耗滑鼠微移而保留鍵盤方向；方向鍵放開後滑鼠移動恢復設目標，明確左鍵點擊仍能設目標並觸發短接帽窗。新增六個 Session GUI 事件案例驗證這三種轉換。Root 的局部結果：帽子模型 28 cases、Hat View 47 cases、共用 Session 80 cases 通過。

## v13 步態修正與原生補驗

v12 原生影片通過當時的輸入及回合檢查；其 View 曾只載入左右各 4 張步行圖，且用 elapsed 選格。v13 改用 `AvatarRenderer.walk_frame_count(direction)` 載入所有 atlas 格，以實際 `player_x` 位移累積相位、轉向延續相位、重試歸零；catch 動作優先顯示時，步態觀測 accessor 回傳 -1。Hat View 局部測試 55 項通過。

原生 fixture 在 `RenderingServer.frame_post_draw` 只讀正式角色實際呈現的 direction/index，首次見到每格才保存全畫面 PNG，並要求正式真實輸入回合左右各 8 格完整（mask 255/255、共16張）；不注入步態輸入、不推進模型。Root 已完成 v13 正常與四分之一速度重跑，兩次皆取得左右 mask 255/255，且正式及私人練習回合通過。逐次數據、雜湊、保留影格和未驗範圍見 [v13 原生證據](hat-rescue-native-v13-evidence.md)；v12 影片不作為 v13 全步態畫面證據。

## 畫面檢視範圍與限制

正常與慢速錄影及實際接觸表已準備給 Root 做視覺檢視；程式和原生流程通過不等於 Root 已核准髮頂與 popup 間距、完整人物辨識或整體美術品質。TUI 截圖只展示移動、接帽時機和示例成果，不把驗收或測試字樣放進玩家文字。

此 fixture 沒有測試 Park 的私人離開路徑、首次教學理解、全套五十種服裝剪影，也未完成三位完整動畫 NPC 的要求。v12 全身截圖可檢查目前旅人的實際動作，但不能替代上述範圍。PM 圖片預計包含正常／四分之一速度影片、兩段接帽特寫與 12 格接觸表；須在 Root 完成實際視覺檢視後作最後接受記錄。

## 成品路徑

- 正常速度影片：`.review/sg20-normal-v12.mp4`，1280×720、60 fps、32.383 s。
- 四分之一速度影片：`.review/sg20-quarter-v12.mp4`，1280×720、60 fps、126.633 s。
- 正常速度接帽特寫：`.review/sg20-normal-v12-catch-focus.mp4`，1280×720、60 fps、1.100 s。
- 四分之一速度接帽特寫：`.review/sg20-quarter-v12-catch-focus.mp4`，1280×720、60 fps、2.817 s。
- 實際 12 格接觸表：`.review/hat-v12-quarter-catch-poses-00-11.png`，2080×846。
