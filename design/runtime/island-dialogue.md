# 島嶼對話呈現

島上對話使用畫面下緣的常駐字幕板，讓 3D 場景、角色位置與當前探索目標繼續可見。字幕板顯示說話者和完整台詞；文字逐字顯示，按 E、Space 或畫面按鈕先顯示完整句子，再前進到下一句。玩家可隨時結束對話。對話期間停止玩家移動與 NPC 閒置活動，結束或取消後恢復園區。

票票、小角與阿浪都能重複交談。初次抵達直接播放原有上島台詞；導覽亭保留主線與既有照片回饋；兩位任務角色先說自己的既有角色台詞，再開啟原有任務旅券。對話本身不推進任務、不改寫存檔格式、不發放新獎勵；實際互動記錄仍使用原任務事件。

逐字音是短促、依角色音高與間隔區別的電子提示，不是語音合成或配音。短音在遊戲啟動時預先合成並快取；空白、標點、靜音設定與短時間連續字元不播放音效。文字字幕保持完整可讀，角色姓名每句都顯示，因此故事資訊不依賴提示音。

呈現原則參照 Microsoft [Xbox Accessibility Guideline 104](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/104)：對白提供字幕、標示說話者，避免把重要內容只放在音訊；字幕固定靠近畫面底部，使用大字與不透明底板。對話不覆蓋字幕以外的方向資訊。Godot [AudioStreamWAV 4.7](https://docs.godotengine.org/en/4.7/classes/class_audiostreamwav.html) 說明 WAV stream 可儲存動態產生的 PCM 音訊，並由 AudioStreamPlayer 播放；本實作採單聲道 16-bit PCM，於啟動時建立快取，逐字過程不配置新音訊串流。

敘事內容沿用[迎賓故事品質基線](first-park-story-quality.md)中已查閱的六個團隊來源：inkle、Supergiant、CD PROJEKT RED、Ubisoft、Guerrilla、Santa Monica。這裡只採用短句、可離開後重入、角色動機明確且互動不重複領獎等準則，不把音調提示當作角色配音。
