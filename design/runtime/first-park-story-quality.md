# ST-4｜迎賓角色與園區故事品質基線

## 已讀的一手來源與採用原則

以下來源均讀取了頁面正文指定段落；沒有把網頁插圖或嵌入影片當作已檢視的證據。

| 團隊／來源 | 實際閱讀範圍與可核對內容 | 對迎賓故事的具體採用 |
|---|---|---|
| inkle，《Autocut!》 | [開發文章](https://www.inklestudios.com/highland/2023/05/11/autocut-for-responsive)，正文第 7–36 行。文章說明如何追蹤玩家已讀／跳過內容，並讓對話退出更俐落。 | 台詞保持短句，事件應可重入；已完成的步驟不能靠重看對話重發獎勵。沒有採用其特定對話系統或剪輯演算法。 |
| Supergiant Games，《Hades》官方 FAQ | [官方 FAQ](https://www.supergiantgames.com/blog/9/)，正文第 83–86 行回答角色敘事與互動。 | 票票、小角、阿浪需有自己的動機，回訪時用狀態或短句回應；重播服務性對話不應重置任務。沒有複製其角色語氣或希臘神話題材。 |
| CD PROJEKT RED，Sarah Grummer 任務設計訪談 | [官方訪談](https://www.cdprojektred.com/en/blog/155/turning-emotions-story-and-big-moments-into-gameplay)，正文第 26–43 行。訪談將情緒目標、玩家可做的挑戰與跨團隊實作連結起來。 | 每個任務步驟都必須改變玩家在園區中的行動或取得可驗證結果；本設計把新構圖試拍連到長椅照片與泡泡合照，把指路焦慮連到觀察和人潮遊戲。沒有借用其大型敘事規模。 |
| Ubisoft Narrative 團隊，《Far Cry 6》故事設計 | [官方文章](https://news.ubisoft.com/en-au/article/1z2FrTnA3EsZ58iQUc2fcE/finding-new-ways-to-tell-stories-in-far-cry-6-and-lost-between-worlds)，正文第 27–35、41–53 行。內容說明分階段介紹人物、非線性探索中的固定敘事節點，以及用 Twine 原型測試文字流程。 | 抵達引言先交代方向與角色，玩家可離開再回來；主要任務用固定三個可驗證節點，保持支線次序清楚。沒有採用其章節結構或世界觀。 |
| Guerrilla Games，《Horizon Zero Dawn》Gildun 角色訪談 | [PlayStation 官方訪談](https://blog.playstation.com/2017/12/19/creating-a-character-guerrilla-explains-how-gildun-was-made)，正文第 59–70、75–89 行。設計者描述先從任務與地點的失敗鏈出發，再推導角色的動機與反應。 | 小角把打結尾巴的尷尬想成彩帶構圖點子，請玩家以自己的角色試拍；這是對話設定，園區目前沒有實際布景修復或小角入鏡狀態。阿浪則擔心指示牌方向造成分流；人物語氣由這些問題推導。沒有模仿 Gildun 的喜劇個性。 |
| Santa Monica Studio，《God of War》探索任務設計 | [PlayStation 官方文章](https://blog.playstation.com/2018/12/05/how-santa-monica-studios-nailed-exploration-in-god-of-war)，正文第 57–63、72–108 行。設計者區分探索內容層級、早期可見互動、簡短任務說明與可跳過背景資訊，並拒絕只有跑腿的任務。 | 主要目標用短句告訴玩家做什麼，額外角色背景可選讀；三步任務各自使用互動、拍照／觀察或小遊戲成果，不以純問答取代園區行動。沒有照搬其地圖與任務層級。 |

## 迎賓人物與可玩的任務

票票是導覽亭值班員，關心第一次上島的人能找到方向並帶走自己的照片；她用路線、服務資訊表達關心。小角想把打結尾巴的窘境變成彩帶主題構圖，請玩家以玩家自己的角色試拍；目前沒有可操作的修布景流程，也不會在泡泡相機裡呈現小角本人。阿浪擔心入口與出口方向說反會讓人潮走錯；他需要核對現場標記並用人潮號誌結果確認指引有效。三人的動機連到已存在的任務互動與拍照設施，但不代表未實作的布景狀態。

資料檔保留舊 `quest-001`、`quest-002`、`explore-001..003` 及其 photo ID；舊 `quest_data()` 仍回傳原本三步問答，額外的 `mission` 才是新型任務資料。

| 任務 | 步驟（持久進度仍為 0–3） | 完成證據 |
|---|---|---|
| 小角：尾巴彩帶試拍 | ① 到小角的既有互動點；② 用長椅的立牌合照試看雙人位置安排；③ 用玩家自己的角色完成泡泡相機全身取景。 | 對應互動 ID、`photo-welcome-explore-3`，以及成功且非練習的 `game-010` 結果；完成獎勵維持 `photo-welcome-quest-1`。遊戲只拍攝玩家外觀，未表示小角出現在該相片或園區布景已修復。 |
| 阿浪：廣播即興救場 | ① 到廣播亭互動；② 核對歡迎字樣／入口標記；③ 完成人潮指揮 `game-004`。 | 對應互動 ID、展示燈觀察或其 `photo-welcome-explore-2` 照片、成功且非練習的 `game-004` 結果；完成獎勵維持 `photo-welcome-quest-2`。 |

新 `StoryDirector.mission_event_result(quest_id, current_step, evidence)` 對照目前步驟，只在證據吻合時回傳 `accepted=true` 與下一游標。練習結果不算正式小遊戲成果；錯誤種類／ID 不會推進。游標已是 3 時回傳完成狀態但不再提供獎勵。呼叫端應將 `next_step` 單調儲存，並以完成時的 `idempotency_key`／既有 `completion_photo_id` 呼叫原有照片領取；`Progress.grant_photo` 的重複領取保護仍是最終防線。測試只驗證資料和證據契約，不模擬玩家操作，也不宣稱原生遊戲試玩通過。

## 主程式事件整合與驗收範例

`main.gd` 現在在既有任務 NPC 互動點、通過驗證的探索快門，以及成功的正式小遊戲結果呼叫 `mission_event_result()`；練習、失敗或不相符的結果不會推進。任務卡顯示目前資料步驟，答案按鈕不再代替世界證據。原有 `quest_data()` 三問答資料、任務 ID、照片 ID 和 `Progress` 0–3 儲存格式仍可讀；完成照片只在游標首次到達 3 時發放。存檔中已存在的精確園區來源照片可以補齊先前完成的步驟，這不會建立新的照片或把未保存的行動當作完成。

核心呼叫形式如下；實際呼叫點只在既有事件成功後：

```gdscript
var mission := story.mission_event_result(
    quest_id,
    Progress.quest_progress(quest_id),
    {"type": "photo_collected", "id": photo_id}
)
if mission.accepted:
    Progress.advance_quest(quest_id, mission.next_step)
if mission.complete and not mission.reward_photo_id.is_empty():
    Progress.grant_photo(mission.reward_photo_id)
```

事件格式：既有任務點互動用 `{"type":"interaction","id":"quest-001"}`；照片用 `photo_collected` 和實際 photo ID；觀察可用 `observation_completed` 與 `explore-002`，或成功的觀察照片；小遊戲用 `minigame_result`、實際 `game-004`／`game-010`、`success:true`、`practice:false`。整合測試涵蓋真實任務點互動、既有探索快門、正式與練習結果，以及完成後重載和重入不重發任務照片。它們驗證事件和存檔路徑，不代表原生畫面試玩。

原生驗收場景 `game/tests/native_story_lifecycle_review.tscn` 準備了一段有限的 GPU 人工輸入流程：使用隔離存檔走過抵達對話、兩個任務互動與探索拍照，再以實際教學開始、泡泡快門鍵、路口 Q／E 導流，讓 `game-010` 和 `game-004` 自然產生成功結果。為縮短走到設施的時間，場景只把玩家位置放到既有站點；不設定模型階段、分數、任務游標或獎勵。它會保存並重載任務游標和照片 ID。Root 已以 GPU 執行最終流程，1724 幀、60 FPS、28.733 秒；實際觀看整段影片及十二張原生截圖。兩條任務分別由泡泡相機 296 分與人潮指揮 430 分的自然正式成功結果完成，保存後重載仍維持進度與照片，重入不重複發獎。驗收腳本省略站點間行走，並非完整自由探索試玩。教學嵌入截圖仍屬先前畫面，會在各款小遊戲定稿後更新。


## 本輪驗收修正與界線

首次存檔比對把 JSON 重載後的整數／浮點表示差異當作內容遺失；改用遞迴語意比對，仍逐項檢查所有鍵、陣列與數值。原生快門前的滑桿操作會等待實際佈局並使用真實滑鼠事件。人潮自然結束時 Main 會釋放 Session；驗收腳本在完成訊號中保存結果，避免等待下一幀後讀取失效物件。這些驗收工具修正沒有跳過真實遊戲輸入、強制成功或直接改任務進度。

Root 視覺檢查發現任務卡曾露出內部步驟 ID；已改為資料中的人話標題與「旅券 · 第 N 步 / 3」或完成狀態。Main 局部回歸直接檢查目前步驟文字、完成文字，以及六個內部 ID 不出现在玩家畫面。四組相關 CPU 測試与最終 GPU 流程均 exit 0，無 SCRIPT ERROR／ERROR／FAIL。原生流程已實際播放至結尾；尚不代表所有 NPC 完整動畫、全園區自由探索或全部時段劇情驗收。
