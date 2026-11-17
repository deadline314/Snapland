# 果凍彈床：蓄彈、斜壓與高台落點

SG-44／game-028。依128款目錄，新增獨立彈性與空間玩法，不是把既有點按或裝缸換外觀。玩家移動彈床、設定左右斜壓，按住蓄彈後放開，連送三顆果實上高台；斜壓必須改變實際水平速度。旁側鈴由果實真實碰觸，碰鈴的同一顆果實還要成功送達才累積小惡魔資格。反重力異空間不在本票，也不湊基本遊戲數。

## 採用決策與界線

| 決策 | 理由與代價 |
|---|---|
| 最小單果實彈道、三次運送 | 保留可讀的蓄彈／落點取捨；不加多球、關卡編輯器或新物理依賴 |
| 彈床位置與斜壓在發射前設定 | 鍵盤／單指都能完整操作；空中不遙控果實改向 |
| 真實重力、側牆／頂梁反彈、下降穿越高台頂面 | 鈴與高台位置有實際空間關係，不用成功按鈕或只有高度的動畫代替 |
| 輔助放寬支撐、台面及側鈴接觸範圍，保留已送果實 | 保留相同能量、斜壓及真實碰撞；不能直接送達或免費碰鈴 |
| 簡單AI只在真實回落接觸彈床時接穩 | 等玩家蓄彈與放開，不調斜壓／位置、不自動發射或領獎 |
| 沿用現有Model／Driver／View、Session及固定收藏 | 不加新框架、存檔結構、Steam定義、經濟或音訊系統 |

## 規則與起始標定

邏輯座標向右／向下為正，1120×620舞台。回合60秒；果實圓形半徑28，重力900單位／秒²。彈床支撐面y=520，中心x初值340、可在180..500以40為一格移動；半寬70，輔助90。只有ready時果實跟隨彈床位置，flight中移動彈床只影響後續實際接球。高台中心x=870，半寬90（輔助115），只在果實下降時底部穿越台頂且圓形中心在支撐範圍才送達。果實／支撐接觸範圍要一致扣除半徑，不把視覺外側當作落台。

配置A果重[1.0,1.15,0.9]、台頂y=[240,260,220]；B果重[1.15,0.9,1.0]、台頂y=[260,220,240]。重試交替A/B，序號只保留0/1。依已送顆數決定當顆重與台高。側鈴中心(930,190)、半徑32（輔助42），必須用果實實際圓形接觸；頂梁y=32、左右牆x=32及1088，碰撞用果實半徑，頂／側牆速度保留係數0.60／0.85，底部y=620為失落線。鈴本身是感測接觸，不替果實自動轉向；側牆才反射水平速度。

斜壓角度初值21度，範圍-35..35，以7度一格（端點夾限）。蓄彈深度d=clamp(按住秒數/1.4,0,1)，ready果實中心y=520-28+40*d，隨支撐中心實際下壓；發射從這個真實位置開始。能量E=500000*d²，發射速度sqrt(2*E/果重)，vx=速度*sin(角度)，vy=-速度*cos(角度)。持續按住最多蓄滿，不自動發射；至少按住0.15秒，匹配的放開才真的發射並記participated。淺按不足只提示，不發射／領卡。移位、斜壓、AI、重置、單純按住或等待不算實際參與。飛行時不可用放開修改速度。

Space可在flight中按住作接球準備，但只有實際回落接觸彈床後才開始蓄彈。回落時AI啟用或玩家仍按住，接穩為ready、速度歸零，等玩家放行；未接穩時彈床依真實碰撞以0.65垂直／0.85水平速度保留反彈，垂直速度低於80可安定為ready。不把AI切換當作捕捉遠處果實。ready初始本來就能自行蓄彈，AI不替玩家發射。

高台實際送達才delivered+1；同顆果實的bell_touched可跨彈床回接保留，到真正送達才bell_deliveries+1，失落／當顆重置清除。普通失落重置delivered與bell_deliveries，輔助保留已完成檢查點；都mistakes+1、果實回到彈床、不回時間。X只重置當顆，flight／已有蓄彈才計失誤，不能刷分或回時間；初始ready空按不改參與或完成數。送三顆成功，成功且bell_deliveries>=1才devil。60秒以自然失敗結束；ordinary_eligible只在有實際發射且正式自然結束時成立，練習／取消由Session維持不發卡。

分數=max(0,delivered*100 + (成功?100:0) + (devil?100:0) - mistakes*20)，因此無失誤普通400／小惡魔500。分數列使用模型結果並對齊零下限。無貨幣損失，首局獎勵沿用去重。delta非有限／非正不推進；每次最多0.25秒，分步不大於1/120秒。快速飛行用掃過的線段及下降跨越檢查，不能穿過鈴、高台、彈床或牆；同一步只送當顆一次，換果實不續用上一顆剩餘碰撞。成功與截止同一步時只承認截止前真正接觸，時間殘差只准1e-9級正規化，不擴大成功容差。

以上為起始數值。Task1以公開輸入找出A/B×一般／輔助×普通／側鈴八條可完成路徑；若數值不可行，只能先報告實際軌跡與最小參數調整，由root同步本規格後再凍結。不得改成功、真實碰鈴、同顆送達、輸入或AI邊界來製造通關。

## 介面與輸入

JellyTrampolineModel公開reset(assisted:bool=false,variant:int=0)、move_bed(direction:int)、adjust_tilt(direction:int)、begin_charge()、release_charge()、cancel_charge()、toggle_helper()、reset_fruit()、clear_input()、step(delta:float)、snapshot()->Dictionary。clear_input等同取消持續輸入，不發射、不重置物理飛行／整局。

snapshot必含elapsed,remaining,score,mistakes,ended,success,devil,ordinary_eligible,participated,assisted,variant,delivered,bell_deliveries,charging,charge_seconds,depth,tilt,helper,feedback；bed{x,y,half_width}、target{x,y,half_width}、bell{x,y,radius}、fruit{x,y,vx,vy,radius,mass,ready,bell_touched}，及最多24點的trajectory:Array[Vector2]。弧線由相同彈道／反彈規則計算，不是美術預置路線；預測不得改模型結果。快照不可被呼叫方回寫。狀態、歷史及預測有固定上限。

Driver沿用reset(assisted,time_phase)、create_view、handle_input(event,design_point)、clear_input、step、snapshot、present(time_phase,reduced_motion)、score_summary(practice)。七命令依序bed_left/bed_right/tilt_left/tilt_right/charge/helper/reset_fruit；鍵盤A/D/Q/E/Space/R/X（方向鍵左右亦可對應移床）。A/D/Q/E為一次按下調一格，Space按住＋同來源放開才發射。滑鼠及觸控按住charge直到放開；外側放開、取消、失焦、暫停、tree_exiting及重試均取消蓄彈，不幽靈發射。鍵盤echo、重複按住、第二指及滑鼠合成事件不得重複觸發；沿用house來源／按鍵所有權，跨來源不可搶放開。空中玩家不獲得額外轉向命令。

View用保留式SubViewport真3D的2.5D舞台：有厚度的果凍支撐／左右不同壓縮、球形果實／重力飛行、高台、側鈴、碰撞梁牆及有界弧線點。全部位置、深度、角度、質量、落台及鈴狀態讀同一快照。建構一次節點／材質／網格，present不逐幀建立物件；必要深度、物理軌跡及回饋不受reduced_motion刪除。固定1280×720設計座標，Session縮放／Paper字體／time_phase沿用。1280×720、1152×648、800×600（大字1.25及降低動態）全控制可用，核心規則不靠hover；hover只講「放開才發射」「斜壓改變水平速度」「重置不回時間」「AI接穩後等你放行」。

## 接入與證據

固定game-028／jelly_trampoline／candy local_index4／photo-candy-game-4／photo-candy-devil-4／ACH_GAME_028；實際27→28、工廠3→4/12，128候選及其餘未實作狀態不變。實際入口放(7,GROUND_Y,-1)的工廠右側下一站，保留前3入口與觀察點／返回路徑；若有實際幾何衝突，先報告再調位。沿用固定補拍道具語彙為第28列，不新增存檔schema、交易定義或專用音訊框架。缺專用聲音沿用既有fallback，不宣稱新MIC驗收。

三張教學圖須來自真實原生操作／3D狀態，說明蓄彈與斜壓、真實高台送達、真實側鈴及回接後手動放行；不編輯／裁切生成成功畫面。Session/Main測試加到現有嚴格runner與Python契約／設計檢查。模型／輸入／視圖／Session／Main及原生三尺寸、兩種實際GPU補拍／新程序、獨立QA嵌入執行檔寫入／讀取皆須真實證據。保持原有遊戲、27堂教學、身份與玩家存檔不變。

所有Godot透過validated launcher且exact4.7.2；SceneTree用--script，Node用真.tscn。runtime stage、TEMP／APPDATA／LOCALAPPDATA／profiles／輸出皆D絕對獨立路徑；prepare_runtime_stage只用tracked runtime，加精確fixture closure，不拷整庫／整test tree／UID與C匯入cache，不改已接受舊包。直接存檔一定SNAPLAND_SAVE_PATH。只允許明示的六張迎賓入園卡＋已看開場前置；原生可受控站位後實際E，但不稱步行／全島入園證據。不得注入028狀態／成績／鈴／照片／成就／獎勵。一般gameplay拍貼保留既有最近畫面更新，retake原檔／來源在真實挑戰與新程序後不變。腳本／GPU／數值不當真人試玩、試聽、美術自然度或跨裝置效能驗收；ART16/17、MIC1..3、ST5不因此結案。
