# 上島與迎賓大道第一版

日期：2026-10-11。開始基準 c1b7b19，分支 feature/island-first-park。遵循現有普通18、惡魔12、收藏不消耗與免費輔助基線。

## 玩家流程

碼頭下船短演出 → 可略過導覽 → 主廣場導覽與收藏冊 → 迎賓大道十二設施自由選擇 → 獨立遊戲結算拍貼 → 任務／探索填滿十八普通來源。其他九區入口顯示名稱與原設計收藏門檻，但標示施工中；达到門檻不冒充園區內容已完成。船上序章後續可接碼頭 entry。

第一版單人可執行；座位／多人沿用設計要求作擴充基線，本輪不宣稱已實作同機與 P2P。其他區／異空間完整遊戲另行交付，十二惡魔滿集有成就與門口提示。

## 畫面与介面

Godot 4.7.2，3D 正交相機、像素 billboard 角色、程序生成原創布景、陰影、水面 shader、動態花朵／氣球／旗幟與晝夜燈光。暖海綠、奶油白、珊瑚紅與金色，讀得清楚的繁中 UI。主要操作 WASD／方向鍵移動，E 互動，Esc 返回／暫停，滑鼠選項。所有對話与結算可快速返回。

## 分工與接口

共用 worker 擁有 project.godot、game/main.tscn、game/core、core test、runtime runner 與 CI；遊戲 worker 擁有 game/minigames、welcome_games.json 與遊戲測試；故事聲音 worker 擁有 game/story、game/audio、assets/audio、story test。主 session 擁有 game/main.gd、game/world、game/ui、整合測試與美術資產。

Progress autoload 管理照片、成就、任務、設定與原子存檔。complete_game(game_id,devil,assisted) 授予固定來源与成就。遊戲 session Control.start(id,assisted) 發出 finished({game_id,success,devil,score,assisted})／cancelled。StoryDirector 提供對話与三步選項任務資料，AudioDirector 提供 play_context、play_sfx、apply_settings、set_paused。

## 交付與驗證

22 張獨立票：MAIN-3..7、ART-1..2、MIC-1、ST-2..3、SG-2..13。每張先研究、標基準、實作、局部測試、原生截圖、主 session 檢查，再逐票提交。原生跑畫面与自動输入狀態測試分開記載，試聽／實體手把等無法確認項目不勾選。

既有 origin/main 缺 design/02-minigames/catalog.json（SG-1 未完成），導致既有 games／all／links 驗證失敗；不更改選擇器、不掩蓋這個缺口。當前十二款以新 runtime 資料提供，不宣稱已完成128款目錄。
