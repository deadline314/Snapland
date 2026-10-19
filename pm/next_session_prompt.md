# 下一個 Session：接續 Snapland 未完成票

2026-10-19（Asia/Taipei）。下方 Prompt 可整段獨立使用。這是工作入口與範圍快照，不是新一輪遊戲、GPU 或聲音驗收。實際主線以 fetch 後的 `origin/main` 為準。

## 可直接貼上的 Prompt

接續完成 Snapland。使用者已要求自主研究、設計、實作與驗證，不要為一般設計判斷停下詢問；先處理角色一致性，再依相依改善光影、動畫、玩法與 UIUX。品質不足可重做，保留已接受的原圖與其他 Session 成果。不要只交研究、計畫或生成候選。

### 先找到正確主線與規範

1. Repo：`https://github.com/deadline314/Snapland.git`。先核對 cwd、遠端、`git worktree list` 與 dirty files。不得切換、reset、clean、stash 或攜走其他 Session 的工作區／未提交內容。
2. 執行 `git fetch origin main`，從最新 `origin/main` 建自己的分支／獨立 worktree。**main 已包含可執行遊戲**；確認 `project.godot` 與入口，不能沿用「main 只有文件」的舊結論。既有 feature 分支不再作為新工作基準。
3. 本批已核對的遊戲主線是 `bcd2297f238c584c98ff66df7aeccd1887360183`；之後有指南與票況整理提交，仍以最新遠端為準。臨時雲端 worktree 或引擎目錄可能已清理，不能把舊絕對路徑當永久入口。原 `/workspace/Snapland` 的其他 Session `work` checkout 不要切換。
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
- SG-1 缺 `design/02-minigames/catalog.json` 仍阻擋全域設計 CI；128 款設計未完成，不能捏造目錄或刪檢查讓 CI 變綠。每次核對最新主線的實際 Actions，不把局部通過寫成完整套件成功。

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
