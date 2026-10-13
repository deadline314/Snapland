# Snapland CC0 聲音

目前接入的首區聲音見 [素材清單與雜湊](cc0/catalog.json)，選曲比較、原始頁及驗收界線見 [MIC-3 研究](../../design/runtime/cc0-audio-selection.md)。所有執行時音檔和四位角色的合成滴滴聲都有明確 CC0 紀錄；此授權只涵蓋列出的聲音，不延伸至遊戲程式或美術。

| 用途 | 素材／創作者 |
|---|---|
| 碼頭 | Happy Ukelele Island Surfing Theme — Tarush Singhal |
| 遊園 | Apple Cider — Zane Little Music |
| 共用遊戲初始曲 | Carnival Rides — Écrivain |
| 操作、命中、快門、柔和失誤 | Interface Sounds 1.0 — Kenney（選段及處理見清單） |
| 整局完成／任務達成 | Win Jingle — Fupi |
| 碼頭及廣場海浪 | Beach Ocean Waves — jasinski（qubodup 提交） |
| 四個旋律音高／四位角色滴滴聲 | 本專案合成純音，[CC0 聲明](cc0/licenses/generated-tones.txt) |

這是可檢查的接入候選；完整耳機／喇叭試聽仍待驗收。Apple Cider 是有收尾的完整曲目，不能只因設定循環就宣稱接續自然。十二款獨立配樂及動作節奏另由 MIC-2 驗收。

`tools/prepare_cc0_audio.py --source-dir <下載並解壓的來源目錄>` 會先核對來源雜湊，保留原速與整首音樂，以固定增益及格式轉換準備素材。短音用 WAV，音樂用 Ogg Vorbis；細節及 ffmpeg 版本留在清單。

`python game/audio/generate_audio.py` 現在只產生四個原創音高，避免覆蓋精選素材。舊版三首合成 WAV 留作歷史，不再作為背景音樂載入；若要重現歷史輸出，須指定資源目錄之外的 `--legacy-output`。
