# 測試退出前完成音訊收束

2026-10-20；MAIN-2；開始main `6af27d0`。先讀User-guide。完整[CI39342800511](https://github.com/deadline314/Snapland/actions/runs/39342800511)設計／Python工作成功，原生前27項通過，第28項收藏介面退出時報`3 resources still in use`。保留失敗及錯誤偵測，沒有稱整套成功。

## 六個團隊的實際文字比較

- [Godot AudioServer](https://docs.godotengine.org/en/stable/classes/class_audioserver.html)：音訊有獨立混音時序，Dummy也仍是audio driver；主執行緒處理了幾張畫面不能證明所有音訊命令已消化。不用lock硬卡住音訊執行緒。
- [SDL CloseAudioDevice](https://wiki.libsdl.org/SDL3/SDL_CloseAudioDevice)：關閉可能短暫等待尚存的音訊資料，避免程序立即終止丟掉尾緩衝。
- [PortAudio Stop／Abort](https://portaudio.com/docs/v19-doxydocs/start_stop_abort.html)：停止並排完buffer和立即abort是不同語義；回呼與前景工作的時序也不同。不照搬API或把sleep當精準音訊排程。
- [miniaudio manual](https://miniaud.io/docs/manual/index.html)：停止／反初始化不應從音訊callback呼叫，以免deadlock；採主測試流程收束。
- [MDN AudioContext.close](https://developer.mozilla.org/en-US/docs/Web/API/AudioContext/close)：停止處理、資源釋放及其他物件引用是不同層次；完成關閉的Promise和呼叫當下有區別。這是生命週期比較，不是Snapland用了WebAudio。
- [JUCE AudioAppComponent](https://docs.juce.com/master/classjuce_1_1AudioAppComponent.html)：來源在停止播放後釋放資源，衍生物件銷毀時必須shutdown；重點是停止、解除引用與物件釋放的順序。

只讀官方文字，未看外部影像或試聽；這些資料不證明150ms是通用音訊保證。

## 本次改動及限制

正式遊戲退出原本先停止音訊、解除stream引用，再讓AudioServer消化停止命令0.15秒。收藏介面測試卻只等三個快速無頭process frame就結束；這不等於相同牆鐘間隔。補齊相同的既有收束流程，原地圖／收藏／焦點／頁面／降低動態斷言保持原樣。

同時核對目前使用的第一入場、教學存檔失敗子程序及海岸自由互動測試，補齊停止音訊與相同間隔；世界測試先停止自身更新，再釋放場景。自由互動的球體WeakRef釋放斷言、完整存檔不變，以及教學失敗回滾和不授卡判斷都保留。沒有改遊戲功能、音色、音量、照片保存或測試selectors；官方92項與90／240秒門檻沒有變動。

修正前本機verbose單次通過，沒有重現遠端的間歇錯誤；因此不聲稱已辨認那三個資源的唯一引用根因。修正後四個受影響實際Godot套件通過；收藏介面再用兩個新私人profile重跑，檢查仍是exit0、0ERROR及真完成行。未把Dummy輸出當聽感驗收。遠端整套由下一輪CI核對。

[本輪數據與記錄](../../pm/Snapland-main/images/MAIN-2-audio-teardown-20261020-verification.json)。既有對話收尾`126375c`已在較早CI通過；本批是其餘現行測試收尾，不放寬退出錯誤。
