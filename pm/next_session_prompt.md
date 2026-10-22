# 下一個 Session：接續 Snapland 未完成票

2026-10-20（Asia/Taipei）。下方 Prompt 可整段獨立使用。這是工作入口與範圍快照，不是新一輪遊戲、GPU 或聲音驗收。實際主線以 fetch 後的 `origin/main` 為準。

## 可直接貼上的 Prompt

接續完成 Snapland。使用者已要求自主研究、設計、實作與驗證，不要為一般設計判斷停下詢問；維持角色一致性，並依最新回饋與票的相依改善世界自由互動、光影、動畫、玩法與 UIUX。品質不足可重做，保留已接受的原圖與其他 Session 成果。不要只交研究、計畫或生成候選。

### 先找到正確主線與規範

1. Repo：`https://github.com/deadline314/Snapland.git`。先核對 cwd、遠端、`git worktree list` 與 dirty files。不得切換、reset、clean、stash 或攜走其他 Session 的工作區／未提交內容。
2. 執行 `git fetch origin main`，從最新 `origin/main` 建自己的分支／獨立 worktree。**main 已包含可執行遊戲**；確認 `project.godot` 與入口，不能沿用「main 只有文件」的舊結論。既有 feature 分支不再作為新工作基準。
3. 本輪續作基準為 `244536b`；已合入的攤位／海岸互動／UI 交付包括 `40e27eb`、`c4eaae5`、`2424410`，另有 MAIN-15 `39570aa` 完整圈與夜燈交付；一律以最新遠端為準。臨時雲端 worktree 或引擎目錄可能已清理，不能把舊絕對路徑當永久入口。原 `/workspace/Snapland` 的其他 Session `work` checkout 不要切換。
4. 動手前讀 `AGENTS.md`、`.agents/skills/pm-ticket/SKILL.md`、`pm/user_guide.md`，再讀本組票最新需求、驗收、來源與證據。票在 `pm/`，不是外部票務系統。逐票狀態入口是 `pm/open_tickets.md`；舊勾選不代表本輪已重驗。
5. 確認實際引擎、依賴、記憶體／磁碟與渲染能力。CI 固定 Godot `4.7.2.stable.official.ed1daf0bf`；設定並核對 `GODOT_BIN`。環境不具備原生 GPU、音訊或 Windows 就照實記錄，不能捏造。

### 已交付與仍待完成

- ART-31 固定 280×360 畫布、根點與原畫頭部；ART-32 已接回八向專用待機與眨眼。正式島上保留完整 2D 原畫，沒有拆腿 3D 步態。
- ART-33／34 完成正式島上人類微風短髮、短髮及捲髮的八方向髮尾綁定；髮根、臉、帽緣與肩背不可動區保留原畫。其他種族、NPC、單次動作的完整動態覆蓋沒有因此完成。交付 `1baf7dd`，PR #1／#2 已確認 merged。
- ART-34 有 96 組渲染比較、隔離 PCK 額外 200 格、200 格定位與 432 格既有待機回歸，正常／真正慢速的島上操作及連續反向／移動中換髮證據。影片以完整人物抽幀檢視，不是逐電影格連續播放或真人試玩。
- ART-18 四款正式外套明確是換色；左右側走路／待機 24 格的衣料換色已修正，使用核對過且綁定來源指紋的衣料標記。真正輪廓替換必須整套姿勢完整，任一缺件整套保留原衣。148 格自動標記草稿因相機／衣袖誤標拒收；歷史背心不能返回正式衣櫃。主要提交 `b84746a`，證據 `dc32c14`。
- ART-18 新增明確單格候選檢視，與正式來源／錨點／快取隔離。舊候選可讀的斷言保留；最終 Godot 4.7.2 隔離 PCK 的 335 項衣物／檢視契約、72 組衣料、avatar、動畫庫、64 格髮型跨膚色／種族渲染通過。最終本機來源回退恢復與八向校準也通過。主要提交 `b1100b3`，證據 `bcd2297`。
- MAIN-2 已修復量測標記與固定畫布校正未一起平移的落差，原固定鏈長 `0.3740643274853801` 斷言未改並恢復通過；獨立鞋圖、借用色樣各守自己的座標。提交 `f35e341`／`bc6a6ec`。
- 原生島上錄影為 Godot 4.7／llvmpipe 降低環境成本 fixture，人物不降解析度。4.7.2 PCK 是 Linux 隔離測試，採 Windows Desktop preset；不是 Windows EXE、完整光影、原機器效能或完整原生美術驗收。
- ART-17／18 仍需正式 NPC 行走／個性動作與真正不同衣物輪廓的完整原畫；票票、小角缺正式走路來源，不得用拒收候選或程序拆腿代用。ART-22／其他上位票也不能只因局部髮型完成就自動結案。
- 2026-10-19 已核對 `a8f610a` 的實際 CI：前批角色／捲髮／NPC 量測與正式世界整合已通過，後續來源待機附件的完成文字與 runner 舊契約不一致。`906d314` 修復完成契約並補齊四項缺少標記的測試；23 項 Python 反例與五項實際 Godot 局部檢查通過，原 91 個執行項目、門檻、GDScript 與遊戲原圖不變。看最新遠端執行確認後續結果，不把這五項稱整套綠燈。細節在 MAIN-2 與 `design/runtime/runtime-result-contract.md`。
- 2026-10-20 已結案 MAIN-12／18／13／16，目前 75 張進行中。ART-10 `83a6397` 修復相容渲染的每物件參數耗盡，0 ERROR 原生照片流程；MAIN-2 `67906d9` 保留有界完整 CI 預算與獨立 Python 回歸，`9d250cf` 量測阿浪真正可見原圖腳底。SG-27 `45c4c94` 將錯誤計分說明同步成精準20／接近12，39項規則、54項畫面／Session及雙尺寸原生明細通過。全組首區整合在90秒上限中止，獨立240秒量測也未完成；正式個別時限未改，先核對 MAIN-2 最新定位與 CI；不能以局部通過稱全綠。
- SG-1已補齊128款候選規格與逐款理由、六款原型次序；設計五範圍和101項Python本機通過。116款仍只是設計；不擴出簡陋入口。每次核對最新主線的實際Actions，不把局部通過寫成完整套件成功。

具體驗收看：

- `pm/Snapland-art/[ART-18]同步換裝分層與角色動畫.md`
- `pm/Snapland-art/images/ART-18-side-20261017-verification.json`
- `pm/Snapland-art/images/ART-18-inspection-20261017-verification.json`
- `pm/Snapland-art/[ART-33]接入島上主角髮尾骨架.md`
- `pm/Snapland-art/[ART-34]擴充島上其他髮型動態.md`
- `pm/Snapland-main/[MAIN-2]建立設計驗證與定時CI.md`

### 接續工作與研究方法

先看最新 CI，對本批角色回歸的失敗找真實來源、畫布、錨點或快取原因，不改預期常數、刪斷言、調整測試選擇器或加 known failure。若只是 SG-1 未完成，保留明確失敗並接續角色優先事項。

下一個角色製作範圍先從 ART-18 真正不同輪廓的主角衣物做完整小批，再擴 ART-17 NPC 正式行走／完整個性演出。每批實作前至少比較六個不同來源／團隊／方法，優先實際看圖；不局限 Xbox 或 Game Accessibility Guidelines。保留來源、觀察、採用／不採用原因及有用圖例，參考圖不能當自有素材。只讀文字、只看靜態圖或只抽影片影格就照實記錄。

先核對必要動作／方向／影格清單，再製作素材；不能刪掉缺件項目就稱全套通過。新候選先查固定畫布、髮根／部件、身體完整、持物遮擋與來源覆蓋，再做實際島上正常／真正慢速、起停、轉向、換裝、暫停、降低動態、重入及打包等相關驗證。數值檢查不能代替自然度與美術判斷。跨票可重用流程整理回 User-guide，票記問題、可見改動與實際結果。

### 存檔、測試與入口安全

角色量測回歸的暫存副本也跟隨隔離存檔目錄，不依賴 Windows TEMP；比較時先回到同一作者／登錄畫布座標，保留原始量測常數。所有引擎啟動使用 `tools.godot_entrypoints.run_validated_godot`；每項測試／匯入／原生錄影使用獨立絕對 `SNAPLAND_SAVE_PATH`，不讀寫玩家正式進度。`SceneTree`／`MainLoop` 才用 `--script`；Node／Control 透過實際 `.tscn`。`.review` 快照不能當執行入口。

只跑受影響局部測試並檢查 exit、ERROR 與 PASS；完整套件交 CI。以下只是可重用範例，**不是這份文件又跑過一次測試**。先在正確 worktree 設定已核對的 `GODOT_BIN`：

```python
from pathlib import Path
import os
import tempfile
from tools.godot_entrypoints import run_validated_godot

root = Path.cwd()
engine = os.environ["GODOT_BIN"]
with tempfile.TemporaryDirectory(prefix="snapland-next-local-") as isolated:
    env = dict(os.environ)
    env["SNAPLAND_SAVE_PATH"] = str(Path(isolated) / "profile" / "progress.json")
    result = run_validated_godot(
        root,
        [engine, "--headless", "--rendering-method", "gl_compatibility",
         "--path", str(root), "--audio-driver", "Dummy",
         "--script", "res://game/tests/test_outfit_atomic_coverage.gd"],
        env=env, timeout=150,
    )
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "ERROR:" not in output and "PASS:" in output
```

原生錄影另核對 fixture、速度、輸入事件、解析度及環境成本，保存實際檢視過的證據。音訊需實際試聽；PCM 有值只證明輸出。尚未完成的遊戲、平台與全套美術不可由局部回歸推論。

### 逐票提交與整合

- 一需求一票；新票先 fetch，核對 origin/main 與自己未合併票的最大號 +1，票檔先獨立 commit／push 登記。現有票用原票接續，不另造重複票。只有實際全達成才完成／勾選。
- 作者與提交者每次均核對 `Stanley Li <stanley890314@gmail.com>`。訊息只寫票號與具體變更，不加模型名稱、Co-Authored-By、Claude-Session 等署名。
- **每次 push 前 `git fetch origin main`**。若前進，先 rebase 工作分支至最新 origin/main，保留其他 Session 修改、解衝突並重跑受影響測試；使用正確提交者設定。
- 使用者要求的 merge 是 **`git push origin HEAD:main`** 快轉整合，禁止 force push main。只有因主線再次前進而非快轉拒絕時，才重新 fetch／rebase 後正常推；403／權限拒絕不重試、不繞過，回報。
- 每票 push 後 fetch；更新本機 main 前確認它沒有其他 checkout／未提交內容，安全快轉後核對本機 main 與 origin/main 一致。不能 reset 或強改其他 Session 分支，受阻就說具體原因。
- 全部交付後只移除本 Session 已確認合入最新 main 且不用的 worktree／分支及對應遠端舊分支，保留其他 Session、未合併分支與證據。遠端拒絕刪除時停止並回報。交付說明含真實測試、證據、提交與仍未完成範圍。

## 文件入口

[長期 User-guide](user_guide.md) · [逐票未結案清單](open_tickets.md) · [本次指南審閱票](Snapland-main/[MAIN-20]整理需求指南與接續提示.md)

## 2026-10-20 本批後續交付（優先於上方舊進度）

- ART-3、ART-27、MAIN-19 已結案；89 票中 17 完成、72 進行中，具體見 `pm/open_tickets.md`。先讀 User-guide 最新擴圖要求：使用者希望內容、美術及 3D 場景模型更豐富、地圖更大；正式角色仍保留已批准的完整 2D 原畫。
- MAIN-2 `8dbb00c` 修正 NPC fixture 先登記再補素材的失敗，並補 NumPy 2.3.5；ART-20 `139f1ff` 避免反覆套用同一文字樣式，保持分數／縮放更新。完整原有首區整合 81 組於 79.37 秒通過，90 秒上限未改。
- MAIN-11 `0ec93bd` 擴大主陸布景外框 41×67→72×96（約 2.52 倍），接入可選海岸環線、六處立體地標、E 觀察、真實夜燈和可停轉水車；正式角色、十二遊戲、任務與九區入口位置／識別保留。原生自動移動與六處真 E 觀察、回碼頭約 255.59 公尺，141.7 秒／1417 格／10 FPS 影片已完整解碼並看過七個抽樣，不稱人工連續播放。Movie Maker 實際為 1280×720，不能沿 800×450 視窗請求誤標。最終另測含兩條中途回程的物理往返 315.50 公尺、全路兩側餘裕與日夜／降低動態畫面。MAIN-11 上位探索與完整角色條件仍未結案。
- ART-3 `eb9cdd0` 完成六處立體布景、原生前後與拒收中間畫面、夜燈及降低動態；不代表 ART-1 完整光影或 ART-17／18 全角色／衣物完成。
- ART-27 `b441722` 補三個來源漏字及 pixel RTL 的實際後備；字型由 30 加十組 profile，共 40 項，原斷言保留。高行距 RTL 暫停會依行高重排兩組入口，窄畫面優先顯示主要操作，避免側邊預覽和次要狀態擠出返回按鈕。新雙尺寸幾何／不重疊檢查、原三尺寸 Tab／滑鼠與偏好回歸通過。75 份正式文字來源共 1025 非 ASCII 字符的字集聯集 0 缺字，另有每 profile 實際符號檢查與原生圖；聯集不等於所有 Unicode／所有語系完整。
- MAIN-19 已在相同已合入框架重驗存讀、損毀／未知資料回退、變數、複數、焦點／對話進度與穩定識別。正式可選仍只有完整繁中；英／阿是未發布 QA，不能宣稱全作翻譯。
- 最後推送後核對最新 Actions。`139f1ff` 的獨立 Python 回歸已實際執行 97 項，剩六個錯誤都來自 SG-1 缺 `design/02-minigames/catalog.json`；NumPy import failure 已消除。新 main 的完整 CI 結果依實際 run，不能以局部通過稱全綠。不要偽造 128 款目錄或跳過檢查。
- 角色優先仍是 ART-18 真正不同輪廓、完整姿勢衣物與 ART-17 正式 NPC 動作；不得用拒收背心、候選走路、程序拆腿或凍結動作代替。沿既有七方海岸研究、八方字體研究與最新原生證據持續完善。


## 2026-10-20 最新集中交付（覆蓋前面票況快照）

- 全案 90 張，20 完成、70 進行中；本輪結案 MAIN-14／15／21，ART-20 局部交付仍保持進行中。逐張依 `pm/open_tickets.md`，不要用舊數目判定。
- 使用者最新補充：世界要生動、有趣且可融入，不能只到攤位拿拍貼；UI 要減負、有風格、善用版面與 Tab，避免堆裝飾和無謂捲動。最新需求已整理進 User-guide。
- MAIN-14 普通／輔助共用可略過的首次教學，取消不記已讀；十二攤位新檔及真實重開續玩、1.25 大字夜間輸入驗收附票。
- MAIN-21 接入可控制方向的物理海漂球、節奏潮鐘、開關水閘；不計分、不開結果面板、不改保存內容。原生發現球架搶側面互動，移位並加最近選擇回歸。新自由互動測試已加入完整 runner，舊項目及逾時保留。
- ART-20 精簡常駐資訊、對話／入口隱藏其他 HUD、縮短動作提示，四十個環境招牌走近才顯示；三尺寸大字及 E／M／Escape、原完整 shell、對話與小遊戲 UI 通過。整票及拍貼品質仍須依實際條件驗收。
- MAIN-15 修正只繞六成圈，補完整圈、真正夜燈與實際碼頭到入口步行 18.49 公尺、日夜完整搭乘；最終原生 0 ERROR，保存位元不變。
- 研究與閱讀限制見 `design/runtime/entry-and-freeplay-flow.md`；未下載成功的參考圖不能當作已看過，影片抽幀不等於人工連續播放。
- 最終完整 CI 仍需核對當前提交的實際 run；SG-1 設計缺檔沒有被繞過。ART-17／18 來源缺口沒有因世界／UI 交付而完成。


## 最新接續：SG-1設計交付（2026-10-20）

SG-1完整設計已交付，舊缺檔敘述只代表歷史。全案90張、21完成、69未結案；本機五範圍與101項Python通過。上一主線5560c23遠端runtime在第33／92項NPC世界整合停止，仍要求已停用的程序拆腿；需改以正式原畫與完整接地／姓名／暫停／互動契約驗證，不能恢復被否定步態。後九區116款設計不等於可玩，不做新入口擴張。角色及主區優先繼續。


## 2026-10-22 接續索引

目前票況以 [open_tickets.md](open_tickets.md) 與 [User-guide](user_guide.md) 為準；上方各輪次的數量與遠端SHA是歷史紀錄，不當成最新main。SG-17已完成逐次成績／資格、穩定結果翻頁、原生普通／精準／輔助／私人練習及真正新程序重開；來源與界線見本票最新Commit。ART-18本輪新衣物候選仍全數拒收，沒有新增已批准格數或正式衣櫃內容。接續前先fetch最新main及核對CI，保留其他Session工作。


### 2026-10-23 本輪停止點：SG-16

SG-16已依真實輸入、可見風向與失誤計次、新教材及Linux輸出檢查結案，票數為62完成／28未結案，以open_tickets為準。前置94de1a9完整CI已實際成功（143Python／93Godot／5設計範圍），本票新提交CI需另看實際結果。最新使用者要求完成當前票、推送後刪除本次分支並停止；本輪不續作其他票。既有ART-18拒收候選與其他票不因這次交付改為完成。
