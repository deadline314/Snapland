# 測試退出的音訊播放釋放

MAIN-31 修正 NPC 對話測試退出時的原生播放物件延遲釋放，不變更玩家音訊、對話或獎勵行為。原 CI 只留下三份資源錯誤摘要；獨立 Linux 4.7.2 用原 150ms／owner free／兩幀流程重現，末尾詳細診斷辨識 plaza.ogg、其 OggPacketSequence 及 plaza_ambience.wav，由原生 Ogg／WAV playback 持有。正常或從啟動即詳細輸出的執行可能通過，故保留時序敏感的限制。私有 A/B 對照只新增 owner free 後實際釋放條件便通過，刻意持有 playback 的故障注入於 2004ms 如實失敗。

## 裁決與最小共用接口

五個測試清理位置已使用或需要同一段弱參照擷取／有界等待，重複約十餘行。採兩個測試專用靜態函式，合併相同機制；不新增生產音訊框架、可選策略、可調逾時或新的依賴。

新增 game/tests/audio_playback_release.gd（RefCounted，無全域 class_name）：

- capture(audio:Node)->Array[WeakRef]：必須在 shutdown 前呼叫，擷取現有 AudioStreamPlayer 的 playback 弱參照，不保留強參照、不停止或釋放 owner。
- wait_for_release(tree:SceneTree,playbacks:Array[WeakRef])->bool：呼叫者必須先 shutdown、queue_free owner 並完成原有 frame barrier。逐 process_frame 檢查真正弱參照釋放，Time.get_ticks_msec 單調期限 2000ms，逾限回傳 false；空陣列立即 true。不記錄成功、忽略錯誤或自己退出程序。

每個呼叫者保留自己的功能斷言、quitting 狀態、shutdown／queue_free／既有 frame 順序與原完成訊號。NPC 改掉無條件的預先150ms等待，使用 owner free 後條件；設 quitting=true 與其餘 Main 結束流程一致以避免清理時再起播放，但此守衛不是已證明的 backend 延遲原因。MAIN-28 在 shutdown 後、owner free 前的 late-world callback 斷言必須留在原處。

遷移僅五處：test_npc_dialogue_hold、test_photo_retake_main、test_sugar_bridge_main、test_cookie_mold_main，以及 native_sugar_bridge_main（Cookie native 繼承之）。其餘尚未有對照證據的舊測試不批次改寫。工具只處理目前 AudioDirector 使用的 AudioStreamPlayer，沒有將假想2D／3D／polyphonic系統納入範圍。

## 驗證

新增 SceneTree 自測使用真正播放物件，證明弱參照不延長壽命、owner free 後可完成、空集合通過、強持有的故障注入在有界期限回報 false，釋放後可恢復；假注入需明確標記且退出前清理，不能隱藏退出資源錯誤。原五個呼叫者的局部功能與退出驗證保持要求；至少 NPC Windows／Linux 各用獨立絕對存檔驗證，保存原時序 RED、條件 GREEN 與逾限失敗。

將自測登錄嚴格完成訊號，錯誤、後綴、stderr-only、非零退出仍拒絕。Native QA 明確包含新共用依賴，以真入口與有界清理驗證；正式玩家輸出仍排除 game/tests。純測試生命週期修正不以截圖或自動檢查冒充真人試玩／試聽。
