# 上島與迎賓大道交付紀錄

日期：2026-10-11（Asia/Taipei）。分支：`feature/island-first-park`。從最新 `origin/main` 建立独立 worktree，先以 `c1b7b19` 開出並推送22張票，再製作可玩第一版。

## 可以直接玩的內容

Windows 預覽包在本 worktree 的 `build/`。執行 `Play-Snapland.cmd`，預览進度獨立放在 `%LOCALAPPDATA%\SnaplandPreview`。WASD／方向鍵移動，E／Space互動，Esc返回。碼頭開始有可略過與重播的導覽，穿過主廣場可进入迎賓大道12款設施；其他9區有入口與收藏門檻。船上序章保留前接點。

像素人物與立體布景結合，包含日夜實際光影、水面、植栽與步行动畫；12款小遊戲目前使用原創2D圖形。對話、任務、18個普通收藏來源、12張小惡魔、設定、安全存檔、遊戲內成就與Steam待同步接口已接通。這是可玩第一版，尚非最終美術、音樂或真人體驗品質定稿。

## 實際驗收

- 本機受影響 runtime：7/7檢查通過，包含乾淨匯入、實際啟動／退出、核心、小遊戲、劇情、音訊與主場景整合。
- 小遊戲：42個程式化測試案例；12款各自正常／輔助的成功、惡魔條件與超時不授卡，另含輸入路由、重複按拍、重複拍照等邊界。
- 原生GPU：Intel Arc B580、Vulkan Forward+。經实际鍵鼠事件逐款通關，12張普通＋12張小惡魔及迎賓通關／惡魔全集成就均入檔；12張結算圖已逐張查看。最新整合與截圖 log 無 ERROR／WARNING。這是原生自動操作，不是一次真人樂趣試玩。
- 設計局部：park、story通過。未自行跑完整設計套件；既有 `design/02-minigames/catalog.json` 缺檔（SG-1），games／links／all仍有基線缺口，沒有更改選擇器或斷言來掩蓋。
- 存檔破損注入：單獨測試檔案有備份時恢复24張收藏；沒有備份時回到0收藏與預設總音量0.7，記錄具體檔案位置與解析行數。故意損毀測試會產生預期錯誤訊息，未當作零錯誤正常執行。
- 原創音訊：12個WAV資源，PCM飽和樣本0；已驗循環、音量、切換、暫停及音符路由，尚未進行喇叭／耳機聽感驗收。
- Windows正式匯出可啟動並乾淨退出（exit0），以實際GPU啟動；研究圖片、票、測試均不打包，附Godot／Noto及引擎第三方授權。

## 遠端與票況

[程式交付 commit](https://github.com/deadline314/Snapland/commit/f2d6b84919a91d534082660a12aec5a9b44eaa2c)已推送。先提交共同可執行程式，接著逐票單独提交證據，讓每張票都有穩定可查的程式commit連結。

[GitHub Actions執行紀錄](https://github.com/deadline314/Snapland/actions/runs/38143451049)已触發，但兩個工作皆因帳戶付款／支出限制未啟動（步驟列表為空）。沒有重試遠端工作，沒有更改付款或支出設定，不能宣稱遠端CI通過。MAIN-3的實際CI條件與MIC-1的聽感條件保持未勾選，因此整組保持「進行中」且未推main；未刪交付分支或worktree。

## 存檔測試事故

一次未指定隔離路徑的核心測試誤寫 `C:\Users\stanl\AppData\Roaming\Godot\app_userdata\Snapland\progress.json` 及其 `.bak`。原有6,580bytes內容未能恢復，也無法確認是否來自先前的測試；現存兩檔為29bytes測試資料，已保留，不假造原進度。測試入口現已要求獨立路徑，預览啟動器也使用另一個持久保存位置。這是本輪已發生的資料影響，不列為已恢復。

## 範圍與後續驗收

其他園區內部、完整異空間、船上序章與多人沒有在本版實作。Steam接口已留，但未安裝正式SDK與同步到Steam帳戶。尚待帳戶允許CI執行、音樂實際試聽與真人操作感評估；既有128款目錄缺口保持在原設計票。

## 逐票索引

| 票 | 結果與局部證據 | 票況 | 證據commit |
|---|---|---|---|
| [MAIN-3](Snapland-main/[MAIN-3]建立可執行遊戲與原生驗證.md) | 現在可開啟上島與迎賓大道，缺少引擎或測試時會明確失敗。；CI未啟動 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/f89466f5eeced3cbee303a7476a4c7f4250cbbde) |
| [MAIN-4](Snapland-main/[MAIN-4]建立主廣場與園區路口.md) | 現在可步行往返三個主要地帶，另九區顯示入口、收藏門檻與準備中提示。；局部／原生驗收通過 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/f724b21c4719f72682386ec19d9fab607523d295) |
| [MAIN-5](Snapland-main/[MAIN-5]建立遊戲成就與平台接點.md) | 十二款首次完成、迎賓全通關、小惡魔全集有獨立成就，離線可記下待平台同步成果。；局部／原生驗收通過 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/df32881cf6ca63a224e1dd5a841fe39345216ba1) |
| [MAIN-6](Snapland-main/[MAIN-6]提供設定與安全存檔.md) | 現在可調整音量、文字速度、動態、顯示與輔助，進度重開能接續，損毀檔案有具體位置與安全恢復。；局部／原生驗收通過 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/0da0e234e80028ce46dc503ca8d2f1ba37a67946) |
| [MAIN-7](Snapland-main/[MAIN-7]建立拍貼結算與收藏冊.md) | 現在結算保存實際遊戲畫面，可重試／返回；普通與小惡魔獨立收藏，重玩不重複增加張數。；局部／原生驗收通過 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/dfd19a61fe880812f4e7db41941002cd31e15fbb) |
| [ART-1](Snapland-art/[ART-1]建立立體像素園區光影.md) | 像素角色走進立體碼頭、主廣場與迎賓大道，水面、旗幟、植栽與日夜光影連動。；局部／原生驗收通過 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/4b8978ed8b2aa5617562e1baa771fb90b45220aa) |
| [ART-2](Snapland-art/[ART-2]建立遊園介面與操作引導.md) | 現在以清楚操作提示與可見鍵盤焦點操作各選單，對話與結算有返回方式。；局部／原生驗收通過 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/78aa5cdadb448140e9ce5f8934df64feb5610292) |
| [ST-2](Snapland-story/[ST-2]演出上島導覽與對話.md) | 碼頭以五段短對話開始旅途，按玩家步調前進，可略過與重播，保留船上序章前接點。；局部／原生驗收通過 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/b82ece7af9d755f85c4affbe70eaf1787e9c338e) |
| [ST-3](Snapland-story/[ST-3]實作迎賓任務與探索.md) | 尾巴危機與廣播救場各有三步，另可讓花壇眨眼、對齊影子及借立牌合照，保留任務進度。；局部／原生驗收通過 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/3fbca6248fb0d3ac0e81d72d2bd6b95e8f21c06d) |
| [MIC-1](Snapland-music/[MIC-1]製作首區音樂與互動音效.md) | 現在有三首原創循環、海風、互動與快門等音效，節拍與合奏會發出實際音高。；聽感未驗收 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/96b57dcef5363782b50382a4d525412ff653a504) |
| [SG-2](Snapland-small-game/[SG-2]實作氣球快遞.md) | 現在可依提示遊玩「氣球快遞」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/aac55c6b2f96ba7d7f59c2c5062c7a7bf134abf2) |
| [SG-3](Snapland-small-game/[SG-3]實作風箏穿環.md) | 現在可依提示遊玩「風箏穿環」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/bfb70a750d1a9ff3a3b92fdbb13e0d96c4eee4be) |
| [SG-4](Snapland-small-game/[SG-4]實作噴泉跳拍.md) | 現在可依提示遊玩「噴泉跳拍」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/7239388a64949ca224f12e9bde1c0e4cfd46a4e9) |
| [SG-5](Snapland-small-game/[SG-5]實作人潮指揮.md) | 現在可依提示遊玩「人潮指揮」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/03749447d26fed0f16afd748d6657bbfff2dc119) |
| [SG-6](Snapland-small-game/[SG-6]實作帽子救援.md) | 現在可依提示遊玩「帽子救援」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/3dd2b6b754dc12af508f9fd50f4e529dfc294bea) |
| [SG-7](Snapland-small-game/[SG-7]實作彩帶節拍.md) | 現在可依提示遊玩「彩帶節拍」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/bb5130762d1b43badfdb3424b33735fa57d79c37) |
| [SG-8](Snapland-small-game/[SG-8]實作花壇拼圖.md) | 現在可依提示遊玩「花壇水路」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/3417dbb3dd97892c1f7200bfccfc0369e3eded39) |
| [SG-9](Snapland-small-game/[SG-9]實作招牌平衡.md) | 現在可依提示遊玩「招牌平衡」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/23cbb009e413c5e1e8cf8677fcb23200980d82d4) |
| [SG-10](Snapland-small-game/[SG-10]實作影子捉迷藏.md) | 現在可依提示遊玩「影子捉迷藏」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/a7e3f439024e2392621ee46159ef1b3e873656f5) |
| [SG-11](Snapland-small-game/[SG-11]實作泡泡合照.md) | 現在可依提示遊玩「泡泡合照」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/249f17107e3bb1e82dd104ae092c3e98f9b7dc2b) |
| [SG-12](Snapland-small-game/[SG-12]實作長椅換位.md) | 現在可依提示遊玩「長椅換位」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/8fa208e54e4709b743bbdccb0af9fa233eacab23) |
| [SG-13](Snapland-small-game/[SG-13]實作迎賓大合奏.md) | 現在可依提示遊玩「迎賓大合奏」，免費重試與離開，正常與輔助都可收藏，另有本款成就及小惡魔目標。；原生通關圖、42案例 | 進行中 | [證據](https://github.com/deadline314/Snapland/commit/13bc54fe00aabd62ceefe6435d7516c38cd6aaf7) |
