# ST-6 證據索引

本票為程式化操作、真實 GPU 畫面與隔離保存驗證，沒有聲稱真人遊玩或真人試聽。

最終遊戲內容：`16ab825`；跨平台測試清理修正：`8512937`，只修改測試。以乾淨提交來源重新輸出的 Windows 成品與資源包，和已驗證版本逐位元相同；來源清單與指紋在 `build/`。

## 最終通過項目

- `local/native-800x600/`：捲髮、雨背心、降低動態、1.25 文字，十張實際 800×600 畫面。
- `local/native-1280x720/`：一般動態、原外觀，十張實際 1280×720 畫面。
- `local/native-1920x1080/`：短髮、雨背心、1.25 文字，十張實際 1920×1080 畫面。
- 各組 `native-boat-review/report.json`：尺寸、外觀、演出時間、操作狀態與空的失敗清單。
- `packed-forward-plus/`：空工作目錄載入獨立資源包，以預設光影重做首次播放與重播。
- `local/pack-native.log`、`local/windows-startup.log`、`local/windows-art.log`：原生資源包、Windows 啟動與十二款原遊戲圖資檢查。
- `windows-twelve-assets/`：Windows 成品的十二款原生圖資畫面。
- `reviews/task-3-fix-linux-child-final.log`、`reviews/task-3-linux-fix-runner.log`、`reviews/task-3-fix-windows-runner.log`：跨平台保存失敗與確定性退出驗證。
- `reviews/`：三項任務、整批審查及修正後的局部複查。

## 保留的失敗歷史

檔名含 red、diagnostic、failed、composition 或較早 final-runner 的資料是開發中的失敗重現與構圖草稿，不是最終通過結果。舊 Linux 雲端執行 `43242323231` 曾抓到測試清理順序造成音訊資源未釋放，已以 `8512937` 修正；精準錯誤檢查仍保留。故意阻擋保存的子程序只能出現指定隔離路徑的一次預期錯誤，不能忽略其他錯誤。

最終雲端結果及成品資訊以同票的 verification.json 與最後提交為準。
