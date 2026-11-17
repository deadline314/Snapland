# 小視窗規則頁：完整文字與操作

MAIN-34。SG-43 實際原生 Main 在 800×600、ui_scale=1.25 的兩個規則頁面各發現三個右側操作超出 viewport；原始圖已確認整個面板被橫向最小寬度撐開。修復位於共用規則呈現，先在 origin/main 的既有26款重現，獨立交付後再將 SG-43 rebase 並重驗。不能藉改視窗縮放模式、縮小字體、裁切、隱藏操作或放寬邊界判斷通過。

## 原因與範圍

目前 _show_game_rules 把本局目標標題與兩個未嘗試時的長補拍按鈕置於 HBox，另在固定 HBox footer 放四個遊玩選項加返回。這是已觀察的最小寬度假說，必須以既有遊戲的 fresh RED、實際 Control rect/minimum-size 與 viewport 證明，不能只改圖或照抄 SG-43 截圖當舊版基準。

只修改 game/main.gd 規則頁所需排列／專用呈現，沿用 Paper、既有容器、_content_pager 與自適應面板。優先現有流式／換行容器或分頁；若不需要新 helper 就不新增。其他 modal、全域 modal_footer 的 HBox型別、遊戲／進度／保存／照片規則保持原值。現有名稱 GameRulesDetails、GameRulesRetakes、KioskRetakeOrdinary/Devil、GameRulesExtraDetails 頁碼、MenuBackButton 與所有 callback 目標維持可觀察功能；若有必要巢狀排列，測試改成正確查找而不刪驗證。基本目標／操作與額外說明保留可讀順序；不新增長捲動區或無意義 hover。

## 可驗證條件

- 1280×720、1152×648、800×600 的實際 viewport。800 使用既有1.25大字與降低動態，所有可見按鈕及文字位於視窗、卡片與各自文字框內，不能只驗中心點；字級與原型相同。原生先用與 SG-43 相同 CONTENT_SCALE_MODE_DISABLED 實體視窗設定，不靠換模式隱藏缺陷。
- 規則頁須涵蓋目錄全部已交付遊戲（本分支26，後續隨真實 Catalog增加），尤其兩種卡均缺且未嘗試的最長按鈕狀態；另驗已嘗試、只剩一種卡及都已收藏。使用隔離合成進度只作介面條件，不能稱為玩家遊玩或取得卡片。
- 真實教學、練習、開始、輔助、兩種補拍、返回、說明翻頁的回呼與相對順序正確；鍵盤與指標仍可用。補拍前置與照片來源、金幣、存檔及老遊戲不變。
- 有意義的局部測試：既有 pixel UI shell 納入兩卡缺少的規則回歸、跨目錄／三尺寸矩形與文字檢查、對應回呼／狀態；既有補拍 Main／工廠 Main／旅行介面受影響項適量回歸。新原生 fixture 保存各尺寸代表原圖與實際判斷，不代替真人試玩或試聽。

所有Godot由 tools.godot_entrypoints.run_validated_godot、exact C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe，Node使用真實.tscn；runtime stage用prepare_runtime_stage tracked inventory加精確fixture/helperallowlist。獨立絕對SNAPLAND_SAVE_PATH/APPDATA/LOCALAPPDATA/TEMP/TMP，重輸出全部D磁碟；不匯入C專案、不動玩家存檔或已接受的舊QA包。保留失敗、修正後marker/exit/error、原圖與雜湊。不為UI-only修正重做正常遊戲匯出。

## 交付接縫

原生SG-43 producer已停止所有寫入與程序，未完成的native_syrup_flood_main.gd/.tscn是未追蹤的另一票檔案，這張票不讀取、匯入、搬動、刪除或提交。只交付本票已驗證共用UI變更。main同步後回SG-43分支rebase，保留其參與資格三模式名單與所有新遊戲內容；相依票關係雙向維護，任何add/add票文衝突保留進行中狀態及MAIN-34相依。SG-43後續需真實27款下再驗800原生規則／補拍，不沿用舊候選成功。
