# 棉糖捲風：轉棒收絲、三段分布與斷絲接回

SG-47／game-030。採真實 3D 旋糖近景，純 Model／Driver／保留式 View 與現有 Session；棉糖厚薄來自實際收集位置及棒的角度，不能以按鈕、模板編號或計時動畫授予成品。這是有界遊戲運動學，不是流體模擬或食品製程。異空間的雙對流不在本票，不增加基本款數。

## 收絲與品質

以下為起始標定，Task1 必須先以公開操作證明 A/B×一般/輔助×普通/接回八條路徑，再凍結；不可為了過測刪除核心動作。若不可行，先交具體軌跡、失敗原因與最小係數調整建議，由 controller 裁定並更新此文。

座標為任意遊戲單位：棒沿 X，中心初值 (0,90,70)，半長 90，三段中心偏移 -60／0／60，軸向區間 [-90,-30)、[-30,30)、[30,90]。玩家中心 X 限 -120..120、Z 45..155，Y 固定 90；平移 120 單位/秒，斜向正規化；轉棒 ±3 rad/s。三段各 12 個角向格，基底半徑 6，半徑依實際沉積量增加且最高 28。棒角度決定當次接觸落入哪個角向格；不轉只能堆一側，左右不移則不能均勻餵到兩端。快照必須保留完整 3×12 厚薄，外觀使用同一資料。

回合 120 秒，step 只接受有限正 delta、單次最多 .25、子步最多 1/120 秒，不倒退或以超大 delta 跳過碰撞。A 每 .12 秒、B 每 .15 秒放出一束，最多 128 束、壽命 3 秒。每束保留前後位置、速度、年齡、可收材料量；有限的實際線段與棒軸膠囊接觸才沉積，同束只消費一次。初始源點 X 為小幅擺動（A ±18、B ±22），Y=40、Z=0，初速 (橫風,100,80)，重力 Y=-80。A/B 熱風相位、擺幅及發射間距需有可見且可預測的差別；輔助降低熱風並放寬接觸窗，仍需轉棒和平移。

每束原始材料 .6；接觸時根據實際飛行距離／年齡決定可沉積比例，近處較多較厚、遠處較少較細，差額進入散失。材料總量必須守恆：已發射 = 在途 + 玩家沉積 + AI 沉積 + 懸絲 + 散失（容差 1e-5）。每格上限 4，多餘材料明確散失，不無界增厚。半徑初始採 6+4*sqrt(該格材料)，上限 28。

三段均勻條件：各段材料至少 12、最大段/最小段 <=1.35，各段至少 8/12 格有材料（每格至少 .15），各段角向材料變異係數 <=.65；輔助可放寬到 1.5、7 格及 .8，但不給無轉棒／無平移通關。F 確認只有真實品質達標才能結束成功；失敗確認計一次失誤並清楚指出不足。到時自然結束保留已做作品，不能當作成功。

## 將斷細絲與 AI

棒的外側兩段在遠處 Z>=120 接到薄絲時，最多產生一條實際懸絲：當束 60% 可收材料沉積，40% 成為仍有材料的自由端。懸絲保存錨定段與角度、世界自由端、剩餘材料、長度／張力、年齡。錨點隨棒的實際平移及旋轉移動，自由端受有限熱風漂移；伸長到原長+80 為將斷，超過原長+140 或 3 秒即斷，材料轉散失。畫面清楚顯示自由端、原錨點、另一端接取範圍與張力，不只是計量表。

只有仍在將斷窗內，棒另一外側段實際觸到這個自由端且正在轉棒，才把懸絲材料沉積到接取段並記錄接回。原端、中段、按確認、切換 AI 或僅等倒數均不算。輔助放寬接取半徑及斷前時間，不替玩家移棒／轉棒／接回。最終均勻作品且至少一次實際接回才得小惡魔，不能提前結束後追加旗標。

R 切換簡單 AI；它有實際第二支棒，在玩家之後處理未被玩家消費的絲束，守低密度位置並在接近玩家時讓位。只記自己的有限沉積，不把材料或成功條件直接轉送玩家、不自動接回。獨自不開 AI 也能完成全部內容。

## 參與、介面與呈現

participated 要求玩家實際收到至少 1 材料，且曾真實平移至少 6、轉動至少 .5 rad；移游標、配置 AI、空轉或只等結束不算。自然正式結束且 participated 才有普通資格；普通遊戲目標仍是均勻成品，須清楚區分參與收藏與通關。練習／取消由既有 Session 排除獎勵。分數為每個達標段 100、均勻成品 100、實際接回且成品成功再 100、每次失誤扣 20，最低 0；乾淨普通 400／惡魔 500。

公開 Model：reset(assisted:bool=false,variant:int=0)、set_motion(direction:Vector2)、move_stick_to(point:Vector2)、set_spin(direction:int)、finish()、toggle_helper()、clear_input()、step(delta:float)、snapshot()->Dictionary。move_stick_to 接收 (X,Z) 真實棒座標作目標，拒絕非有限值；只設定目標，不立即改變棒位置或收絲。step 每個子步以相同 120 單位/秒上限追隨目標，並依前後有效位置檢查碰撞；不能傳送棒穿越整場掃光糖絲。set_motion 切回方向控制，clear_input 清除未到達目標；Driver 拖曳沿用這個目標追隨，不另抄運動學。snapshot 為獨立資料，含時間／結束／成功／參與／資格／分數／失誤／設定、棒位置／角度／角速度／三段 12 格／各段品質、風向／絲束前後點與可收量／AI 棒及材料／懸絲完整狀態／接回次數／守恆總量／feedback；不得含 Node、共享可變幾何或無界歷史。

Driver 沿用 house reset/create_view/handle_input/clear_input/step/snapshot/present/score_summary。命令固定 left/right/near/far/spin_left/spin_right/finish/helper 共 8 個。W/↑ 靠近、S/↓ 遠離、A/D/左右鍵平移，Q 逆轉、E 或 Space 順轉，F 確認，R 切 AI；實體按鍵集合支援同義鍵及相反鍵釋放恢復，echo 不重複。鍵盤按住轉；單指／滑鼠點轉棒按鈕可鎖定轉動，放開後在 3D 工作區拖曳移棒，同鈕再點停止。移動按鈕按住有效。來源所有權清楚，第二指與合成滑鼠不得重複動作；暫停、失焦、取消、重設與離場清除移動及鎖定轉動。已收材料不因此消失。

View 公開 COMMANDS／KEYS、command_at、command_center、stick_to_design／design_to_stick，所有命中與繪製共用同一幾何／投影。1280×720 設計座標；Main 前 140 高保留，工作區初定 Rect2(24,242,880,390)，右側 Rect2(916,242,340,390) 為 2×4 按鈕；可在不遮 HUD／字級與小視窗完整性的前提調整。沿用 CargoBalanceView 的 SubViewport／相機／燈光／資源生命週期。棉糖使用真實三段格數生成的有體積表面，絲束採固定容量 MultiMesh 等平台批次機制，懸絲為實際世界線段。只在沉積修訂後更新棉糖網格，固定節點／材質、有限頂點與實例，不逐幀建立 Node。降低動態只關裝飾，必要絲流、轉動與張力保留。

本體說明完整解釋三段均勻、近遠取捨、轉棒、將斷接另一端、AI 只收自己的絲與正式參與；hover 只放操作重點。三張教學原圖分別取實際收絲分布、三段均勻、將斷接回操作。1280×720、1152×648、800×600（字級1.25、降低動態）所有 8 控制／狀態／規則／每個教學文字頁完整可用。原始 PNG 不編修，不把腳本操作稱為真人或實體觸控。

## 接入與驗證

固定 game-030／cotton_wind／candy local_index6／photo-candy-game-6／photo-candy-devil-6／ACH_GAME_030；實際 29→30、工廠 5→6/12，128 候選不變，031 為下一未實作。入口初選 (6.5,GROUND_Y,10)，必須實際檢查地面、鄰近物件及最近 E 互動；衝突先以可重現證據裁定最小位置調整。沿用固定補拍道具語彙、普通參與40與去重規則；不改 Progress schema、交易／經濟／音訊框架／正常玩家入口或輸出排除。

局部 Model/Driver/View/Session/Main 與實際受影響 Python／catalog／tutorial／world 契約。公開操作八條解法、Driver/Session 三種輸入共24條；不 seed 本款材料／懸絲／成功／成績／拍貼／獎勵。原生只允許標示的六張迎賓入園前置／已看開場與受控站位後實際 E，不稱步行／新檔賺入園資格。真實 Input.parse_input_event，正常 Session 推進，不繞過 GUI 用私有 handler 補救。

所有引擎／匯入／匯出／exe 走 validated launcher 與 exact Godot4.7.2；每個程序先完整審查實際 fixture/helper 與 staged 腳本的直接／間接子程序呼叫。每程序獨立絕對 D stage/save/APPDATA/LOCALAPPDATA/TEMP/TMP/capture/export，只有 reader 共用其 writer save。prepare_runtime_stage 僅 tracked runtime + 精確 fixtures；不帶整庫 tests、UID／C cache 或舊包；asset-only imports 只可在相同引擎及來源雜湊確認後複用。四個 fault-child 父測試 test_photo_retake_main、test_region_travel、test_photo_retake_progress、test_region_progress 本地排除，CI 保留。SceneTree 用 --script，Node 用真 .tscn；strict exit0、成功標記一次、零 ERROR／真正 leaked/still-in-use，保留 unsuppressed UTF8 engine log/stdout/stderr 與來源／引擎／模板／exe 雜湊。

三尺寸原生 writer/reader；四組 GPU 補拍 writer/reader（普通及惡魔1280、普通800、惡魔1152）比較實際快門原圖、320×180 解碼與選定一張40點去重，真實重挑戰後來源／原圖不變，新程序持續；正常最新 gameplay 圖更新另列。全新獨立 D 嵌入 Windows QA 執行檔 writer/reader，不能 --path／scene override；不得重寫舊包／歷史證據。設計、腳本、GPU／封裝驗證不能替 ART16/17、MIC1..3、ST5 的真人美術／聽感／敘事驗收結案。

## 參考與採用界線

- [Godot MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html)：批次實例、可見數及整批 AABB；[ArrayMesh](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/arraymesh.html)：有限頂點／法線與索引生成實際表面。執行相容性以本機 exact4.7.2 實證為準。
- [Molina 等，PLOS ONE，2022](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0264933)：閱讀原研究中離心拉伸與環境氣流使材料成纖的描述，僅作絲流／冷卻的定性靈感。該研究是聚合物非織物，不據此主張糖的溫度、工業物理或食品製程；上述係數均為遊戲標定。
