# SG-23 招牌平衡：招牌與機械搖架

## 設計方向

這一款採用固定低三分之四近景，主體是一面高大的海港木招牌與其黃銅搖架。畫面中的海平線和碼頭維持穩定，只有招牌沿真實支點轉動；同一角度驅動招牌面、儀表指針和地面影子。玩家以左右鍵或拖曳滑軌移動配重，改變對軸力矩，抵消可讀的海風。它以單一物件近景、持續配重操作和受力回饋，區別於氣球的側向飛行、花壇的俯視管網與人潮的俯視交通圖。

風力分七段，每段約 2.86 秒，預告在實際吹動前 0.55 秒出現。預告旗形、方向箭頭、力量讀值與文字共同說明風向；「海風」和「穿堂陣風」使用不同旗形。配重不能瞬間拉回招牌，玩家必須持續把重量放在能平衡目前力矩的位置。每段要在目標角度的安全帶內保持至少 0.52 秒才得分；中心精準帶得 100 分，安全帶得 70 分，未達時間得 0 分。五段安全可普通通關；七段全精準、沒有撞線才符合小惡魔條件。三次穿越外側安全線失敗，60 秒是失控／卡住時的上限。

輔助模式減弱風力並放寬安全帶與精準帶，但仍需要配重輸入和穩定停留，不會自動送出結果。降低動態只減少裝飾效果，保留真實招牌角度、影子、配重位置、風向與安全帶，因為這些運動承載操作資訊。

## 畫面構圖與材質

1280×720 畫面把木牌置中，牌面只保留「潮汐花園」、短英文副標與當前風段；題名不再和中央圖章擠在一起。牌下的直柱、雙側撐桿、黃銅固定座與鉚釘形成一條看得懂的受力路徑，配重滑軌作為同一機械的操作延伸。海面兩側用低矮岸線、燈塔和停泊帆船指出港灣位置，四道短水紋提供尺度；裝飾集中在牌與岸邊，儀表區保持安靜。

儀表、撞線／穩住／精準計數、配重滑軌、狀態列與操作提示落在一張獨立淺紙控制牌內。階段與風力預告另有一張置於牌面上方的小紙牌，確保夜間墨字不直接壓在深藍天空上，也讓分數、風段與預告各自分區。紙牌從木碼頭前景分開，底下不再穿過木板紋理；夜間沿用淺色紙面和高對比墨字。安全帶、精準帶和配重滑軌維持可辨識的形狀和位置，降低動態時仍能操作。

這次視覺整理承接本設計前述已讀來源：OpenStax 靜力與力矩用於支架和轉軸關係；Kao 的 Game Feel 綜述用於讓同一角度連動影子、指針與牌身；Kao 的 CHI 回饋研究用於把分數與成功印記接到真實停留條件；Apple Reduced Motion 與 Xbox 117 用於固定鏡頭及保留必要物理動作；Xbox 103 用於形狀、文字和方向箭頭並行；Godot CanvasItem 文件用於單一 Control 上的樞軸繪製。

## 來源閱讀與採納理由

以下來源分別涵蓋機械平衡、互動力學、遊戲回饋、動態無障礙、多通道提示與 2D 畫法；設計只取原則，不複製來源版面或素材。

| 來源 | 實際閱讀 | 採納到本玩法 |
|---|---|---|
| [OpenStax College Physics 2e：Statics and Torque](https://openstax.org/books/college-physics-2e/pages/9-introduction-to-statics-and-torque) | 靜力學把平衡描述成外力互相抵消，且旋轉也由作用力與力臂決定。 | 玩家位移配重改變力臂／反向力矩，招牌不由按鍵直接「吸回中心」。 |
| [OpenStax University Physics：Conditions for Static Equilibrium](https://openstax.org/books/university-physics-volume-1/pages/12-1-conditions-for-static-equilibrium) | 重心離開轉軸會產生重力力矩；力矩方向與轉軸距離可表示成可判讀的正負量。 | 一個角度狀態連接支點、配重力矩與安全線；超線是狀態事件而非每幀扣分。 |
| [Kao et al., CHI 2024：How does Juicy Game Feedback Motivate?](https://doi.org/10.1145/3613904.3642656) | 預註冊大型實驗分別操弄回饋量、回饋是否依賴挑戰成功、以及回饋多樣性；成功依賴對好奇、效能感與勝任感皆有影響。 | 穩定分數與木牌回正／章印在實際達到停留條件後才觸發，普通與精準結果使用不同回饋。 |
| [Kao et al., IEEE Transactions on Games：Designing Game Feel: A Survey](https://doi.org/10.1109/TG.2021.3072241) | 研究綜述以物理一致性、回饋放大與輸入支援整理 game feel 設計。 | 角度由受力模型推進，輸入是連續配重調整，成功回饋只放大已達成的物理結果。 |
| [Apple Developer：Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria) | 對模擬深度、旋轉及持續動態應提供可調整方式；若動態表達狀態，應改用較少動作但保留理解資訊。 | reduced mode 停止裝飾擺動／脈動，但不能凍結真實牌角或隱藏風力方向、狀態和目標帶。 |
| [Xbox Accessibility Guideline 117：Visual distractions and motion settings](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117) | 非玩家觸發的視野與畫面重複移動需審慎處理；鏡頭晃動和強制視角變化可能造成不適。 | 相機固定、港景不跟著搖，只有必要的招牌物理角度改變。 |
| [Xbox Accessibility Guideline 103：Additional channels for visual and audio cues](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103) | 關鍵提示應以文字、符號、形狀等多種方式表達，避免只靠顏色判斷方向或警告。 | 左／右箭頭、不同旗形、文字標籤與顏色共同呈現風向和安全狀態。 |
| [Godot 4 CanvasItem drawing API](https://docs.godotengine.org/en/4.5/classes/class_canvasitem.html#class-canvasitem-method-draw-set-transform) | CanvasItem 的繪圖 transform 可讓同一組局部座標繞固定支點做平面旋轉；文字與 primitives 可以直接繪製。 | 用單一原生 2D Control 組出木牌厚度、支架、黃銅軸和遠方港景，避免平面背景素材或額外節點。 |

## 範圍與驗收要點

- 純狀態模型以 `reset(assisted)`, `set_balance`, `step`, `snapshot` 對外；`snapshot()` 回傳同一個可重用字典與其巢狀階段資料，呼叫者依約定只讀。
- 單一受力角度連動木牌、指針與影子；預告先於實際力矩，七段真實模擬各自變化。
- 達成結果需有連續安全帶停留，錯向配重可撞線、復原並再次失衡；普通及小惡魔規則依段落成果與撞線紀錄判定。
- 顯示支點角度、安全帶、精準帶、風向、力量讀值、配重位置、階段、分數與撞線數；主要幾何留在 1280×720 且避開 `(34,18,1212,112)` HUD。
- reduced-motion 保留物理結果及必要操作線索，只關掉裝飾動態。
- 局部 headless 測試涵蓋可控七段路線、錯向失敗、普通門檻、輔助、超時、重置、完成段數快照、裁切與日夜配色；這些測試單獨不代表 GPU 原生遊玩已驗證。

## Runtime 接線與證據範圍

`game/minigames/session.gd` 將方向鍵映射為持續配重移動，拖曳則由獨立 2D 畫面滑軌送入同一個平衡狀態。每幀推進 `SignBalanceModel.step()`，使用 snapshot 的 `completed_stage_count` 消費真正完成的七段帳本，並將 70／100 分事件寫入共用成績摘要；撞線、普通結果和小惡魔條件都由模型輸出。暫停不推進模型，重試與練習都立即重設物理狀態和事件帳本，練習旗標沿用共用結果契約。

七段帳本有七筆預先配置的記錄；snapshot 的 `stage` 是顯示用零起始索引，`completed_stage_count` 則明確回報已完成帳本筆數。Session 以這個計數同步發獎，避免最後一段仍顯示索引 6 時漏掉第七筆 100 分，也不依賴逾時或撞線時的計時器狀態。結算預期讓每一段使用獨立列，顯示段號、精準／安全帶類型和該段分數，而非把七次精準合併成一筆；局部回歸現驗證七個實際段名各自列出及合計 700，原生 v5 畫面已驗證第一段明細顯示；七列完整捲動版面仍待 UI 改善。模型回歸涵蓋完成數 0–7、段中撞線／逾時，並從實際方向鍵 action 推進完整七段；模型帳本、Session 分數及結果訊號都須為 700，且結束後不重複發獎。

`game/tests/test_minigames.gd` 驗證 session 的按鍵、受力、暫停、重試和練習接線；`game/tests/test_sign_balance_model.gd` 與 `game/tests/test_sign_balance_view.gd` 驗證獨立規則和幾何。原生 GPU fixture `game/tests/native_sign_balance_review.gd` 已由實際主選單、園區 E 互動、HUD 按鈕及七段方向鍵控制通過：正常速度的正式路線得到七段精準、零撞線、700 分及實際惡魔結果；降低速度路線也通過；輔助／降低動態練習實際完成並得到 700 分，但沒有保存收藏或計數。相同流程實際驗證指標滑軌拖曳、暫停／恢復、確認重試即時重設及練習結果返回。

原生證據：`.review/sg23-normal-v5.log` 和 `.review/sg23-slow-v5.log` 都有 fixture 的 `PASS` 結尾；正常影片 41.43 秒，四分之一速度影片 162.25 秒。主 Session 實際觀看兩種速度的配重、風向、牌角和結果；正式七段精準、零撞線合计 700 分，輔助／降低動態的指標練習也為 700 分且收藏與計數不變。影片及四張截圖保存在 `pm/Snapland-small-game/images/SG-23-*`，教學三張截圖已換成同一版本的實際畫面。這些記錄只代表目前 SG-23 原生流程的驗收範圍；首次教學、失敗／離開流程與最終美術檢查仍待完成。設計文件、headless 結果或單張截圖均不替代相應的實際驗收。
