# MIC-3：首區 CC0 聲音選材與驗收

2026-10-14，開始基準 `89bf0b4`，分支 `feature/island-experience`。

## 使用者要求與本次界線

音樂、音效一律 CC0；用心挑選真正符合場景的聲音，至少六個不同來源比較。保留海港遊樂園的個性，不能因像素畫面就把配樂一律換成簡單蜂鳴聲。短操作回饋、角色語音、環境聲與配樂各有密度取捨。

這次接入三個既有音樂情境、海浪、五個共用音效及四個旋律音高。十二款各自配器、音樂節拍與動作同步、完整日夜音景仍由 MIC-2 驗收。以下適配判斷是**素材頁描述及音訊量測的候選判斷**，尚未經主 Session 耳機／喇叭試聽；不能寫成已聽過或最終選曲通過。

## 實際閱讀的不同方向

| 創作者／第一手頁 | 實際看到的內容 | 決策及理由 |
|---|---|---|
| [Zane Little Music：Apple Cider](https://opengameart.org/content/apple-cider) | CC0；作者說選擇 cozy 方向；標籤含吉他、長笛、口哨、節慶；提供 WAV／OGG。 | 接入遊園候選；比全程高強度節奏更接近悠閒探索。保留整首；原曲有收尾，接續自然與否待實聽。 |
| [Tarush Singhal：Happy Ukelele Island Surfing Theme](https://opengameart.org/content/happy-ukelele-island-surfing-theme) | CC0；標籤含夏日、島嶼、ukelele、acoustic drums；提供 MP3。 | 接入碼頭候選；對應登島及海風。不能因標題含島嶼就認定最終合適；與海浪及對話的混音待聽。 |
| [Écrivain：Carnival Rides](https://opengameart.org/content/carnival-rides) | CC0；為 Carnival 每週挑戰製作的短循環；提供 OGG 與樂譜來源。 | 接入共用遊戲初始曲候選；保留嘉年華辨識。25.5 秒較短，長玩重複感待聽；不是十二款最終獨立配樂。 |
| [Kenney：Interface Sounds](https://kenney.nl/assets/interface-sounds) | 資產頁及 ZIP 內 License.txt 均明確 CC0；100 個操作音。 | 同一套內選操作、命中與失誤，讓操作語彙一致；保留來源個別檔名。快門是同源點擊的短延遲處理，不冒充相機實錄。 |
| [Fupi：Win Jingle](https://opengameart.org/content/win-jingle) | CC0；作者指定成功操作／關卡完成用途；有不同樂器預製版本、MIDI。 | 以現成 fretless 版本作完整結算候選；不另載不明 soundfont。每次命中改用 290ms 短音，完整 jingle 只在結算／任務出現。 |
| [jasinski／qubodup：Beach Ocean Waves](https://opengameart.org/content/beach-ocean-waves) | CC0；標示擷取自 jasinski 的 Alki Beach 錄音，提供四個 FLAC。 | 接入第一個四秒海浪片段，350ms 交疊接縫；比合成白噪音更有實際海邊來源。短循環的重複感仍待驗收。 |
| [Cleyton Kauffman：Exploration Theme](https://opengameart.org/content/exploration-theme) | CC0；合成器／鋼琴、水感、2:14、明確無縫循環，ZIP 附 CC0 說明。 | 保留探索／夜間替代候選；同頁含 midnight、space 等方向，目前先不把偏氛圍的候選套在所有白天設施。已下載並核對 ZIP，但未試聽。 |
| [Fupi：Loop Town](https://opengameart.org/content/loop-town) | CC0；鋼琴、bass、drums、harp；作者說是快步調小鎮，中間有安靜段。 | 保留較有動能的替代候選；不依「town」名稱直接選作悠閒廣場。已下載 WAV，未試聽。 |
| [controllerhead：Magic Town](https://opengameart.org/content/magic-town) | CC0；作者描述奇想、神秘小鎮，SNES RPG 靈感。 | 暫不接入；神秘奇幻方向與本批暖色海港的重點不同，不能把所有復古音色視為同一氣氛。 |
| [Guy G. Gamerson：Happy Town](https://opengameart.org/content/happy-town) | CC0；Game Boy／chiptune／retro RPG，簡短 town theme 描述。 | 暫不接入；已看過頁面，沒有聽過，不能只用「happy」標籤當最終選曲依據。 |
| [cynicmusic：Enchanted Tiki 86](https://opengameart.org/content/enchanted-tiki-86) | CC0；作者描述 dark、moody、hypnotic；有另外商業專輯及其他作品連結。 | 排除此首作為白天主題候選；不把本頁 CC0 延伸認定整個作者商業曲庫都 CC0。 |
| [rezoner：Happy Arcade Tune](https://opengameart.org/content/happy-arcade-tune) | 標籤適合快節奏解謎，但素材頁授權是 CC-BY 3.0。 | 因本次全部 CC0 要求排除，不下載作遊戲素材。免費可用不等於 CC0。 |

已保存九張真正的原始頁截圖，涵蓋七位不同創作者；見 MIC-3 票。海浪也追溯至 [jasinski 的 Freesound 原作](https://freesound.org/people/jasinski/sounds/18363/)，確認原作者頁仍標示 Creative Commons 0；本作使用的是 OGA 擷取片段。截圖是研究／授權佐證，沒有轉用其中封面美術當本作素材。頁面與素材雜湊、作者、直連、處理方式見 [catalog](../../assets/audio/cc0/catalog.json)，個別素材附的 license 原文另保存。

## 採用的方法

[Godot 官方匯入指南](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html) 區分短音效 WAV 與長音樂 Ogg Vorbis；後者可設定循環起點。音樂只保留兩個播放器交疊，保留原速與整首，避免長 WAV 同時解壓的記憶體負擔。循環旗標正確只能證明機制，不能證明音樂樂句接得自然。

音樂以整首量測後的**固定增益**接近 -23 LUFS，並保留至少約 5dB 真峰值餘裕；不以壓縮器把細節全部壓平。UI／命中峰值 -18dB、失誤 -20dB、快門 -15dB、結算 -12dB。這是保守的本作初始混音選擇，不是業界通用響度標準。實際耳機／喇叭聽感、相對音量與疲勞度仍待測。

操作聲 40ms 同源重複閘門抑制瞬間重複事件；命中與完整結算分開。對話維持四位角色各自音高及揭字節奏的短純音，標點不出聲。音量設定同時影響淡入、淡出的兩首音樂；暫停時聲音及淡化進度一起停；離開時清理播放與資源。WAV 環境聲明確使用完整取樣範圍作循環終點，不能只切換循環旗標。靜音使用真正零增益；原生錄音的靜音中段另查 PCM，不能把 -60dB 的微弱訊號當成零訊號。

[CC0 官方聲明](https://creativecommons.org/publicdomain/zero/1.0/) 說明此類素材可修改、散布及商用。每個第三方素材都另核對自己的原始頁和下載版本；我們仍保留創作者署名，不暗示作者認可本作。原創純音及歷史合成聲音另外明確專屬 CC0 聲明，遊戲程式與美術不受此聲音聲明影響。

## 驗收規則

1. Python 核對所有 13 個實際使用音檔都有唯一來源、CC0、雜湊及有效容器，另檢查 WAV 非空、不飽和。量測與雜湊不能證明好聽。
2. 原有 Godot 音訊測試保留並擴充：Ogg 循環、交疊時靜音、快速換場景、暫停中再換曲、海浪完整循環、同源事件閘門及退出清理。原來的 WAV 格式斷言等價更新為實際採用的 Ogg 格式與路徑，不移除測試入口。
3. 原生 Main 內用 AudioServer 錄製輸出，保存事件時間軸、三個音樂 context 與靜音畫面。這是同一 Main 場景內的音訊技術測試，不能說成已走完三區或真人試玩；短錄音也不代替每首完整兩次循環。
4. 最終以耳機與喇叭各聽至少兩輪：海浪是否有明顯重複、曲尾是否突兀、BGM 是否遮擋滴滴聲、密集命中是否刺耳、結算是否過長，以及靜音／恢復是否自然。記錄實際時點、問題與修正後才勾選；目前此項保持待驗收。
