# 主角完整製作樣本實作計畫

**Goal:** 以獨立樣本驗證主角八方向的換髮、戴帽、短／長外套、持相機和行走起停轉身；看過正常與四分之一慢放後才考慮其他角色。

**Architecture:** 可編輯的立體角色場景與製作關節離線輸出完整畫姿；同一姿勢的部件使用同一畫布並按真實深度合成。執行端只消費烘焙資料，以實際位移推進唯一姿勢狀態。保留舊素材與未提交修補，獨立樣本不改正式島嶼角色入口。

**Tech Stack:** 現有 Godot 4.7.2 供離線立體製作、烘焙與原生樣本；Python 3.12／Pillow 供資料驗證、圖集與錄影檢視。外部 Blender 執行環境在本機不存在，官方 wheel 查詢無可用版本；本批使用現有引擎保存可編輯 3D 場景，不為取得工具改動全機設定。

**Spec:** [ART-28 已批准方向](character-production-pipeline-v2.md)，2026-10-15 使用者明確要求直接製作主角完整樣本。

## Global Constraints

- 只做主角，不擴 NPC；完整八方向，兩種髮型、一頂帽與無帽、兩件不同輪廓服裝、相機。
- 像素畫風與既有主角身份須親自比較；工具輸出成功不算美術批准。
- 綁定與動作發生在可編輯製作原件；樣本遊戲內只播放圖集，禁止即時拆腿、轉鞋、辨色補頭皮。
- 任一 Godot 執行使用絕對隔離 SNAPLAND_SAVE_PATH，經 tools.godot_entrypoints.run_validated_godot 驗證入口。
- 正常速度、四分之一模擬速度、逐姿勢、換裝、事件次數與打包普通啟動均留下證據；拒收素材不能宣稱通過。

## Review Focus

1. 帽／前後髮／頭／袖口的交錯遮擋：完整底圖與同場景深度輸出，不以 alpha 外框重置原點。
2. 低頭持相機：兩手固定握點且鏡頭不被誤算成臉；道具不隨獨立計時器漂移。
3. 起步／半步停下／快速反向／貼牆：接觸腳階段明確，零位移不空走。
4. 動作中換裝與暫停恢復：同幀外觀切換，保留相位，事件不重複。
5. 缺格／錯版本與一般啟動：指出缺口並完整保底；樣本不污染玩家存檔與正式島嶼入口。

## Task 1：角色原件與離線輸出

Files: `tools/hero_sample/hero_author.gd`、`tools/hero_sample/bake_hero.gd`、`assets/characters/hero-sample-v1/hero-source.tscn`、`assets/characters/hero-sample-v1/manifest.json`、`tests/test_hero_sample_assets.py`。

- [ ] 先寫測試：manifest 必須包含八方向、兩髮型、有／無帽、兩種外套及相機姿勢；移除指定背向相機格應驗證失敗。先執行並記錄缺素材失敗。
- [ ] 製作保持頭身與相機身份的完整光頭底圖、頭髮、帽、衣服、背包、雙手道具；關節原件保存為可編輯場景。
- [ ] 先輸出三向關鍵姿勢並親自比較畫風、遮擋與全身；失敗回原件修正，再輸出八方向與完整動作。
- [ ] 輸出同一邏輯畫布、姿勢相位、左右落腳、握點與來源版本；整套外觀的完整逐格圖共用同一姿勢採樣。
- [ ] 驗證所有組合覆蓋與圖像完整，保存可重烘來源與命令。

## Task 2：唯一姿勢播放器與換裝

Files: `game/world/hero_sample_pose.gd`、`game/world/hero_sample_library.gd`、`game/tests/test_hero_sample_pose.gd`。

Interface: `advance(delta: float, displacement: Vector2, desired_direction: Vector2, photograph: bool) -> Dictionary` 產出 action/direction/frame/phase/events；`texture(appearance: Dictionary, pose: Dictionary) -> Texture2D` 取得同姿勢完整外觀。

- [ ] 先寫測試：實際位移零不推進 walk、半步停止進 stop、反向進 turn、完成拍照只發一次快門、換裝不重設相位、暫停保留樣本；執行觀察失敗。
- [ ] 實作 idle/start/walk/stop/turn/photo 的明確過渡、接觸階段與單次事件；根位移由場景控制。
- [ ] 外觀以完整已烘焙組合原子切換，拒絕未知版本與缺格，不引用舊辨色合成器。
- [ ] 執行局部測試與故意損壞的素材契約測試，保存結果。

## Task 3：可操作樣本與原生驗收

Files: `game/review/hero_sample.gd`、`game/review/hero_sample.tscn`、`game/tests/native_hero_sample.gd`、`game/tests/native_hero_sample.tscn`、`tools/hero_sample/run_review.py`、`pm/Snapland-art/images/ART-29-*`。

- [ ] 實作八方向移動、碰撞牆、方向／動作顯示與換髮／帽／衣服／相機控制；正常與慢放速度切換。
- [ ] 驗收序列逐個檢查外觀組合、八方向走路、半步停下、反向轉身、貼牆、持相機、動作中換裝與暫停恢復。
- [ ] 以原生腳本輸入錄影正常與四分之一模擬速度，輸出完整逐姿勢圖；主 Session 親自看完所有必要片段並記錄拒收或通過。
- [ ] 跑受影響 Python 與 Godot 局部測試，做輸出版本普通啟動；未實際看過不勾選驗收。
- [ ] 獨立審閱整批差異，更新票、指南與證據；只提交本票內容並 push。既有未提交補丁保持原狀。

## 執行紀錄

- 2026-10-15：使用者批准方向並要求直接製作主角樣本。本對話直接執行，不再要求重複批准已明確授權的工作。
- Ruling：使用現有 Godot 保存作者場景與離線烘焙，代替尚未安裝的 Blender；批准設計要求可編輯 3D 原件而非特定軟體。若原件或像素風格不成立，必須拒收，不能因工具替換降低要求。
