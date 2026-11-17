# 糖漿分洪：共享熱源、關閥與冷糖堵漏

SG-43／game-027，糖果工廠第三款基本遊戲。依既有目錄實作「取捨」核心與 3D 管道剖面；不是 game-007 的接管拼圖，也不重用搭橋或翻模規則。使用者已授權自主裁決，不再等待逐項選項批准。

## 最小完整玩法

三條固定支管，各有一個開關閥、一缸液面與實際溫度。共用熱源同時只能加熱一條支管，可關閉。高溫低黏度、流得快，但旁漏會浪費糖；先保留中管冷糖，可改道流入裂口形成實體糖塞，再把熱源轉回中管加速裝缸。不同管長影響阻力、熱容量影響升溫速度，重試交替兩配置。玩家可同時開幾條管，利用熱慣性輪轉熱源；單一冷管不必等全熱。

| 裁決 | 理由 | 成本／邊界 |
|---|---|---|
| 固定三管與共享熱源，不拼接管網 | 操作是熱與流量取捨，與既有空間接管區分 | 不做通用流體解算器或可編輯管網 |
| 每缸達 90% 刻線至 100% 且三閥關閉才成功 | 必須親自處理關閥，不在即將溢出時自動判勝 | 不要求毫秒精準，保留清楚液面帶 |
| 中管唯一旁漏可選擇不堵而先熱快裝 | 冷堵是材料第二用途與小惡魔挑戰，不強迫每局同解 | 漏糖只浪費流量，不無限累積事件歷史 |
| 溢出關當閥，可免費排空該缸重來，時間不回復 | 失手可補救，已完成其他缸保留 | 每次溢出扣分，不扣收藏或玩家貨幣 |
| C 停流配置供單人正常及輔助使用 | 暫停模擬仍能讀表、調閥與熱源，完成後手動續流 | 暫停不產生熱、糖或獎勵；Session Esc 暫停仍禁止操作 |
| 沿用 model／driver／view、Session、固定收藏與補拍 | 已有責任分工，控制器不接觸保存 | 不加依賴、設定框架或另建經濟系統 |

## 有界規則與起始標定

時間為秒，液量為遊戲單位，溫度 T 在 0–1；視覺標示冷／溫／熱與百分比，不宣稱實體工業校準。回合 75 秒。三缸容量依序 100／110／90，刻線均 90%，開始液量 0、T=0.18、閥全關、熱源關閉、無 AI，旁漏未堵、出口正常入缸。配置 A 的管長 [1.0,1.35,0.85]、熱容量 [1.0,1.4,0.8]；B 為管長 [1.3,0.85,1.1]、熱容量 [1.6,0.75,1.2]。視覺管段及參數顯示要和該局一致，不能僅換名稱。

每次有效 step(delta) 上限 0.25，拆成 ≤1/60 子步；非有限、非正 delta 不改狀態。計時只能走到剩餘時間，截止的最後有效子步若已達成條件先成功，否則逾時失敗。配置暫停與 ended 時不模擬。每子步順序：熱更新 → 流量／堵漏與液面 → AI 關指定閥 → 成功／逾時。溫度變化 `dT/dt = (0.4*(1-T)/heat_capacity if heater==i else 0) - 0.04*T`，clamp0..1。當閥開且缸未溢出，流量 `q=(1.6+8.4*T*T)/length`；輔助乘 0.75。閥關 q=0，但支管仍能加熱及冷卻。有效黏度指示與此流速單調相反，不能與模型另算矛盾結果。

- 正常出口：未堵的中管將 35% 流量旁漏、65% 入缸；其餘管全部入缸。各缸保留當前液量、流量及累計漏糖，不保留軌跡陣列。超出容量即一次溢出，標記 spoiled、關該閥、mistakes+1；液面顯示超線，只有免費 drain_selected 排空及清除 spoiled 後可重新開閥。排空不回時間、不清累計 mistakes，不算通過。
- 中管旁路出口：玩家必須選中中管，切換 diversion 並真的開閥。T≤0.30 的流量累積糖塞材料，達 12 單位才永久堵住；尚未堵住時熱糖只漏出，並按每單位 0.6 消融未完成糖塞。形成前進度 clamp0..12；不存在憑切換直接封堵。完成時自動恢復入缸出口，實際冷糖材料累積成塞後才鎖定 cold_plugged=true。堵住後普通中管不再漏；本回合無第二裂口。非中管或已堵時切旁路為無效操作。
- 所有累計量有回合時間與最大流量界限；模型只持三條支管、三缸、一個熱源、一個糖塞及一個 AI 指定索引。快照深複製嵌套資料，無效索引不改狀態。結果與分數由模型單一來源提供。
- AI 僅監看玩家指定的一缸：當出口入缸、閥開且液量達容量 92% 時關該閥。指定另一缸會替換原指定，重選同缸取消。AI 不開閥、不加熱、不改道、不排空、不生成材料或直接設結果。輔助與 AI 均可完成真實小惡魔，沒有按鈕直接領獎。
- 三缸各未 spoiled、液量在 [90%,100%] 且三閥均關，即 success；devil 僅 success 且 cold_plugged。正常成功／逾時且曾有效開關閥、改熱源、改旁路或排有糖的缸才 ordinary_eligible；選管、AI、停流配置或等待不算參與。取消／練習仍由 Session 排除。
- 分數 `max(0,100*filled_tanks + (success?100:0) + (devil?100:0) -20*mistakes)`，filled_tanks 指結算時未 spoiled 且在刻線帶內的缸，不能靠排空重複計分。溢出只記一次、逾時誠實失敗。

上述係數為共同起始標定。模型作者須用公開操作接口實際完成 A/B、普通／冷堵及輔助路線，並保留不操作失敗、熱旁路不能堵、溢出補救等證據；若需調整係數，只能局部標定並回報最終數字及動機，不能放寬成功／冷塞／參與規則或變更接口。後續 driver／view 使用凍結後數值，不各自複製物理算式。

## 凍結接口與輸入

新增 game/minigames/syrup_flood_model.gd、syrup_flood_driver.gd、syrup_flood_view.gd；沿用 CookieMold 的責任邊界，不能複製其不相關物理或手部模型。

Model：`reset(assisted:bool=false,variant:int=0)`, `select_branch(index:int)`, `select_next(direction:int=1)`, `toggle_valve()`, `toggle_heater()`, `toggle_diversion()`, `toggle_helper()`, `drain_selected()`, `toggle_configuration()`, `clear_input()`, `step(delta:float)`, `snapshot()->Dictionary`。toggle_heater 把共享熱源切至所選管，若已是該管則關。clear_input 不發出命令，不把開關式閥／熱源重設；真正模擬暫停由 Session 或 configuration_paused 控制。

Snapshot必有 elapsed,remaining,score,mistakes,ended,success,devil,ordinary_eligible,participated,assisted,variant,selected(0..2),heater(-1..2),helper(-1..2),configuration_paused,diversion,cold_plugged,plug_amount,plug_required,filled_tanks,feedback，及 branches[3]，每項含 length,heat_capacity,capacity,target,temperature,viscosity,flow,fill,valve,spoiled,leaked。target為實際液量非百分比；diversion 為 bool 僅中管旁路，fill/flow 與所有文字均讀同一快照。

Driver保留 reset(assisted,time_phase)、create_view、handle_input(event,design_point)、clear_input、step、snapshot、present(time_phase,reduced_motion)、score_summary(practice)。reset有界輪次交替A/B；snapshot補 progress_text/time_text/feedback_text，結果列與模型分數一致。KEYS與可點按控制列：Tab/ShiftTab 上／下一管，Space開／關所選閥，H切所選熱源，F中管旁路，R指定AI，X排空所選缸，C停流配置／續流；鍵盤echo及同一按住重複、第二根觸控或滑鼠合成事件不得連跳開關。場景各閥也可點按／觸控選管及開關，熱源／旁漏／冷塞狀態標清。按下可觸發一次開關，放開只釋放所有權；取消觸控、失焦、重試、tree_exiting、Session暫停清除所有權不觸發新命令。

View沿用保留式 SubViewport 真正3D工作台：三個有厚度管段剖面、可見糖流及液面、三閥、共用熱源位置與熱色、實體冷糖塞與旁漏。不是一張HUD平面替身；液面、閥、溫度／黏度／流速及刻線帶顏色與文字皆可分辨。建構一次固定節點，present不逐幀建材質／網格或累積標籤，reduced_motion只停純裝飾流動，不刪必要液面變化。1280×720設計座標配合Session縮放、Paper字體與time_phase。1280×720、1152×648、800×600（放大文字及降低動態）全部控制可用；不靠hover讀核心規則，hover只說「共用熱源同時加熱一管」「熱糖快，冷糖能堵裂口」「排空不回時間」等實際後果。

## 接入與證據

Catalog糖果增加第三項 game-027／syrup_flood／local_index3，固定普通 photo-candy-game-3、小惡魔 photo-candy-devil-3、ACH_GAME_027。實際可玩26→27、工廠2→3／12；其餘候選仍非已實作，十區與128候選不變。維持舊存檔／收藏／貨幣／地圖動線與兩款舊工廠遊戲。實際入口置於可走右上管道區(7,GROUND_Y,-6)，保留觀察點與返程，地圖列真實三款。

三張教學圖由實際原生3D視圖及真實操作狀態保存，講清冷熱切管、刻線關閥、冷塞／溢出恢復；不拿其他遊戲圖代用。教學、規則、普通參與與真實小惡魔說明一致。現有 Session 暫停／重試／離場、Main教學及結果、收藏補拍與新程序保存重開全部走實際路徑，不直接改成績或寫結果代替操作。模型／driver／view／Session／Main測試加到既有嚴格runner及PASSmarkers、Python契約測試，不靜默略過缺引擎或缺fixture。

原生桌面三尺寸＋獨立輸出包／新程序保存重開，直接寫存檔一律獨立 SNAPLAND_SAVE_PATH，Godot4.7.2由驗證launcher，runtime stage與TEMP／profiles全部D磁碟；不動既有接受的QA包或玩家存檔。報告只稱腳本／GPU／數值驗證，不稱人類試玩、試聽、連續藝術自然度或跨裝置效能通過。
