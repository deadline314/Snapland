# SG-19 人潮指揮：交通調度設計

## 現況與設計範圍

我唯讀檢查了 `game/minigames/session.gd`、`game/data/welcome_games.json`、SG-19 在 `design/runtime/first-park-gameplay-quality.md` 的提案，以及 `game/tests/test_minigames.gd` 的既有案例。現在每 2.2 秒取 `count % 2` 作為新隊伍方向，再比較 `lane`：方向相同便加 50 分，不同便記一次失誤，六次後結束。Q/E 與點擊都只在兩個方向間切換，所以玩家可固定交替按鍵，無需看路口或安排服務順序。票面要求六隊安全通過；小惡魔條件是六隊全通過且號誌方向正確。

以下是後續實作規格，不是遊戲實玩紀錄，也不是現行交通工程控制器。它把行人號誌的辨識、等候、通行與清空規則縮成一個短小、固定可重播的遊戲事件序列。

## 建議的可玩循環

保留一個路口、兩個互斥行人方向、六個固定需求群組。需求次序為「橫向、橫向、縱向、橫向、縱向、縱向」，於 0.75、1.5、2.4、3.1、5.1、7.1 秒抵達，讓兩向隊伍實際重疊等候；人數固定為 2、3、2、4、2、3。最後一組進場後只等候既有隊伍清空或耐心耗盡，不再抽新需求。兩個方向各有自己的路邊隊列、隊首目的地、等待計時與排隊人數。連續同向需求讓保留號誌有實際價值；方向切換仍必要，但不再是無條件 Q/E 交替。

玩家控制的是「哪一向的行人可開始過街」：Q 明確選橫向，E 明確選縱向；點擊對應的方向箭頭選同一方向。按目前方向不切換；重複輸入只重選方向，不能縮短安全轉換。另一方向即使隊列很長，在紅燈期間所有人都停在線後，不能踏入斑馬線。沒有適用隊列時放行該方向不會移動其他方向的隊伍，只會浪費一段可服務時間。

每次放行有四個可見狀態：紅燈等候、行人綠燈、行人清空、全紅切換。綠燈期間，隊首群組以固定速度從路緣進入並穿過斑馬線；只要群組踏上路面，玩家即使要求切換，也要讓該組走到對側路緣。之後播放短暫清空倒數與全紅間隔，才可亮起另一向的行人綠燈。轉換中再次輸入只更新「下一個相位」，不重置清空計時。預設空隙可以是 0.35 秒清空加 0.25 秒全紅；這些是便於節奏遊戲理解的遊戲時間，不宣稱等同實際道路時間。

等候群組的耐心以隊首旁的形狀刻度顯示，普通群組 5.5 秒；過期後該組離開、記為未服務，不發生碰撞，也不能再拿安全通行分。玩家可在另一方向通行期間看見對側累積隊列，並在一組走完後決定是否切換。紅燈擋住所有未入場群組；已入場群組則在清空狀態下完成，讓玩家能清楚分辨「正在等」和「正在過」。這呼應官方行人訊號的 WALK／清空區別：紅色站立圖示時不開始過街；訊號變化時已在路上的人仍應完成清空。[GOV.UK 行人與號誌控制路口指南](https://www.gov.uk/government/publications/know-your-traffic-signs/pedestrian-cycle-and-equestrian-crossings) 說明了等候、開始過街與清空的差別；[FHWA MUTCD 第 11 版第 4 部](https://mutcd.fhwa.dot.gov/pdfs/11th_Edition/part4.pdf) 也將 WALK、行人變換區間和行人清空時間分開描述。

第四組固定是港區救援隊，隊伍攜帶擔架，有獨特旗形標記與較短的 3.5 秒耐心。它仍須等候自己方向的行人綠燈，不能在紅燈下闖入，也不能截斷已經開始的另一組。若另一方向尚有群組穿越，救援隊留在路緣等候；同向隊伍依抵達順序通行；玩家必須在下一個安全放行時，將較短耐心的救援所在方向排在另一向之前。這提供一次明確的優先請求，但不另加隨機事件或新按鍵。真實緊急車輛號誌優先在切入優先控制時保留黃燈和紅燈清空區間；此處只借用「先清空、再優先」的次序，救援隊本身仍是行人，並非車輛號誌預先控制的模擬。[MUTCD 第 4F.18–4F.20 節](https://highways.dot.gov/media/111811) 說明緊急車輛優先／預先控制及轉換時不得縮短的清空區間。

## 命中、失誤與分數

群組只有完成整條斑馬線才算安全通過。紅燈隊伍保持不動；選到一個沒有隊伍的綠燈不構成安全事件，但會消耗等待時間。群組等候過期算一次漏服務，任何錯向群組都不會被模型移進路口，因此不會用碰撞動畫掩飾控制規則。轉燈過程中不會有兩向同時綠燈，也不會切斷已入場群組。

保留現在每組安全通行 +50 分，六組基礎上限 300。每組再依隊首從到達到開始過路的等候時間給效率分：不超過 2.2 秒 +20，2.2–4.4 秒 +10，超過 4.4 秒 +0。救援隊在耐心耗盡前安全完成另加一次 +50；等待逾時或未完成不給效率／救援分。總分上限 470，結算列出六組的安全結果與等待秒數、救援隊等待、未服務組數，讓分數能由實際事件重算。

普通拍貼仍要求六組都安全完成；未服務任何一組即未達普通門檻。小惡魔要求六組全通過且效率總分至少 430：要求沒有群組逾時，救援隊也在安全切換後完成；選擇空隊列不直接扣成就，但浪費的時間會影響等候與通過結果。普通資格不因等待效率分低而失效。這保留票面收藏門檻，同時讓高品質操作反映在可查核的等待與訊號事件，而非固定按鍵節拍。

## 教學與視覺回饋

教學依完整截圖介紹四個狀態，不回到常駐長提示：

1. 路口初始圖：兩個方向箭頭、兩側紅燈隊列，清楚標出 Q／E 與點擊目標。
2. 一向綠燈圖：只有該方向的人從路緣進場；另一方向的人留在停止線後，隊列與耐心刻度可見。
3. 切換圖：已入場隊伍走到對側、清空倒數、全紅與待切方向依序呈現。
4. 救援隊圖：擔架／旗形符號與短耐心計時，顯示不得截斷目前過街群組，清空後才優先服務。

相位不能只靠紅綠顏色區分：方向箭頭、站立／行走人物、停止線和清空倒數都要一致。NYC DOT 的無障礙行人訊號把方向箭頭放在相應的按鈕旁，並以「wait」及 WALK 回饋區分等候與可行走狀態；遊戲至少應保留相同的方向對應與非顏色線索，字幕／按鍵提示也需與點擊區相同。[NYC DOT Accessible Pedestrian Signals](https://www.nyc.gov/html/dot/html/infrastructure/accessiblepedsignals.shtml) 與 [FHWA MUTCD 第 4K 章](https://mutcd.fhwa.dot.gov/pdfs/11th_Edition/part4.pdf) 提供了箭頭、訊號方向和多感官回饋的第一方範例。

固定需求序列配短週期可讓玩家預測下一組，但不能讓序列變成「每次必須換燈」。NACTO 指出短週期可縮短行人等待，而過多相位會增加所有方向的等待；因此本局只保留兩個行人方向、紅燈等待、綠燈通行、清空和全紅，不再為普通組、緊急組各加一套燈號。[NACTO Signalization Principles](https://nacto.org/publication/urban-street-design-guide/intersection-design-elements/traffic-signals/signalization-principles/) 對週期與相位數的建議支持此取捨。Seattle DOT 的行人訊號政策則把清空時間與路口寬度及步速連結；本遊戲不照搬真實秒數，而是讓固定過街速度、清空倒數和畫面距離共用同一個遊戲事件時鐘。[Seattle DOT Pedestrian Signal Timing Policy](https://www.seattle.gov/documents/departments/sdot/technologyprogram/pedestrian_signal_timing_policy_january_2021_signed.pdf)

## 技術驗收與實玩問題

- 固定序列逐組重播，確認順序為 H、H、V、H（救援隊）、V、V，兩側隊列及耐心均可預測；不存在隨機來人。
- 紅燈方向任何時候都不移動。行人入場後，即使按 Q/E 或點擊反覆切換，也必須先完整抵達對側，完成全紅間隔後才能放行另一向。
- 短按、長按、按鍵重複、同向重選與轉換中連續輸入都不會跳過行人清空。方向箭頭點擊與 Q/E 都選擇同一個 lane，點擊錯誤處不改變相位。
- 同向連續需求時保留相位能依序服務隊列；在等待的另一方向需求出現後，切換會消耗已顯示的安全間隔。救援隊出現時不能截斷在路上的組別，安全清空後它才優先開始。
- 對每一組獨立驗算安全分、等待效率和過期結果；普通只在六組安全完成時取得，小惡魔還要通過無逾時與全部安全通過檢查。錯誤不靠直接設置完成旗標或減弱既有門檻測試。
- 暫停時凍結所有隊列、計時與清空相位；恢復不會讓隊伍或訊號跳時。降低動態設定停用人物 bob 與不必要閃爍，但保留相同的隊伍位置、箭頭形狀和倒數語意。
- Root 實玩需確認六組需求與一次救援事件在不到約 20 秒的局內節奏仍可讀；驗證錯向不是靠紅燈顏色而是停線和人物姿勢也能看懂、點擊目標足夠大、連續同向隊伍確實讓玩家選擇「保留」而非固定交替。

## 參考來源

本設計讀取以下第一方交通機關來源；它們提供安全及訊號溝通原則，不代表曾實玩本遊戲：

1. [FHWA MUTCD 第 11 版，第 4 部：行人訊號、清空區間與無障礙訊號](https://mutcd.fhwa.dot.gov/pdfs/11th_Edition/part4.pdf)。
2. [FHWA：Leading Pedestrian Interval](https://highways.dot.gov/safety/proven-safety-countermeasures/leading-pedestrian-interval)。
3. [NACTO：Signalization Principles](https://nacto.org/publication/urban-street-design-guide/intersection-design-elements/traffic-signals/signalization-principles/)。
4. [NYC DOT：Accessible Pedestrian Signals](https://www.nyc.gov/html/dot/html/infrastructure/accessiblepedsignals.shtml)。
5. [Seattle DOT：Pedestrian Signal Timing Policy](https://www.seattle.gov/documents/departments/sdot/technologyprogram/pedestrian_signal_timing_policy_january_2021_signed.pdf)。
6. [GOV.UK：Pedestrian, cycle and equestrian crossings](https://www.gov.uk/government/publications/know-your-traffic-signs/pedestrian-cycle-and-equestrian-crossings)。
7. [FHWA MUTCD 第 11 版：Preemption and Priority Control, Sections 4F.18–4F.20](https://highways.dot.gov/media/111811)。
8. [NYC DOT：Traffic Signals, exclusive pedestrian phases and leading pedestrian intervals](https://www.nyc.gov/html/dot/html/infrastructure/signals.shtml)。

## 開場與操作裕量驗證

固定抵達時間保留 0.65 秒開場與 0.30 秒反應；於 0.95 秒首次選擇橫向，先讓同向兩隊與救援隊通過，再放行縱向三隊，可得到六隊安全、430 分。只依全局最早抵達切換方向會讓救援耐心耗盡，因此兩側隊首的等待期限是實際決策；同一方向仍遵守排隊次序。這是模型驗證，不視為真人試玩。
