# NPC 正式原畫與測試契約

2026-10-20；MAIN-2；開始main `47f9601`。上版[實際CI](https://github.com/deadline314/Snapland/actions/runs/39319136915/job/118288460285)在第33／92項停於「正式世界必須啟用量測拆腿」的舊斷言，90秒後失敗。使用者已否定該步態，ART-17正式島上只用完整原畫；不能為了測試把它開回來。

## 六方方法比較

本次重新閱讀以下官方／作者文字，無參考影片或新參考圖；沿用[結果契約既有診斷圖](runtime-result-contract.md)，不把無頭測試當美術試玩。

- [Google Testing：測行為而非實作](https://testing.googleblog.com/2013/08/testing-on-toilet-test-behavior-not.html)：以可觀察行為為主；必要實作檢查限在真正契約。正式角色必須維持完整原畫，測它實際顯示的腳與姓名，不能要求隱藏候選當正常步態。
- [pytest斷言](https://docs.pytest.org/en/stable/how-to/assert.html)：失敗應帶可定位比較。保留角色、姿勢和相機角度的錯誤文字，不把assert降成警告。
- [Godot命令列](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)：headless／script是原生入口；quit不是成功證據。固定4.7.2，仍檢查實際完成行。
- [Python subprocess](https://docs.python.org/3/library/subprocess.html)：退出碼與兩個輸出通道分開。仍須exit0、0 ERROR、完成行三者成立。
- [CMake PASS_REGULAR_EXPRESSION](https://cmake.org/cmake/help/latest/prop_test/PASS_REGULAR_EXPRESSION.html)：文字匹配可覆蓋退出碼的行為不適合此案，不採用。
- [Meson unit tests](https://mesonbuild.com/Unit-tests.html)：成功、略過、錯誤和有界逾時分別記錄。保留原92項與每項90／240秒，不設known failure。

## 正式測試與候選測試的邊界

正式世界：三人登記、完整Sprite可見、沒有隱藏拆腿驅動器、原畫與shader同一張圖、完整畫布、固定像素尺寸與單位比例。腳底檢查獨立從可見影格alpha像素投影至相機平面，比較每點實際地形；故意下移0.2m必須被拒絕。姓名仍保留原0.07–0.085m間距，測18度／30度相機，改按實際原畫身高比較。

NPC根點保留作者座標；地形可見腳底由獨立billboard錨點處理。不能把根點強移到另一個候選rig的地面座標來讓斷言通過。初始化先把AnimationPlayer、動作時鐘與互動點採樣在同一時間，避免deferred coroutine已在幀中段時拿兩個不同時間當「初始」。

原有阿浪側步±0.6m、互動點跟隨、對話中招呼、路線凍結、低動態復原、模態暫停、不爆發補播及清理繼續驗。候選量測的三人兩向來源、固定鏈長、cache、接地、缺來源回退等仍由既有獨立opt-in測試保留；本次沒有改該測試、來源、角色程式或切換正式步態。


## 第二批：測試邊界與後段真實缺口

前批合入後，遠端[39322468425](https://github.com/deadline314/Snapland/actions/runs/39322468425)的設計／Python工作已成功，原生測試前36項通過，在缺來源候選的舊世界fixture停止。本批保留92項命令、完成行及90／240秒門檻，修正四個具體契約：

- 缺走路來源的測試先確認正式Main沒有啟用量測候選，再在此隔離fixture明確opt-in；所有原缺來源／路線／對話／暫停條件不變。結束採Main既有audio shutdown及短暫收束後釋放，先前有資源洩漏ERROR的執行拒收；尚不能由此斷定唯一洩漏原因。
- 3D角色可見腳底按正式shader的alpha≥0.5量測，不把不可見抗鋸齒尾巴當鞋底。站姿／招呼等接地2px限制保留；走路逐格下半身必須精確保持已核准的固定畫布來源，整格故意下移1px會被拒絕。原畫中抬腳姿勢不重新逐格對地，但這不代表ART-17自然步態已完成。
- 透視控制器用獨立可見、未登記姓名作反例；遠處廣場招牌原由本地顯示距離管理，另確認透視不覆寫它。保留遮擋／材質／碰撞／完整實際穿越條件。
- 泡泡拍照fixture跟Session一致，首張呈現前先同步真正角色大小；以另一個renderer的原始RGBA位元組獨立量測全部待機格alpha聯集，替代已退休素材的206×298固定數。三輪路線完整走到finished，以中心移動範圍檢查500×40px，再比對文字遮擋，避免以衣服寬度冒充路線完整。

四項Godot4.7.2及23項Python契約均通過，沒有改正式角色、素材或小遊戲規則。後段診斷另找到帽子救援的真實原畫差異：當前待機中央髮頂72px，接帽序列48–59px，風格／頭身也不同。不能把12px限制調寬或以舊待機代替正式角色來通過；該失敗原樣保留，接續由SG-20／ART-17修素材。此批不是完整CI綠燈，也不是正常速度動畫或遊戲品質驗收。
