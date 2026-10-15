# 下一個 Session：接續雕琢 Snapland 島上體驗

更新：2026-10-15（Asia/Taipei）。**把下方「可直接貼上的 Prompt」整段交給下一個 Session。** 本文件是接續工作指令與狀態快照，不代表又完成一次遊戲驗收。

## 可直接貼上的 Prompt

你要接續完成 Snapland。使用者已授權自主研究、設計、實作與原生驗收，先把島上體驗雕琢到可作為後續園區標準；不要再只交研究、生成圖、計畫或半完成展示。保持簡短進度溝通並持續做已授權工作，品質優先於趕進度。以下需求及使用者後續新指示優先。

### 先找到真正的遊戲版本

- Repo：`git@github.com:deadline314/Snapland.git`。本機原始 checkout 是 `C:/Github/Snapland`，但不要切換或修改其他 Session 的 checkout／stash。
- 可執行遊戲在既有獨立工作區 **`C:/Users/stanl/.codex/worktrees/island-experience/Snapland`**，分支 **`feature/island-experience`**。最後已核對的遊戲交付 HEAD 是 **`8f141fbeed9366d3b61ec0e98ac57b8edf8a58f3`**；之後可能有本次文件提交，開始時以 fetch 和實際 HEAD 核對。
- **main 截至本次整理只有設計／票據等內容，沒有 `project.godot`；不能從 main 另建空白遊戲或把沒有引擎專案當成遊戲程式遺失。** 文件已另外發布至 main，不代表整個遊戲 feature 已合入 main。
- 優先沿用上述合適工作區；先看 `git worktree list`、目前分支、dirty files 和遠端，不覆寫已有成果。現有工作區有大量先前未追蹤媒體、匯入變動與未完成票；禁止 `git add .`、整棵 clean／reset／stash。
- 若該工作區仍由另一個活動 Session 使用，從 `origin/feature/island-experience` 建自己的獨立工作區，不能從 main 重建或擅自攜走未提交變更。新工作區需真正驗證依賴、匯入和原生畫面，不能假定原機器上的未追蹤檔也已在遠端。
- Windows／PowerShell；先前實測 Godot 4.7.2 Forward+，路徑 `C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe`，GPU 為 Arc B580。當次自己核對引擎版本與資源。若是雲端，先確認 Snapland repo、fetch 成功、Godot 可跑、實際記憶體及磁碟，任一不成立就回報，不捏造原生驗收。

### 只讀必要文件與本組票

1. 讀工作區的 `AGENTS.md`、若有 `CLAUDE.md`、可用的 ai-desktop-ticket skill，以及 `.agents/skills/pm-ticket/SKILL.md`；若有 `.claude/skills/pm-ticket/SKILL.md` 也依適用規範讀取。票是 `pm/` Markdown，不在 AI Desktop 開。
2. 讀最新 `pm/user_guide.md`。如果工作區仍是舊指南，先用 `git show origin/main:pm/user_guide.md` 取得本次整理版本，避免丟失最新更正。
3. 先讀 ART-17、ART-18 的最新需求、Commit 與相依；需要時再讀 ART-3／19（背景）、ART-12／13（角色、光影）、ART-20／21（UI）、MAIN-11／14／15（探索、攤位、設施）、MAIN-17／18（存檔與入口）、MAIN-19／ART-22（多語系、字體）、MIC-2、ST-4／5、SG-14／16–27 的相關段落。只讀本批需要的票，不全 repo 掃完。
4. 必要設計文件位於遊戲 feature 的 `design/runtime/character-animation-wardrobe.md`、`wardrobe.md`、`component-animation.md` 等。先比對實際程式與素材，不把文件寫有需求當成已實作。

### 使用者品質底線

- **先做好島**：主區域與第一園區完整，其他區域先做路口；從上島開始，未來另接船上序章。探索、特色設施、休閒、拍貼、主支線與可交談角色要形成真的遊樂園，不是一排小遊戲按鈕。多看《炸彈超人樂園3》。
- **高精緻像素 HD-2D**：像素角色與真正立體布景、光影、遮擋和動態相互成立，不是簡陋像素放大或平面圖加特效。避免通用 AI 插畫；參考使用者肯定的海港圖與更有個性的角色圖，保留自己的世界特色。紙劇場／青綠珊瑚等是先前方案，不是永久不可改的使用者定案。
- **動畫是目前優先修正項**：主角與每位 NPC 都要專用站姿、呼吸／眨眼、待機小動作、自然行走起停／轉向、互動、情緒與專用動作。主角採八方向，NPC 依活動需要完整覆蓋方向。依角色安排服務、拿盤子、巡走、舞蹈等生活節奏，不能全場同步或永遠招手。
- **已有八方向走路圖就直接播原圖**。使用者最新再次否定了額外套在上面的怪步態；不能重啟拆腿、膝蓋拼接、轉鞋、整身伸縮或角色 shader 扭曲。更多幀要有真正姿勢變化，不能用重複圖、平移與像素差異充數。
- **人物一致且完整**：每格頭髮、臉、衣服、手、腳、鞋、包袋、相機、角尾都完整，身份和比例穩定，不分離、不截斷、不穿地。來源裁切、圖集跨格、鏡頭與地物遮擋分開檢查。正常速度、四分之一慢放、全身逐姿勢都真的看過再接受；先前「看過」仍被使用者指出怪異時，必須重查。
- **紙娃娃**：衣帽可購買收藏自訂，膚色／種族／性別／基礎外觀免費無限換；衣物不鎖性別。髮帽衣物與身體共享動作／方向／影格與正確遮擋，不獨立計時。不同衣服最終有不同輪廓，同一件外套不能待機變背心、走路又變外套；缺素材明確列缺口。
- **環境與日夜**：物件依材質有合理動態，不把所有剛性物件亂晃；NPC 站位避遮擋。主角後方建築用夠大的圓形透視，可比較柔和邊緣。影子跟光源方向對應。凌晨／中午／傍晚／晚上可隨時切，融入拍貼、任務及小遊戲光影背景。
- **全遊戲 UIUX**：重新檢查 HUD、暫停、設定、旅券、收藏、拍貼、衣櫃、教學、開場與結算。精緻像素、克制偽3D厚度／高光／投影；充分用畫面，主要操作一次看見，盡量不捲動，長內容分類分頁。不要小窗大卡、不必要／巢狀捲動、文字重疊或裁切。參考《歧路旅人》《幻想水滸傳》等多方案例。像素字體要清楚，保留多語系、缺字後備、長句與文字方向框架。
- **教學與對話**：少常駐長提示，完整教學要有實際截圖、可略過重看；對話用正常對話框，所有出現的角色都可談話，先用克制的滴滴聲。
- **每個小遊戲都新鮮**：同園區共用主題，不共用所有場地／鏡頭／動畫。依玩法用2D、2.5D、HD-2D或3D，做專業操控、目標、得分和回饋。氣球快遞特別要修無聊、操控弱、看不見海風與引導弱；風需可見、可預判且真實參與玩法。
- **音樂音效全部 CC0**，保留授權頁、作者、來源和雜湊，挑真正合適的音色／節奏。不能把免費當CC0、把PCM／音量通過當試聽或好聽。
- 每款小遊戲、每區通關與小惡魔收集等有遊戲內成就，保留 Steam 接口；未平台確認不算同步。收藏不消耗、離線收藏與平台可交易經濟分開。長期100款以上基本小遊戲／128候選與多人等依 AGENTS；不是這批已完成。

### 現在實際完成到哪裡

- **ART-17 仍進行中**。`e8320de7ab71ac2d716d314ba09f95834116535c` 恢復主角八方向各八格原圖，停步、真實距離相位、完整招手／拍照／互動，移除角色額外扭曲與正式島嶼的拆腿優先。阿浪用真正左右各四格。票票與小角沒有批准的完整走路，現在保留原地專用待機，不能說整套已完成；2026-10-15 已補主角左／右各四格專用站立、呼吸與短眨眼，並修正慢速換向仍短暫播相反走姿；後與四個斜向專用待機仍未補齊。來源、正常／四分之一模擬速度、三組外觀、降低動態、重入與實際 Windows exe 本批局部通過，詳見 ART-17-side-idle-verification.json；不是整套角色完成。
- **ART-18 仍進行中**。`48a8ab9580508dbb11cae6d269766d0512201091` 修正衣櫃「珊瑚紅外套」在前方動作選到不完整背心的身份切換；目前一律用正確外套姿勢配色。這不是不同衣服完整輪廓已完成。被拒收背心走路候選有跨格，重試又改姿勢，沒有採用。
- **MIC-2 仍進行中**。`629da35d2ff6d7f33e9337c24b735b31beeccb15` 有日夜／區域混音、對話降音、靜音／重入等，先前 WASAPI 25.71秒錄音與局部測試通過。沒有主觀音色試聽完成，也沒完成十二款獨立選曲。
- 先前局部通過：原圖主角行走、NPC真實來源路線、世界狀態、元件效果、髮帽貼合、坐姿、外套一致性、音訊與 Main 整合；原生四角色來源錄影、降低動態／重入、預設外觀QA包及普通Main啟動都有證據。**不是全部角色與全島的精品品質驗收。** 額外完整髮型矩陣曾150秒逾時，未算過。
- 證據主要在 `pm/Snapland-art/images/ART-17-authored-*`、`ART-18-coral-jacket-consistency-v1-*`、`pm/Snapland-music/images/MIC-2-dynamics-v1-*`。影片慢放有的是正常影片延長四倍，不能寫成另一輪慢速模擬。報告中的 technical PASS 與 content／visual pending 要分開讀。
- 最新普通本機試走：`C:/Users/stanl/.codex/snapland-qa/side-idle-20261015-v1/Play-Island-Preview.cmd`；以同資料夾 `profile/progress.json` 隔離存檔。本批程式／素材交付 `8f141fb`，不是整島完成版本；已實際輸出並經正常啟動／保存／退出檢查。舊 `build/island-walk-preview-20261014/` 仍為 `cf7578a`，不可當最新版。裸開 exe 不會套用 launcher 的隔離設定。

### 第一個具體工作

先用隔離存檔進入實際島嶼，重看現有原圖步行正常／慢放，確認不曾恢復舊程序步態；讀 ART-17／18 最新覆蓋與逐角色來源表，核對主角非正面待機、票票／小角正式行走及衣物覆蓋缺口。**先讀 ART-17 的 2026-10-15 拒收紀錄：票票五次新候選都沒有可靠的反側接地，最後一次還增加襪口，未接正式巡走；不要重複同一生成方式。先選一個缺口做完整小批交付（票票行走需要可靠的全身關鍵姿勢製作方式），從研究／素材／接線到正常與慢放全身審閱及換裝回歸真正做完，再推進下一項**；不要把候選升為已批准或反覆推倒已有原圖系統。若有更新的使用者試玩回饋，先解決該回歸。

### 研究、委派、測試與 Git

- 每個新研究主題至少六個跨作品／團隊／方法來源，記錄實際看到內容、採用理由及圖；未看影片／未試聽就明寫。過去已有八方角色製作文字研究，不要每次從零重讀或假稱新做過。新東西或兩三次不成功先查成熟做法。
- 可委派工作給 gpt-6-luna，明確檔案／邊界／驗收、只回結論；同件事超過三輪仍失敗才用 gpt-6.1-sol。主 Session 生成、跑GPU並親自驗收。代理不搶檔，不相信自報「通過」。
- 先fetch、新需求先票。取 origin/main 與自身未合併號碼的最大值+1，按專案分號，先提交推送票檔再實作；同需求沿用既有票，避免重開一批重複票。
- Git專案身份 `Stanley Li <stanley890314@gmail.com>`；不加助理／模型品牌、Co-Authored-By。每張票固定起始SHA、進行中；只交付本組檔案，必要跨組最小修改並記錄。
- 只跑受影響局部測試，完整套件給CI，不換selector／刪assert／加knownfailure／把逾時或缺工具算過。完整入口為 `python tools/run_game_tests.py`（留CI）；文件改動可用 `python tools/verify_design.py --scope links`。
- 原生輸入要測真實事件傳遞。直接呼叫方法、來源像素正確或容器矩形正確，不能當原生手感、動畫自然、UI可讀或聲音適配完成。
- **任何測試、預覽、錄影都設獨立絕對 `SNAPLAND_SAVE_PATH`**，不在Godot正式userdata，不用舊測試存檔當正式進度復原。當次先記錄正式檔／備份雜湊，之後使用者的正常遊玩可能改變它們，不可強制還原舊雜湊。
- 用 `tools.godot_entrypoints.run_validated_godot` 驗證入口：SceneTree／MainLoop 才用 `--script`；Node／Control 經 `.tscn`。不可直接跑 `.review/commit-slices/*.gd`，提交快照保留純文字。
- GPU原生用Forward+；GL compatibility在這個世界曾遇uniform上限。Godot CPU／GPU任務避免同專案搶跑；保留exit、ERROR與PASS摘要。新腳本要真正解析與執行，不把檔案檢查當編譯成功。
- 錄影30FPS要用ffprobe核對；Root重看實際畫面。瀏覽器video硬體層截圖曾卡首幀，應核對編碼影片／抽幀或可靠canvas播放，不只看currentTime。拉近鏡頭時NPC鞋子不能被主角擋住，角色也不能被屋頂遮住再宣稱完整。
- 音訊PCM用真實WASAPI與實際時間，不能Dummy/headless或fixed-fps當試聽證據。普通包正常退出用既有 `--smoke-test` 的保存／關閉路徑；先前硬切 `--quit-after` 在MovieWriter時曾報退出資源仍佔用，不得包裝成正常退出通過。
- 截圖／影片放各票 `images/`；票用「問題—改動—驗收」，附簡短結果、分支與遠端提交。全驗收才依流程fetch／rebase、局部複測、快轉main轉審查；未過留feature push且票進行中。遠端拒絕不重試、不繞過。
- 不改其他Session分支、工作區或stash；不清未合併交付分支。收尾做本批互相影響檢查，誠實逐票報結果、測試、圖／片、提交、狀態與缺口。

### 安全的局部測試範例（從遊戲工作區執行）

以下是可複用命令範例，**不是這份交接新執行過的測試**。先核對測試檔、引擎與作用範圍，不為無關改動重跑。

```python
from pathlib import Path
import os
import tempfile
from tools.godot_entrypoints import run_validated_godot

root = Path.cwd()
engine = "C:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe"
with tempfile.TemporaryDirectory(prefix="snapland-next-local-") as isolated:
    env = dict(os.environ)
    env["SNAPLAND_SAVE_PATH"] = str(Path(isolated) / "profile" / "progress.json")
    result = run_validated_godot(
        root,
        [engine, "--headless", "--rendering-method", "gl_compatibility",
         "--path", str(root), "--audio-driver", "Dummy",
         "--script", "res://game/tests/test_avatar_authored_walk_loop.gd"],
        env=env, timeout=150,
    )
    output = result.stdout + result.stderr
    failures = [line for line in output.splitlines() if "ERROR:" in line]
    passed = [line for line in output.splitlines() if "PASS:" in line]
    print("exit", result.returncode, "errors", failures, "pass", passed)
    assert result.returncode == 0 and not failures and passed
```

若是 `test_integration`，它是Node場景，應將命令末端改成 `res://game/tests/test_integration.tscn`，不要加 `--script`。原生動畫證據使用 `game/tests/native_island_animation_acceptance.tscn` 與新的絕對輸出目錄，依該檔參數實際操作；它調整了鏡頭且使用腳本輸入，不能稱真人試玩。完成修改後更新指南對應段落及本批票，不要只回覆已理解。

## 交接附件索引

- 長期需求與三張使用者喜好／否定圖：[user guide](user_guide.md)。
- 來源雜湊與圖的用途：[三張原圖來源](Snapland-main/images/MAIN-20-reference-provenance.json)。
- 本次文件整理票：[MAIN-20](Snapland-main/[MAIN-20]整理需求指南與接續提示.md)。
- 最新角色局部交付與證據：[8f141fb](https://github.com/deadline314/Snapland/commit/8f141fbeed9366d3b61ec0e98ac57b8edf8a58f3)。原分支未完成事項仍要看其票，不能只依本摘要勾完。
