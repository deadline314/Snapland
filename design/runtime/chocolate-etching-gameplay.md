# 巧克力蝕刻：實際熱線、折料與齒輪傳動

SG-45／game-029。新增2D俯視工藝板：玩家親自描線、選切深、折出三片有實際輪廓的齒輪，再放置及試轉。切線不是完成清單；未閉合、未切透、切壞齒形或擺錯中心距都不會傳動成功。深切一次快但耗料，淺切重描能保留剩料；第四顆惰輪必須從真正剩下的材料取出，介入輸入至出口的路徑。溫度反轉異空間不在本票，不增加基本款數。

## 採用方式與界線

沿用house純Model／Driver／View及Session。專用geometry helper只處理本款有界輪廓、切縫及齒形量測；不建立一般CAD、剛體或編輯器框架。採實際切割多邊形與簡化外嚙合運動學，不宣稱工業漸開線、逐齒剛體接觸或加工精度。捨棄預選成品後按確認，以及無界自由CAD；前者刪除核心描線／剩料取捨，後者超出單款小遊戲。以下數值是controller決定的起始標定，Task1須以公開操作證明路徑後才凍結。

## 材料、輪廓及熱線

材料座標720×440，向右／下為正；原板為Rect2(60,70,590,330)。三個主輪原料中心依序(160,190)、(330,190)、(500,190)。配置A齒數[12,18,12,8]、B[14,12,16,10]；第4個為剩料惰輪。基準模數8，節圓半徑r=4*z；齒頂r+8、齒根r-10。每齒3個頂點：根角phase+TAU*i/z，兩齒頂角再加0.3及0.7個齒距；phase=PI/2-PI/z，使中央輪的下齒與惰輪上齒相向。剩料中心為(330,190+(中輪r+8)+(惰輪r+8)+8)，A為(330,318)、B為(330,302)。前三片折出前不能折第4片。

切深d初值0.5，0.25..1.0、步長0.25；每一筆沿實際折線切入，切縫全寬w=2+6*d*d。深切單筆較寬，兩次同路淺切可累積切深而保持較窄切縫。畫面顯示兩條可選引導：理想齒形外擴w/2，以及外擴w/2+2的厚齒線；玩家可自由畫，不以引導編號直接授予形狀。

按住下刀，移動游標留下實際預覽；匹配的內側放開提交一筆。小於3單位的連續移動可合併取樣，轉角及最後位置須保留；每筆最多512點、每片最多8筆，滿額停止並明示先撤銷，不靜默丟點。端點距<=4可補上真實末段封口（輔助<=7），更大缺口保持開線。取消、外側放開、暫停、失焦／離場丟棄未提交預覽，不幽靈封口、切料或發獎。零長度、非有限座標、超出原板及移除區的輸入不得製造成品。

折料使用最後一個簡單閉合切線作候選；拒絕自交、零面積、中心不在內、超界或與已移除材料相交。沿候選周長等距取128點，逐點累積各實際筆劃的深度：距某筆最近線段<=該筆w/2才貢獻d，各點上限1。所有點至少0.85才可折（AI第二夾持有效時0.75；輔助分別0.75／0.65）。不能以平均值掩蓋未切開的連接，單次0.5淺線不能直接拆出。

實際成品是候選切線向內縮「貢獻筆劃最大w/2」的多邊形；移除／耗料範圍是候選向外擴同距離的多邊形。使用Geometry2D時處理空結果、多輪廓與方向，不假定第一個就是成品；本款只接受單一有效外輪廓且含原料中心，不默選錯誤碎片。任何已提交熱線的實際切縫侵入候選成品內部，都拒絕完整成品；不能忽略穿過輪心的舊切線。用線段與多邊形距離／相交及包圍盒預篩選處理切縫，不把閉合切線外圈誤當整片實心燒毀。剩料第4片的完整耗料範圍必須仍在原板，且與前三片已移除範圍無正面積重疊（面積誤差上限1e-4），並避開所有其他片筆劃的實際切縫。不要給第4片另一塊獨立板、預切成品或剩料旗標。

幾何引擎生成的偏移輪廓可先移除座標完全相同的連續重複點及重複閉合點，不能移動或刪除任何非零短邊端點。這類生成結果以精確有界線段拓撲檢查真正交叉、非相鄰接觸及重疊，不套用描線輸入的1e-4最短邊／間距代理檢查；單一輪廓、原板邊界、含中心、面積、512點上限及後續所有切縫／齒形／材料判定均維持。原始玩家筆劃不因此平滑、改點或放寬自交規則。

齒形以實際成品從中心射線量測：每個根角，以及每齒0.35／0.5／0.65齒距的齒頂區。每條射線需得到唯一最外正交點；根距須在r-18..r-4，三個齒頂區均在r-2..r+14；輔助各放寬2，但不得刪齒或接受圓片。另要求每一齒的三個齒頂區，均至少高於兩側相鄰齒根的較大值4單位，一般與輔助相同；這是實際有齒的獨立條件，不能只憑重疊的半徑容差通過。實際最小齒根距減軸孔半徑8，至少max(6,0.35*r)（輔助0.30*r）；過薄不能傳動。有效節圓半徑為所有根與中央齒頂量測均值的半和+1，模數=2*有效半徑/z。成品外觀、尺寸與傳動都用這個實際多邊形／量測，不替換回模板。

每次真正提交至少8單位、切到尚存板材的熱線才算participated；移游標、換片、改深度、AI、零長按住或空轉不算。未閉合但真實切入的筆劃可算參與，不能算折料成功。折料失敗計1失誤，保留材料及可撤銷狀態，不消耗貨幣。撤銷最近8次已提交熱線／折料／放置操作；可不限次試切重畫，超過8步的歷史不承諾保留。一般撤銷計1失誤，輔助不扣分；均不倒退時間、參與歷史或傳動進度。這個歷史界線須在教學正文寫清楚。

手動基礎夾具固定(80,90)，單人不開AI仍可完成。R開啟簡單AI時，只從仍存在、且在當前輪廓外的板角選一個最遠點作第二夾持；顯示其實際位置。若無合格位置不給較低折料門檻。AI不描線、封口、補深、折料、移輪、連線或轉動。輔助游標可在距兩條引導任一線段10單位內吸附最近線段；不自動走完輪廓，仍需持續描線、匹配放開及自行折料。

## 放置與實際傳動

工藝／試裝共用相同720×440座標範圍。輸入軸固定(200,220)，出口軸A(440,220)、B(416,220)。主輪0、2分別放在距對應軸<=3的位置才接上（輔助<=6）；其餘輪自由放置。所有實際成品邊界需落在材料座標畫布內：放置時用實際輪廓距source_center最遠點的半徑，要求以放置中心為圓心的完整旋轉包絡落在Rect2(0,0,720,440)，確保接觸重設相位及轉完整圈都不出界；即使尚未接入傳動也先保留此空間，不靠逐幀撞邊裁切。不能一次確認自動排列。鍵盤移游標預覽，F在新位置放置；游標仍在已放位置3單位內時F取下。指標／觸控拖動只改預覽，內側放開才提交放置，取消不改原放置。指標／觸控在板內可微調已放輪；原位放開保留傳動進度與撤銷歷史。位置、實際尺寸、連接與角度皆可讀取。

最多4輪，對每對已放輪依實際量測建立接觸：模數相對差<=6%（輔助10%），中心距與有效節圓半徑和之差<=3（輔助6）。太近的主體干涉、齒距不合、未折出或分離都不能當成可傳動接觸。輸入所連的有限圖要能到達出口、途經三個主輪；閉環明示卡齒、停止該網路，不用無界約束求解。僅擺在旁邊或只掛枝節的第4輪不算惰輪資格。

按住Space／轉動才給輸入角速度2 rad/s；相鄰外輪角速度ωj=-ωi*zi/zj。相位依接觸中心線與相反齒相約束設定，實際切出輪廓跟同一角度轉；不是另播完成動畫。有效網路中出口實際轉滿TAU弧度即成功，三主輪必須同在輸入至出口路徑。若唯一路徑還通過由剩料實際切出的第4輪，才devil；4輪路徑因此改變出口方向，整體速比仍由輸入／出口齒數決定。沒有有效出口角速度便不累加進度。放開只停轉，暫停保留已轉進度；實際切料／折料／放置／取下或撤銷結構則將進度清零，不能跨不同網路拼湊一圈。欲挑戰小惡魔，第一次有效完成前先做剩料輪並串入路徑；普通成功後沿用Session再玩／練習，不修改既成結果。

名義未修形參考位置：A普通中輪(320,220)，B(304,220)。四輪參考路徑0→1→3→2：A中輪(303.923048454,160)、惰輪(407.116252650,147.070862063)；B中輪(290.066641994,168)、惰輪(368.249996602,127.609864296)。這只是基準齒形的中心距算例；真正公開操作測試需使用切出後量測尺寸調整位置，不能把算例當遊玩通過。

回合240秒；step只接受有限正delta，每次<=0.25，子步<=1/120，截止前的真實輸出轉動才算。自然正式結束且participated可得普通資格，不要求通關；練習／取消由Session排除獎勵。分數=max(0,已折出主輪數*100+(success?100:0)+(devil?100:0)-mistakes*20)，乾淨普通400／小惡魔500。不要多給第4片基本100分。卡齒只在新一次試轉遇到無效網路時計1失誤，不能每幀扣；鬆開重試仍無效才另計。狀態、筆劃、撤銷、圖及輪廓均有固定上限，snapshot不能回寫模型。

## 公開介面與呈現

ChocolateEtchingModel公開reset(assisted:bool=false,variant:int=0)、set_motion(direction:Vector2)、move_cursor_to(point:Vector2)、cycle_piece()、adjust_depth(direction:int)、begin_tool()、release_tool()、cancel_tool()、fold_or_mount()、place_selected(point:Vector2)、toggle_phase()、toggle_helper()、undo()、clear_input()、step(delta:float)、snapshot()->Dictionary。set_motion用每秒120座標單位推游標，斜向正規化；move_cursor_to走真實線段並限制有效畫布。begin/release在工藝為描線／提交，在試裝為轉動／停止；cancel及clear_input不提交熱線，清空移動與轉動，不還原已提交材料／進度。geometry helper的內部函式由Task1最小實作，後續只消費凍結Model／快照，不重建規則。

snapshot必含elapsed,remaining,score,mistakes,ended,success,devil,ordinary_eligible,participated,assisted,variant,phase,selected,depth,cursor,cutting,driving,helper,helper_clamp,feedback,output_travel,output_omega,connections,source_board,source_centers,pins,parts。parts固定4筆，含teeth,source_center,freed,outline,removed_outline,pitch_radius,module,strength,position,mounted,angle；未取出時outline為空。另含selected_guides兩條實際引導、selected_strokes及current_stroke、undo_available／undo_limit8。只複製選中片筆劃與固定4片成品幾何，不將全歷史附進每幀快照。stock_revision在提交熱線、折料、撤銷及重置後遞增。Driver只在版本改變時以stock_strokes()讀取當前板面全部已提交熱線的獨立副本（最多4片×8筆×512點）。剩料保留各片切痕，已折出的孔洞遮住切痕。HUD與工藝板共用向下取整的出口百分比，成功時才顯示100%。

outline、removed_outline、引導及筆劃均為原板絕對座標；position為試裝中心，angle為弧度，試裝點=(原輪廓點-source_center).rotated(angle)+position。connections為Array[Vector2i]，每對及整體按索引遞增排序，不放可變共享節點。順／逆時針描同一輪廓都可成立，不能暗藏模板頂點順序要求。

Driver沿用house reset(assisted,time_phase)、create_view、handle_input(event,design_point)、clear_input、step、snapshot、present(time_phase,reduced_motion)、score_summary(practice)。12命令依序left/right/up/down/select/shallow/deep/tool/fold/phase/undo/helper；WASD與方向鍵移游標、Tab換片、Q/E淺深、Space按住下刀／轉動、F折料／放置原位取下、M換工藝／試裝、X撤銷、R夾持AI。方向鍵可與同鍵盤Space同時按住；非同來源不能搶控制，鍵盤echo／第二指／合成滑鼠不得重複。換片／改深度／換工作面先取消未提交描線。暫停、失焦、tree_exiting、重試及離場都清持續輸入。

連續移動以實體按鍵集合計算：W與上鍵同時按住不加倍速度，放開其中一個仍保留另一個；相反方向抵消，釋放後恢復仍按住方向。活動工藝板需真正取得焦點並接收Tab等鍵，不把GUI預設焦點跳轉誤當換片成功。Main的M地圖快捷鍵已有session==null條件，保持此界線；遊戲內M由本款切換工作面。

View公開COMMANDS／KEYS及靜態command_at(design_point:Vector2)->String、command_center(command:String)->Vector2、board_to_design(board_point:Vector2)->Vector2、design_to_board(design_point:Vector2)->Vector2。輸入、繪圖與驗證共用同一等比畫布轉換及按鈕幾何，不在各層另抄比例常數；有效畫布外放開不夾回邊緣提交。

View為2D俯視工藝板，固定1280×720設計座標；保留Main首140高度，狀態自140以下；畫布Rect2(24,242,880,390)內等比映射720×440，12按鈕置右側Rect2(916,242,340,390)的3欄4列，底部保留精簡模型回饋。兩模式清楚標題、實際殘料／孔洞／切深／輪廓／夾持／已放輪／預覽虛線／軸／接觸線／轉向及出口進度。少量常駐CanvasItem與固定按鈕，無逐幀Node／材質建立；必要幾何與轉動／接觸狀態不能被降低動態刪除。核心規則寫在畫面／教學；hover只提示「放開提交／外側取消」「淺切可重描保料」「先做惰輪再試轉」「撤銷不回時間」「AI只夾持」。三尺寸1280×720、1152×648、800×600（大字1.25、降低動態）所有活動文字及12控制、5規則頁與全部教學文字頁都需完整可用。

## 接入、範圍與證據

固定game-029／chocolate_etching／candy local_index5／photo-candy-game-5／photo-candy-devil-5／ACH_GAME_029；實際28→29、工廠4→5/12，128候選不變，030為首款未實作。實際入口(10.5,GROUND_Y,-0.8)，保留原4入口／資訊／返回；初步檢查在右上LAND內且避開(11.4,-2)缸體，Task3須實際物理最近入口核對，有衝突先報告。第29列補拍沿用原有固定道具語彙。無Progress schema、Steam物品／交易、獎勵策略、音訊框架或正常玩家入口／輸出排除改動。

三張教學原圖來自真實原生操作：有實際描線及切深／尚連接；三片取出後真實可轉網路；保留殘料做第4惰輪並真實帶動出口。單張靜態圖不冒稱整個切割／通關；解說明示AI／輔助、8步撤銷、普通／惡魔條件。原生不得注入029幾何、成品、傳動、成績、照片、成就或獎勵；Model公開操作可以找可行路徑，Driver／Session／原生需對應真實事件。只允許獨立存檔的六張迎賓前置及已看開場，受控站位後實際E，不稱步行／新檔賺入園資格。

所有Godot使用validated launcher／exact4.7.2；SceneTree --script，Node真.tscn。每個程序獨立D絕對save／APPDATA／LOCALAPPDATA／TEMP／TMP／stage／capture／export，只有成對reader共享writer save。prepare_runtime_stage為tracked runtime加精確fixtures/helper閉包，排除C cache／未追蹤UID/import／整庫或整test tree／舊接受包。每次launch前審查完整fixture/helper及實際staged腳本有無間接OS啟動；本地不執行四個既知fault-child父套件test_photo_retake_main、test_region_travel、test_photo_retake_progress、test_region_progress，保持CI註冊。不能再把不合啟動邊界的歷史父／子結果列為通過。

局部Model／Driver／View／Session／Main、受影響既有工廠／收藏／教學與Python／design契約；原生3尺寸、四組指定GPU補拍（普通與惡魔1280、普通800、惡魔1152）及新程序、全新獨立嵌入Windows QA執行檔writer／reader均須實證。正常gameplay保留最新完成畫面更新；retake原圖／路徑／來源在真實挑戰及新程序後不變。來源原始／Git換行雜湊分清楚，不改歷史原圖／log／receipt／exe來造一致。腳本、數值、GPU與設計檢查不是真人試玩、試聽、美術自然度、實體觸控或跨裝置效能；ART16/17、MIC1..3、ST5不因此結案。

## 參考資料與採用範圍

- [WM Berg Gear Reference Guide](https://www.wmberg.com/documentation/metric-catalog/reference-section_metic.aspx)：模數、節圓及兩輪中心距關係；遊戲容差／熱切材料係數為本作標定，不冒稱製造規範。
- [KHK Idler Gear](https://khkgears.net/new/gear_knowledge/gear-nomenclature/idler-gear.html)：中間惰輪可改方向／跨距，簡單輪系整體速比由輸入與輸出齒數決定。頁面open回傳壓縮亂碼，搜尋索引文字可讀；只採用可見基本說明，不引用不可讀內文。
- [Godot Geometry2D](https://docs.godotengine.org/en/stable/classes/class_geometry2d.html)、[2D custom drawing](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html)：內建多邊形運算及CanvasItem繪圖；本機exact4.7.2實際驗證才是執行相容性依據。
