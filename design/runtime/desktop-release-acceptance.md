# 桌面成品：從真正執行檔驗收

2026-10-20；MAIN-9／SG-15。先讀User-guide；開始main `baceed6`。此輪是Linux x86_64、Compatibility、llvmpipe；不是Windows EXE、獨立顯卡效能或喇叭試聽。

## 六個團隊的比較

實際讀取以下官方文字；沒有外部影片觀看或外部圖片檢視宣稱。票內圖是本作實際成品畫面。

| 團隊／來源 | 採用的觀察 | 本次取捨 |
|---|---|---|
| [Godot Linux export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_linux.html) | 專用export template移除編輯器，以PCK攜帶資源 | 使用4.7.2正式release template及嵌入PCK，不拿編輯器加PCK稱正式EXE |
| [Valve Platforms](https://partner.steamgames.com/doc/store/application/platforms) | 新平台需在目標作業系統實際測試 | 在Linux實跑，只記Linux；不由這次推論Windows或Steam Deck認證 |
| [itch.io Linux builds](https://itch.io/docs/itch/integrating/platforms/linux.html) | 可攜資料夾包含資產／執行檔／依賴；打包後還需執行確認 | 從僅有執行檔的資料夾啟動；不借開發資料夾的素材 |
| [Epic Packaging](https://dev.epicgames.com/documentation/en-us/unreal-engine/packaging-your-project) | build、cook、stage、package、run分開；成品要測載入、互動與退出 | 不以匯出程序exit0代替切時、領卡、看原圖、退出和重開 |
| [AppImage Quickstart](https://docs.appimage.org/introduction/quickstart.html) | Linux下載成品還需可執行權限 | 驗ELF、保留執行位；此輪是普通Linux執行檔，不冒稱AppImage |
| [Flatpak First Build](https://docs.flatpak.org/en/latest/first-build.html) | SDK是開發工具集合，runtime是執行依賴；build後另安裝／run | 用正式範本驗執行需求，不把開發工具可用當成玩家環境已具備；本輪沒有製作Flatpak |

Unity舊頁未成功，沒有計入六來源。未發行至商店、未更改平台支援聲明。

## 可重現建置

`export_presets.cfg`新增Linux Desktop，保留Windows設定。`python -m tools.build_desktop_release --godot <4.7.2 editor> --template <linux_release.x86_64> --output <新的私人資料夾>`會只複製追蹤中的遊戲／素材、主專案與園區必要資料到暫存專案，匯入後產生真正release ELF，PCK嵌在執行檔內。私人範本路徑只寫入暫存設定，不安裝到他人共用範本資料夾。

官方範本包：<https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz>，1281349702bytes，SHA256 `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`，與GitHub release asset digest一致。只提取`templates/linux_release.x86_64`及版本檔；個別ELF SHA256 `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63`由已驗證壓縮包取得並作為建置入口門檻。

來源檔逐一留SHA256，不能僅寫一個基準commit掩蓋未提交的匯出設定。輸出資料夾必須空；錯誤版本範本及覆寫既有成品的反例都在開引擎前拒絕，原執行檔SHA未變。匯入與匯出都要求exit0及0ERROR。

## 成品入口與證據

正式release範本禁止`--path`，最初嘗試把外部診斷場景送入成品直接exit1，這是拒收記錄，並未繞過或重新編譯範本。改從成品自己的主畫面操作：外部X11鍵鼠、完整1280×720視窗擷取、進度JSON及八個影像檔的唯讀核對。沒有呼叫遊戲內部按鈕signal、搬動角色根節點、直接授卡或預置成果。角色從新存檔碼頭實際走到票票旁。

共用有界引擎入口增加`release_directory`模式：仍先驗來源的正式主場景，再從只有成品的資料夾執行；拒絕path／scene／script／main-pack等覆寫及鬆散project／editor cache。原生套件入口與完成契約保留。另有26項入口／結果回歸，含成品工作目錄及錯誤覆寫反例。

第一程序：跳過抵島對話、步行、開切時面板，依實際按鈕收集中午／凌晨／傍晚／晚上紀念拍貼。每張20幣，重複點擊不再發獎，總額120→200；只新增四張紀念拍貼和四時成就，普通／小惡魔數仍0。關閉面板、正常暫停與儲存退出。

第二程序：同一存檔重開時已是晚上，無第二次抵島教學；由旅券進收藏冊、切四時分頁、逐一打開四張1280×720原圖、Escape返回，再正常儲存退出。原進度完整JSON與全部四原圖／四縮圖SHA256一致，觀看不重寫成果。第一／第二程序退出均exit0、0ERROR。這是程式化外部輸入與靜格檢視，不是人類玩家評測或連續動畫／聽感認證。

外部測試器初版啟動後只等3秒、移動指標後只等50ms，部分早期輸入沒有啟動預期畫面；保留所有嘗試，重點後才依存檔確認成果，沒有把未觸發的輸入當成功。延長指標等待至450ms後，在最後成品已穩定的畫面實際以單擊依序開收藏、四時分頁及夜間原圖。最初輸入延誤原因未單獨定位，未斷言為遊戲或測試器的唯一根因。後續外部驗收應先核對目前畫面，等待視窗／指標穩定，再送下一步，不能只按預設時間和檔名推論成功。

[本輪成品、真程序與來源記錄](../../pm/Snapland-main/images/MAIN-9-release-20261020-verification.json)。大型執行檔與原範本留在私人建置目錄，不把219MB成品塞進Git；依上述入口可重建。圖片與測試紀錄可從票直接檢視。


## 十二款打包資源的分開驗證

首版成品的藝術冒煙在第一款失敗：氣球現已採獨立3D場景，不會走舊共用背景繪製路徑，不能要求每款都用同一張圖。保留原失敗記錄後，將不依賴繪圖狀態的四象限圖集取得抽出，正常繪圖仍使用相同區域／比例／快取；未更換背景素材。

更新後逐款確認當前專用renderer可見、模式一致，實際postdraw存十二張全尺寸圖；最後另明確解析全部四背景與十六道具，再保留完整原門檻、角色／植栽／動畫／遮擋檢查。沒有把明確解析到Texture2D說成每張圖已在遊戲畫面使用。最終release24.30秒、exit0／0ERROR，十二格總覽已實看。故意漏包同一背景的真正release在第3款報缺圖並exit1；沒有降低到只接受程序結束或移除缺圖斷言。

第一／第二次完整切時與原圖流程使用初始成品`ded7716…`；修正上述冒煙契約後重建的成品是`4c53243…`。最後成品另有第三個新程序重開同一存檔、實際單擊收藏／四時／夜間原圖及正常退出，全部照片及進度仍位元組一致。四項受影響Godot回歸（含十二款81案例）通過；104項Python回歸通過。完整遠端CI另有MAIN-2收藏UI收尾問題，未寫成全套綠燈。


## 2026-10-21：匯入階段也隔離測試

ART-18 新增的製作檢查會載入 `tools/island_avatar/`。一般完整專案與 CI 有製作工具，但乾淨玩家 stage 故意不含 tools；只靠 export preset 排除 `game/tests` 太晚，editor import 已先解析它們。建置入口改在複製追蹤檔時排除整個 `game/tests/`，測試依然在完整開發專案及 CI 執行，未刪除任何套件或放寬門檻。

回歸用真正的依賴製作工具測試腳本、巢狀 fixture、未追蹤候選、語系／園區資料與授權建立臨時專案，證明只有玩家檔進 stage，原檔未修改。重新實際匯入 32.51 秒、Linux release 匯出 5.40 秒，均 exit0／0ERROR；219546344 bytes 成品已產生。此處只驗建置，不重複宣稱真人遊玩／音訊／Windows；本輪成品含進行中的 ART-17 原畫修正，逐檔 SHA 才是實際來源，基準 commit 不是乾淨來源聲明。[來源與結果](../../pm/Snapland-main/images/MAIN-9-release-stage-20261021-verification.json)。
