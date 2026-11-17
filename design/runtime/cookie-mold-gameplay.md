# 餅乾翻模：鬆角、翻轉與滑接

SG-42／game-026，糖果工廠第二款基本遊戲。沿用目錄的六塊異形餅、手部近景、凹口／餅厚變化及翻模慣性雙層餅。使用者授權自主裁決；以下為 model／driver／view 共用契約，無待答設計問題。沿用 SugarBridge 的獨立模型、控制器、保留式 3D 視圖與 Session 生命週期，不搬用貨物平衡玩法。

## 開工裁決

| 選擇 | 裁決與理由 | 成本／邊界 |
|---|---|---|
| 真實操作 | 連續模角、指定邊角蓄力敲擊、移動接盤三者各有用途 | 沒有「成功敲擊」或直接取出按鈕 |
| 材料模擬 | 固定多邊形邊緣黏附、累積裂損、剛體慣性與彈道 | 不做軟體網格、碎片碰撞或新依賴 |
| 雙層餅 | 第六塊齒輪是雙層；完整脫模及接住才計一塊 | 六塊自然結束，不額外要求第七塊 |
| 失手 | 裂餅／掉地後免費重做當前形狀；已接住的保留 | 150 秒總時間不回復；正式重試換配置 |
| AI／輔助 | AI 僅將接盤保持於出口垂直下方；輔助提高裂損上限與接盤容差 | 不翻模、不鬆角、不預測拋物落點、不設結果 |
| 結算 | 六塊接住即成功；逾時正常失敗；參與且正常結算有普通資格 | 練習／取消由 Session 排除；小惡魔仍須成功及真實雙層挑戰 |
| 參數 | 下列數值是共同起始標定；模型作者以實際操作軌跡校準係數 | 調整須記錄最終值與成功／失敗證據，不改 API、條件或偷改分數 |

## 座標、形狀與固定容量

長度以工作單位、時間秒、角度弧度。工作平面 x 向右、y 向上，深度 z 向後；剛體只在 x/y 運動與繞 z 旋轉。模具樞軸 `P=(0,2.8)`，初始開口朝上，角度 θ=0；順時針為正，開口法線 `n=(sinθ,cosθ)`，面內切線 `t=(cosθ,-sinθ)`。餅心／出口 `C=P+0.45*n`。多邊形本地座標 `(u,v)` 對應 `C + u*t` 的 x/y 與深度 z=v；厚度沿 n 擠出。View 以同一座標轉成真正 3D mesh，不能只換圓片顏色。

每局六個固定 slot，一次僅一塊活動餅。順序為五角星、心形、魚、葉、五瓣花、雙層齒輪；每形 8–32 頂點，最大半徑 0.62。星採交錯內外徑；心含頂部凹口與底尖；魚含窄尾柄和叉尾；葉含尖端、不對稱兩側；花五個圓弧花瓣；齒輪八個平齒。輪廓是可見網格與黏附採樣的同一資料，不能六個相同圓形。用固定頂點表或有界生成式，凹多邊形由 Godot 既有 triangulate_polygon 分面；上下面與側面均有實體厚度。

配置 A：凹口倍率 1.0、單層厚 0.16；配置 B：凹口更深（內凹頂點向心縮至 0.78 倍）、單層厚 0.21。雙層為兩個相同輪廓、每層當局厚度，中間夾心 0.035；整體厚度參與應力／幾何，兩層不能分別算分。配置 B 實際改變邊緣幾何、黏附與抗裂，非僅改名字。重做當前餅不換配置；Session 整局重試以有界輪次交替 A/B。

每個多邊形邊中點是一個敲擊位置與黏附單元；最多 32 個。每單元保留 `adhesion`（0–1）、`stress`（0–裂損上限）、`notch`（由相鄰凹頂點判定）；全局僅六 slot、一個活動剛體、一個接盤、固定長度邊陣列。不能累加無界敲擊／軌跡歷史。

## 物理與結果順序

`step(delta)` 忽略非有限／非正值，單次上限 0.25 秒，拆成最多 30 個 ≤1/120 秒的子步。所有公開 float／Vector2 輸入先驗證 finite，再 clamp。無效輸入不改狀態。角度以 [-π,π] 的最短差值控制並 wrap，角速度限 ±5 rad/s。快照須深複製嵌套資料。

每個子步固定順序：計時與蓄力 → 翻模／接盤 → 邊緣受力／裂損 → 脫離 → 飛行／掃掠接盤 → 落地或成功 → 逾時。最後一塊若在截止的有效子步內先接住，即成功。

1. **翻模。** 抓持時 `alpha=clamp(28*angle_difference(theta,target)-7*omega,-22,22)`；放手時 `alpha=-1.2*omega`。半隱式更新 `omega+=alpha*h; theta+=omega*h`。放手保留 omega，不瞬停；模型 clear_input 同樣停止外力／蓄力，不能發出敲擊。初始餅、模具同速，未脫離時餅跟隨出口。
2. **接盤。** 盤頂 y=-0.8，半寬 1.15，深度半寬 0.85；x 範圍 [-3.2,3.2]，以每秒最多 4 單位追隨目標，不能瞬移。AI 啟用時每子步目標=C.x；不追飛行餅。手動移盤關閉 AI。保留前後盤中心做掃掠插值。
3. **黏附與敲擊。** 初始每邊黏附 `0.70+0.20*notch`；凹口對實際脫模造成較難鬆開的邊。選定敲點按住 0–0.9 秒，放開才敲；力度 `f=0.15+0.85*clamp(charge/0.9,0,1)`。邊 i 距敲點本地距離 d，權重 `w=max(0,1-d/0.95)`，黏附減 `0.78*f*w/thickness_ratio`（`thickness_ratio=整塊餅厚/0.16`，雙層含夾心）。應力增加 `0.40*f²*w*(1+0.6*notch)*(1+0.65*max(0,cosθ))/thickness_ratio²`；上開口重敲比倒扣輕敲危險。應力不自動回復，達 65% 顯裂紋預告，達上限即裂餅。標準上限 1.0、輔助 1.45。連續重敲同點會裂；分散鬆角有價值。
4. **自然拉脫。** 朝出口的重力加速度 `g_out=max(0,-7.5*cosθ)`；慣性加速度 `a_inertial=omega²*0.45`；`pull=g_out+a_inertial`。每邊當前阻力 `resistance=12.0*adhesion*(1+0.35*notch)*thickness_ratio`。只有 `pull>resistance` 的邊每秒減少 `0.20*(pull-resistance)` 黏附，並增加 `0.012*(pull-resistance)*(1+notch)/thickness_ratio²` 應力；敲擊可鬆黏附但不能直接設脫模。全部邊黏附 ≤0.03 且 n.y<−0.15 才整體脫離。雙層額外要求整體應力低於上限；不得只把黏附歸零當成功。初始完全不操作永遠不會自行完成；完全未鬆角的餅不能只靜止倒扣便自然掉出。
5. **釋放與慣性證據。** 放出位置 C，初速 `v=0.45*omega*t + n*clamp(0.08*pull,0.25,1.1)`，保留 omega 作飛行旋轉；沒有自動對準盤的速度。記錄該餅釋放瞬間的 `release_omega`、`release_inertial`、`release_gravity`。雙層小惡魔候選必須 `abs(release_omega)>=2.0` 且 `release_inertial>=0.35*release_gravity`，並完整；只有隨後真接住該剛體才鎖定 `double_layer_inertial_caught`。任何重做清除當前候選，不能靠 UI 開關、單次翻模紀錄或預先勾選獎勵。
6. **飛行與接住。** `v.y-=7.5*h; center+=v*h; cookie_angle+=cookie_omega*h`。每子步由全部頂點及厚度兩端投影求完整餅 x/y 包圍範圍，不只看中心。餅底從盤面以上向下跨越盤面時，以前後餅底線性插值得碰撞時刻，插值餅心、角度與盤 x，再重算整體 x 範圍；只有完整餅左右都落盤內、深度亦容納、完整且下降，才接住。輔助只在盤的左右各加 0.22 容差；仍必須真的向下跨越盤面。從側面擦過／越過盤面後移盤均不補判。漏接後落到 y<-2.4 或 x 超出 ±6 即 `missed`；裂餅為 `cracked`，都等待免費重做。

每次接住保留該 slot 的完成紀錄，0.45 秒後自動上下一塊；第六塊直接自然結束。分數 `max(0,100*caught + (success?100:0) + (devil?100:0) -20*mistakes)`，每次裂或落地只加一次 mistakes。普通資格：玩家曾有效翻模、敲擊或移盤，並正常成功／逾時；AI 切換、等待、取消不算參與。小惡魔：整局成功且 `double_layer_inertial_caught`，與 assist/helper 狀態無關。

**起始標定的兩條操作軌跡。** 溫和路線：直立時逐邊 0.16 秒蓄力輕敲，僅重敲仍黏附的邊，直到最大黏附 ≤0.15；以每秒約 0.9 rad 的目標增量慢慢倒扣，停住讓重力完成拉脫，盤保持出口下方，依真實餅位置滑接。雙層同法可普通完成而不觸發慣性條件。慣性路線：同樣鬆角到 ≤0.15，從直立快速把目標轉向 2.8 rad，使向下開口時仍有大於 2.5 rad/s 角速度，必要時放開維持轉勢；捕捉實際釋放速度及飛行，再滑盤接住。這是 builder 的可重播輸入起點，不是自動解法 API；測試可以讀快照選仍黏的邊和移盤，但不可修改狀態。若兩配置／某形狀不穩定，以局部係數標定修正並留下實際序列；仍須證明重敲會裂、未鬆角靜止倒扣不放出、低慣性不授惡魔、漏盤會失敗。

## 凍結接口與控制路徑

新增 `cookie_mold_model.gd`、`cookie_mold_driver.gd`、`cookie_mold_view.gd`，mode=`cookie_mold`。Model 公開方法如下，除 reset／snapshot／clear_input 外 ended 時皆不變更：

| 方法 | 契約 |
|---|---|
| `reset(assisted:bool=false,variant:int=0)` | variant 正模 2；六個 slot、第一塊、150 秒重設 |
| `set_mold_target(angle:float)` | 有限角度 wrap；開始抓持目標；只能 molded 狀態操模 |
| `release_mold()` | 結束抓持，保留角速度；不敲擊 |
| `select_edge(step:int)` | 正／負換相鄰邊；0 忽略；蓄力中不可換邊 |
| `select_edge_at(local_point:Vector2)` | 選最近邊中點；限本地半徑 1 以內；蓄力中忽略 |
| `begin_tap()`／`release_tap()` | 僅 molded；重複 begin 不重設蓄力；只有已蓄力 release 才施力一次 |
| `set_tray_target(x:float)` | clamp 盤域、關閉 helper；不直接移動盤 |
| `toggle_helper()` | 只切換上述出口保持；不計參與 |
| `retry_cookie()` | 僅 cracked/missed 免費恢復當前 slot，重設模角／速度／邊緣；不回復總時間／mistakes／已完成數 |
| `clear_input()` | 取消抓持／蓄力，charge=0；不施敲、不移盤、不改結果 |
| `step(delta:float)`／`snapshot()->Dictionary` | 物理唯一更新入口／完全脫離模型的值 |

Snapshot 必有 `elapsed,remaining,score,mistakes,ended,success,devil,ordinary_eligible,participated,assisted,variant,feedback`；`caught` 整數、`completed` 六 bool、`shape_index,shape_name,polygon`（本地 Vector2 陣列）、`thickness,double_layer`；`phase` 為 molded/flying/caught/cracked/missed；`mold_angle,mold_omega,mold_target,mold_held,pivot,outlet`；`edges` 含 `point,adhesion,stress,notch`，以及 `selected_edge,charging,charge,crack_limit`；`cookie_position,cookie_velocity,cookie_angle,cookie_omega,release_omega,release_inertial,release_gravity,double_layer_inertial_caught`；`tray_x,tray_target,tray_y,tray_half_width,catch_tolerance,helper`。Driver 可加 progress_text/time_text/feedback_text，不另算物理或資格。

Driver 沿用 `reset(assisted,time_phase),create_view(),handle_input(event,design_point),clear_input(),step(delta),snapshot(),present(time_phase,reduced_motion),score_summary(practice)`。保留式 View 發 `command_requested(command,pressed,source)`／`pointer_requested(action,point,source)`；driver 才持有模型與輸入 ownership。

- 鍵盤 A/D 持續以 2.8 rad/s 改目標，鬆開兩鍵即 release_mold；左右鍵以 4 單位/s 改盤目標；Tab／Shift+Tab 換邊；Space 按住蓄力、放開敲；R 切換 AI；X 免費重做當前失敗餅。非蓄力狀態才換邊，鍵盤 echo 不重複觸發。
- 滑鼠／單指：拖模具外側把手，以相對樞軸角度連續設定模角；放手保留慣性。點可見邊緣即選點並開始蓄力，放開敲；拖盤只改盤目標。移到別的邊不偷換蓄力點。按鈕另提供「左翻／右翻」「上一角／下一角」「按住輕敲」「左移盤／右移盤」「AI 扶盤」「重做此餅」，讓小螢幕與純觸控可完成全流程。
- 一次只有一位操作所有者（mouse、touch:index 或 keyboard），同一擁有者可連續鍵盤動作；其他手指／裝置不能接管正在拖曳／蓄力的動作。排除觸控模擬 mouse；所有 release 與 cancel 皆先清除 ownership。touch canceled、失焦、暫停、離場、retry、View tree_exiting 均 clear_input，不誤敲。移除場景後無殘留按鍵；盤停止接受新目標。鍵盤／按鈕／指標全部呼叫上述相同模型方法。

## 手部近景與玩家文字

採固定斜俯視正交相機與近距工作台；可看見模具腔、六種輪廓的側壁厚度、雙層夾心與盤沿。模具、餅、接盤是真正擠出 mesh；邊緣間隙隨 adhesion 減少，裂紋以固定數量線段隨 stress 出現，選中敲點有環，非僅靠紅綠辨識。固定重用 mesh/node/material；換形時只重建有限形狀網格，逐幀不新建節點。

左手固定握模柄並跟模角轉動，拇指包住上緣、指節分段可見；右手在選點上方蓄力收拳、敲下後回彈；移盤時右手貼住盤柄。這些是模型狀態驅動的可辨識手勢，不以兩顆球代手。降低動態取消裝飾搖鏡與敲擊殘影，保留必要模轉、飛行與接盤。必要操作不得藏在 hover。

HUD 短句：「完整接住 0／6」「先鬆黏角，再翻模滑接」「裂紋加深了，換一角輕敲」「雙層餅：借翻轉慣性取出，再接住」「餅乾掉了，免費重做」「AI 只扶盤，翻模由你」。顯示當前形狀、六枚完成輪廓、角度／慣性箭頭、蓄力條、局部裂紋、時間。一般模式也看得到黏附／裂損預告；輔助不隱藏或替代因果。遵循既有 FontProfiles／共用 HUD 字級；800×600 放大文字下控制與盤面仍可操作。

## 整合與驗證邊界

呼叫與資料改動須一併抵達：Session driver 註冊、Candy 可玩清單／GameCatalog／設計 catalog、真實工廠入口／地圖／收藏頁、操作教學與圖、固定 itemdef 普通／惡魔卡 local 2、ACH_GAME_026、Retake PROPS 實際道具第二十六列、共用補拍與保存、測試執行清單及設計 verifier。Candy 開放數 2/12、全島可玩 26；規劃仍為當區普通 18／惡魔 12、普通總 180 開終區，不把開放兩款冒充十二款。離線收藏／Steam 固定經濟沿用既有分離，不新增消耗。

模型測試只由公開操作與 step 產生結果：六種真輪廓、兩配置、分角輕敲／重敲裂損、放手慣性、真釋放與飛行、移盤成功／錯盤落地、免費重做、雙層低慣性普通接住與高慣性小惡魔接住、AI 單獨不完成、輔助仍需操作、時間／無效值／深複製／固定容量。必須留下至少一條可重播的普通及小惡魔完整操作軌跡；測試不可寫內部 adhesion／phase／caught／score／資格，不能直接呼叫成功回呼代替碰撞。

Driver／View 覆蓋鍵盤、滑鼠、touch、單擁有者、取消不敲、暫停／恢復／失焦、視圖移除、重試與字級／降低動態。Session／Main 覆蓋真入口、六塊自然結算、逾時、取消、練習不發卡、固定 ID／ACH 去重、所有實際補拍入口再開與新程序保存重開。原 25 款相關回歸保留。必須實跑 Godot 4.7.2；所有會寫存檔的命令使用獨立 SNAPLAND_SAVE_PATH。

最低交付三張真 Main 1280×720 PNG 至 `pm/Snapland-small-game/images/`：近景操作含裂紋／間隙、雙層實際飛行或接住、正式結果與收藏證據；另驗證 800×600 放大字及寬螢幕。截圖不得用設計板冒充實機，局部模型／原生腳本驗證不得描述為真人試玩成功。模型作者須記錄最終校準值及可重播輸入；根代理整合審核後才勾選票與 commit/push。
