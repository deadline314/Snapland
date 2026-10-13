# 全遊戲像素介面重設

2026-10-14；需求與設計自主決定已由使用者授權。本輪保留既有遊戲、收藏、換裝與進度行為，重設所有已存在UI表面；不擴充小遊戲玩法。

## 意圖與問題

使用者徹底否定紙卡式介面：面板小、空間浪費、固定操作被裁切，少量內容也需要捲動。成功標準是精緻像素視覺、清楚導覽、足夠內容面積與可見的主要操作。研究記錄與參考圖只作設計審閱，不作遊戲資產。

現況由`main.gd::_open`的固定偏好尺寸、CenterContainer與外層AdaptiveMenuScroll共同造成。內部再放ScrollContainer便有巢狀捲動。多重紙卡、厚影與圓角加重密度，不靠改色修補。

## 研究：實际讀取與觀察

| 來源 | 本輪實際看到 | 採用／限制 |
|---|---|---|
| [歧路旅人II官方System](https://www.jp.square-enix.com/octopathtraveler2/system/) | 下載頁面實際連結的system03影片，4秒擷取圖：右側角色狀態、上方菱形行動序、場景中央留白；看過該靜態影格，未完整播放參考影片 | 資訊各自固定區域與明確主次；不移植戰鬥面板、原圖或遊戲標誌 |
| [幻想水滸傳HD官方UI/UX](https://www.konami.com/games/suikoden/rem/1_2/us/en-us/system) | 官方ui_2_en-us圖：左角色名單、中央肖像及裝備、右選項與2/5頁碼，底部比較描述；官網明言現代化裝備UI | 以畫面寬度分出導覽、預覽、詳情；少量操作完整可見，長清單有分頁 |
| [Sea of Stars官方presskit](https://sabotagestudio.com/presskits/sea-of-stars/) | Combat-1-1圖：深色像素細框、米白文字、金色數值、選中命令有手形指標、角色狀態與場景分開 | 高對比、像素圖示與明顯焦點，裝飾不搶資訊 |
| [CrossCode開發者官網](https://www.radicalfishgames.com/crosscode/en/home) | feature-rpg圖為技能網：像素菱形節點、選中金框與相鄰黑底短說明 | 焦點與短說明靠近被選項目；本圖不是完整裝備選單，不據此聲稱換裝行為 |
| [Chained Echoes創作者官網](https://www.chainedechoes.com/) | animations2.gif第20格：右下四人數值橫條、右上行動序，中央大部分留給世界；website1-1圖僅風景 | HUD邊緣分組與重要數字一致對齊；不把風景圖寫成選單案例 |
| [Stardew Valley作者手機版公告](https://www.stardewvalley.net/stardew-valley-coming-to-mobile/) | 2018-10-9公告明說為觸控重建UI、選單及操控；media頁本輪下載的農場、河畔及礦區图均沒有選單 | 不硬套一種輸入布局；這些無UI場景圖不作選單結構證據，也不推論實際按鈕尺寸 |
| [Godot Containers官方文件](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html) | 複雜RPG介面適合containers；容器管理子節點位置，手動位置會於resize失效 | 以容器計算布局，固定標題與操作列放在長內容區之外 |

原始參考保存`pm/Snapland-art/images/ART-23-reference-*.png`，主要session已實際查看以上影格。不得聲稱參考遊戲的可用性已由玩家驗證，也不把它們的細節照抄。

## 選擇與視覺基線

比較三案：淡色木質像素面板保留既有暖調但近似舊紙卡；極簡黑底細線容易單薄；採深海藍像素畫框搭配銅金選中、薄荷資訊與象牙文字，讓海港特色與高細節兼容。

- 統一深海藍底、分層內框、階梯切角、精確像素圖示；取消圓角、柔軟紙影、郵戳與不必要內嵌卡片。裝飾只出現在邊角或分區。
- 不把畫面全部降解析度或粗放大；像素邊框、圖示按整數像素畫，中文沿用可讀的完整字庫。文字清晰優先，不用缺字的像素字型。
- 標題、選中內容、主要操作三級層次。焦點以形狀／指標和顏色共同表示。降低動態保留靜態焦點。
- 主要暫停導覽採充分寬高的左右分區，全部主要操作可見；1280×720不得出现滚動條。800×450以較少空白與較短標題適配，不靠縮小到不可讀。
- 收藏、成就、任務與教學以分頁／分類和單一內容捲動；頁籤與返回永遠固定。換裝保持角色預覽、分類與套用可見。
- 對話保留底部場景閱讀；小遊戲HUD只呈現必要目標、分數與時間。教學入口可重看，避免常駐操作段落。
- 不改經濟、收藏資格、時間機制、任務或動作。幀率與配置測試不代表人類偏好或遊玩成功。

## 檔案與工作所有權

1. ART-23：單一owner修改`paper_ui.gd`與`main.gd`，共用風格、模態框架、HUD、暫停與主導覽。保留既有public helper API與回呼、可測節點名稱，移除泛用外層捲動；長內容由各面板自行擁有。
2. ART-24：`collection_book_panel.gd`,`photo_viewer.gd`,`island_map_panel.gd`,`achievement_stamp_book.gd`,`tutorial_panel.gd`；保持資料與原始照片，重設內容布局。不可碰main或共用theme。
3. ART-25：`wardrobe_panel.gd`,`time_panel.gd`及新`settings_panel.gd`，完成後請ART-23 owner接入main設定呼叫；禁止兩人同時改main。
4. ART-26：`minigame_hud.gd`,`island_game_invite.gd`,`photo_stage.gd`,`dialogue_panel.gd`；結算／教學與main交接由唯一main owner處理。對話視覺歸此票但暫停生命周期不更動。

各面板透過Paper.theme、label、button、card、plaque等既有API取得新樣式；相容名稱不代表繼續紙卡設計。內容專屬scroll不得吞掉固定頁籤、返回與套用。

## 實作與驗收計畫

- [x] 記錄每票開始SHA，更新進行中；先建立共用theme與暫停導覽，局部測試固定操作全部在視窗內且沒有scroll。
- [x] 分檔並行重設各面板；新增測試涵蓋固定操作可見、長資料與空資料、焦點、返回及設定／外觀保存。不修改既有測試選擇器、不刪除斷言；布局改版仍維持已有容器 API 與功能契約。
- [x] 主session逐票讀diff並以隔離存檔、受影響局部測試驗收。800×450、1280×720、1920×1080及字體較大設定須檢查；長中文和圖像不得裁切。
- [x] 主session用原生GPU逐頁截圖並實際觀看，包含HUD、暫停、旅券、地圖、任務、收藏、成就、換裝、設定、時段、對話、教學、邀請、拍贴與小遊戲HUD／暫停／結算。
- [x] 對照截圖修正間距、對比、焦點與捲動；保存`pm/<專案>/images`，票按實際證據勾選，逐票commit/push。未全過保留feature與進行中。

所有引擎啟動透過有效入口檢查、明確獨立SNAPLAND_SAVE_PATH、外部逾時與僅終止自己擁有的process。不要改正式進度及其備份。


## 2026-10-14 追加：免捲動與偽3D層次

使用者要求一般介面盡量免捲動、像素UI有深淺與光影、按鈕狀態有表現且文字不可重疊。固定選單全部展開；收藏、成就、任務、教學、換裝與長結算改分類／真正分頁。底層保留相容viewport或程式化頁面位移，不表示玩家需要滾動；少量下拉選項完整向上／下展開，超過視窗容量的長選單才有必要捲動。

- 正文與所有資料保留，分頁須遍歷全部穩定ID，不為免捲動刪內容。教學把圖片與當前步驟放進明確分區，長說明分頁。
- 像素框左上光源、右下側面與克制投影；懸停提高厚度，按下收起投影，焦點仍有金色描邊。文字與點擊範圍不因裝飾改變。
- [Godot StyleBoxFlat官方文件](https://docs.godotengine.org/en/stable/classes/class_styleboxflat.html) 本輪實際讀到各邊寬度、陰影尺寸／位移與抗鋸齒屬性；45度斜角建議關閉抗鋸齒以保持清楚。文件也明說expand margin不會增加可點擊範圍，故裝飾不能充當命中區域。
- 本輪新增尚未提交的UI測試隨追加規格改成更嚴格的分頁完整性／實際文字矩形檢查；所有原本已提交的測試選擇器及斷言保持原樣。
- [Godot Label官方文件](https://docs.godotengine.org/en/stable/classes/class_label.html) 本輪實際讀到`get_line_height(-1)`返回最大實際行高，`get_visible_line_count()`返回已顯示行數。原生驗收發現放大中文可因列高不足而整行不畫，故檢查實際字形行高、可見行數與所有十八項按鍵說明，不以主要字型的估計高度代替。
