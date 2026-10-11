# 敘事、可略過演出與音訊研究

研究日期：2026-10-11。以下是設計參考，不代表 Snapland 已有可遊玩場景或已完成聽感驗收。保存的外部圖片只供內部視覺分析，並非遊戲素材，發行版本不可打包引用。

## 小型探索敘事：《A Short Hike》

官方遊戲頁將體驗描述為沿標記路徑或自行探索，途中遇見其他健行者、發現隱藏寶物並欣賞環境；官方特色亦明確寫出玩家可自行選路、慢慢前進、與遇到的角色交談並互相幫忙。官方 press kit 說明它源於創作者對自然地景與童年森林探索的回憶，並稱原聲帶會隨探索動態推進。對 Snapland 的應用是讓迎賓大道先給清楚目的地，再把可選互動、角色玩笑和拍貼線索放在視線內；不以倒數或錯過懲罰催促玩家。

GDC 的《A Short Hike》事後分享頁說明演講會談小型作品範圍、視覺風格、關卡設計、寫作，以及如何在開始前引導玩家對遊戲建立合適預期。這支持首段簡短交代「這裡可以隨意逛、照片可補拍」，把開場演出重點放在情緒與方向，不用長篇世界觀解說。

圖片：[`reference-images/a-short-hike-trail.gif`](reference-images/a-short-hike-trail.gif)，來源為遊戲官方網站圖像；另存票券參考副本 [`ST-2-reference-short-hike.gif`](../../pm/Snapland-story/images/ST-2-reference-short-hike.gif)。用於觀察路徑、層次與周遭探索氛圍；不是可再散布的 Snapland 資產。

來源：
- [A Short Hike 官方遊戲頁](https://ashorthike.com/)
- [A Short Hike 官方 press kit](https://ashorthike.com/press/)
- [GDC：Crafting A Tiny Open World: 'A Short Hike' Postmortem](https://www.gdcvault.com/play/1028679/Independent-Games-Summit-Crafting-A)

## 對話步調、略過和重播

Xbox Accessibility Guideline 116 說明，非核心互動的時間限制應可調整或關閉；文字對話可由玩家輸入推進，讓玩家保留閱讀時間。指南以 Ori 與 Dragon Quest XI S 為例，展示文字停留到玩家按鍵前進，以及手動／自動推進選項。將此原則套用到本作：角色台詞由玩家按鍵逐段閱讀，不自動消失；略過只結束演出，不改寫收藏、任務、造訪旗標；對話內容可從露露的相簿重播。對話與主要獎勵流程因此保持分離。

來源：[Microsoft Xbox Accessibility Guideline 116](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/116)

## 節奏音樂與音訊播放

任天堂 Iwata Asks《Rhythm Heaven Fever》訪談中，聲音監督說明他以節奏理論整理歌曲，並特別注意保留原始示範曲的感覺；頁面亦提到音樂、音效等聲音工作。對 Snapland 音訊的應用是每個短遊戲的節奏提示與動作音效都要服務操作意圖，讓可聽回饋和畫面時機一致，不用嘈雜長音替代互動確認。另存一張《Rhythm Heaven Fever》玩法圖片 [`MIC-1-reference-rhythm-game.png`](../../pm/Snapland-music/images/MIC-1-reference-rhythm-game.png) 作為節奏提示的視覺討論參考；圖片來源為第三方遊戲截圖頁，僅作內部參考，不是本作美術素材或音樂驗收證據。

Godot 文件說明 AudioStreamPlayer 適合 UI 與背景音樂，可設定播放匯流排；AudioStreamWAV 可在前進迴圈模式播放。Audio bus 文件建議用 dB 管理混音，約 -6 dB 對應一半振幅，並提醒主匯流排避免超出 0 dB。實作以 0..1 線性設定提供給選項介面，轉成 dB；背景音樂由互斥的兩個播放節點交叉淡化，暫停時同步凍結音樂、環境與音效。

來源：
- [任天堂 Iwata Asks：Rhythm Heaven Fever，第 1 頁](https://iwataasks.nintendo.com/interviews/wii/rhythmheavenfever/0/0/)
- [Rhythm Heaven Fever gameplay reference image source](https://gamefabrique.com/storage/screenshots/wii/rhythm-heaven-fever-09.png)
- [Godot：Audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html)
- [Godot 4.4：AudioStreamPlayer](https://docs.godotengine.org/en/4.4/classes/class_audiostreamplayer.html)
- [Godot 4.4：AudioStreamWAV](https://docs.godotengine.org/en/4.4/classes/class_audiostreamwav.html)

## 驗收邊界

音訊為本 repo 的標準函式庫合成原創 WAV，沒有抽取上述遊戲或訪談中的音樂、聲效、圖片或程式碼。程式化訊號與波形檢查能確認可讀格式、取樣率、長度與迴圈設定；它不能替代遊戲內實際播放、切換、音量調整及聽感驗收。此工作沒有宣稱完成實際試玩或試聽。
