# MIC-2：首區十二款小遊戲的聲音身分

2026-10-23（Asia/Taipei），開始基準 `2e95cc6`，分支 `feature/gracious-archimedes-nmdgcm`。

## 問題

十二款小遊戲原本共用同一首 25 秒嘉年華短循環，命中、失誤與操作也共用同一組介面音。換了玩法，耳朵聽到的卻完全一樣；氣球的風、噴泉的水、號誌桿的金屬與長椅的木頭都沒有聲音上的差別。

## 實際閱讀的不同團隊

| 團隊／來源 | 實際讀到 | 採用 |
|---|---|---|
| Nintendo SPD《節奏天國 Fever》音效總監 Masami Yone，[Kill Screen 訪談](https://www.killscreen.com/how-sound-director-rhythm-heaven-fever-tapped-everything-japanese-weddings-neal-peart-inspiration/) | 團隊沒有做特別的節拍工具，重直覺而非數學；音樂與音效要「留在腦中」；加入玩家自己不易察覺、旁觀者會注意到的小細節。 | 每款以一個可記住的主旋律加上「材質一致」的少量回饋聲，而不是堆疊更多音效。 |
| Mark Sparling《A Short Hike》，[Uppercut 訪談](https://uppercutcrit.com/how-a-short-hike-captures-the-feeling-of-fall/) | 音樂隨地點變化，保留往前走的動力，也刻意放「可以喘口氣的層」；不同區域靠旋律與層次建立身分。 | 解謎類（花壇水路、長椅換位、影子捉迷藏）選安靜、不催促的曲；追逐類選有推進感的曲。 |
| Power Up Audio（Kevin Regamey）《Celeste》對話聲，[TheGamer 整理](https://www.thegamer.com/celeste-sound-designer-reveals-how-the-games-dialogue-audio-was-created/) | 每位角色先給一種合成音色，再依情緒決定音高高低與是否移動、語速快慢。 | 既有角色滴滴聲沿用「每人一種音高與節奏」；本票把同一原則用在每款遊戲的回饋材質。 |
| Kazumi Totaka《動物森友會》時段音樂，[Nintendo World Report](https://nintendoworldreport.com/news/32022/totaka-promises-many-new-songs-for-animal-crossing-3ds) | 早晨平靜、白天較上揚、傍晚低音較多、深夜神秘。 | 島上既有日夜增益保留；小遊戲曲不再額外疊時段處理，避免與島上規則衝突。 |
| Lin 等〈What Features Influence Impact Feel?〉，[arXiv 2208.06155](https://arxiv.org/abs/2208.06155) | 以 Steam 玩家評論排序 16 款動作遊戲，19 項回饋特徵中，停頓、**聲音一致性**與鏡頭最影響打擊感。 | 每款的操作／命中／失誤聲取自同一種材質（布、玻璃、金屬、木），命中聲不比失誤聲更刺耳。 |
| Game Accessibility Guidelines，[分開的音量控制](https://gameaccessibilityguidelines.com/provide-separate-volume-controls-or-mutes-for-effects-speech-and-background-music/) | 聽損常只影響部分頻率，音樂、音效、語音需能分開調整；同時太多聲源會讓認知負擔過重。 | 每款音樂與回饋分別走既有的音樂／音效音量；同源重複閘門保留，不新增同時播放的聲部。 |
| Godot 官方〈[Sync the gameplay with audio and music](https://docs.godotengine.org/en/stable/tutorials/audio/sync_with_audio.html)〉 | 以播放位置加上距上次混音時間、扣掉輸出延遲取得實際聽到的時間；系統時鐘法會慢慢漂移。 | 節拍型遊戲（噴泉、彩帶、合奏）的拍點同步由各自遊戲處理；本票的資料只決定配樂與回饋聲，不宣稱已和節拍對齊。 |

素材頁另見 [CC0 選材比較](cc0-audio-selection.md) 與本票來源截圖。

## 決定

- 每款遊戲有自己的配樂與三種回饋聲（操作、命中、失誤），寫在 `game/data/game_audio.json`。沒有設定或設定錯誤的遊戲安全退回原本共用組，絕不讓壞資料阻止遊戲開始。
- 回饋聲依遊戲的物理材質挑選：氣球用帆布與郵袋、噴泉用玻璃水滴、號誌用金屬、招牌與長椅用木頭、影子劇台用紙偶與扣框。
- 彩帶節拍與迎賓大合奏的聲音和拍點、樂器音色綁定，交由 SG-21／SG-27 在遊戲內處理，暫用共用組。
- 音樂維持既有固定增益策略（約 -23 LUFS、真峰值 ≤ -6 dB），只裁掉頭尾低於 -50 dB 的靜音以利循環。頻譜顯示偏亮的兩首先做保守處理：氣球曲 6 kHz 高頻架降 5 dB，泡泡曲 7 kHz 低通。

| 遊戲 | 配樂（作者） | 操作／命中／失誤 |
|---|---|---|
| 氣球快遞 | Sunflower Valley（isaiah658） | 帆布鼓風／郵袋放下／撞海膽悶響 |
| 風箏穿環 | choco bird's run（Bobjt） | 拉線上揚／撥弦短句／擦環落空 |
| 噴泉跳拍 | Jungle Simple Style 1（Tozan） | 玻璃水滴／彈跳／軟落空 |
| 人潮指揮 | Children's March Theme（Cleyton Kauffman） | 號誌桿／通行雙音／擦撞 |
| 帽子救援 | Rolling Circus（cinameng） | 草地腳步／接住布帽／帽子落地 |
| 花壇水路 | Calm Piano 1（cynicmusic） | 轉木水槽／接通清響／斷開下降 |
| 招牌平衡 | Taking you to the Circus（Pro Sensory） | 木招牌吱嘎／木板穩住／碰撞 |
| 影子捉迷藏 | Exploration Theme（Cleyton Kauffman） | 紙偶翻動／影框扣合／偏離 |
| 泡泡拍貼 | Sandy Seaside 2（Spring Spring） | 吹泡／上揚／破掉 |
| 長椅換位 | Bossa Nova（Joth） | 木棧腳步／坐定／卡住 |

回饋聲來自 Kenney 的 Impact Sounds、RPG Audio、Digital Audio 與 Music Jingles（皆 CC0）。逐檔來源、雜湊、增益與選擇理由在 [catalog](../../assets/audio/cc0/catalog.json)。

## 驗證與界線

1. 授權：每個新來源保存原始頁截圖、頁面雜湊、下載檔雜湊；Kenney 附 ZIP 內的 CC0 文字。Python 檢查所有路由的音檔都有唯一來源記錄、雜湊、無飽和，並檢查每款三種回饋不重複。
2. 程式：Godot 局部測試確認指定遊戲換用自己的曲與回饋、不同遊戲之間會交叉淡入、沒有設定的遊戲退回共用組、離開遊戲後清除遊戲回饋，以及錯誤路徑被拒絕。
3. 原生：在真正 Main 場景經由正式啟動流程依序開啟十二款，錄下主混音並記錄每款實際播放的曲目與回饋聲。雲端機器沒有音效卡，使用 Dummy 驅動混音；高負載時軟體混音時鐘落後牆鐘（305 秒音訊／328 秒事件），因此只用來核對路由與有聲，不拿來對時。
4. 另以出貨檔案、遊戲預設音量離線混出逐款「試聽表」，方便以耳機或喇叭快速比對。**這些都不是試聽**；音色是否合適、是否刺耳、循環接縫與疲勞度仍待人耳驗收。
