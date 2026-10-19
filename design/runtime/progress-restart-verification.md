# 進度、離線成就與真正程序重開

2026-10-20；MAIN-5／6／8。先讀User-guide、現有核心／衣櫃研究與實作，沿用本輪已通過的核心、交易、UI及三尺寸原生驗收，再補獨立程序驗證。這是現行功能結案核對；未改成就、存檔格式、貨幣或購買規則。

## 重新比較的六份資料

- [SQLite Atomic Commit](https://www.sqlite.org/atomiccommit.html)：交易的全部或全無是可觀察結果；本次比對完整進度樹，不只查一筆照片。不宣稱現有JSON檔具備SQLite等級斷電保證，沒有斷電測試。
- [Python JSON](https://docs.python.org/3/library/json.html)：預設可接受NaN／Infinity，但標準JSON不允許；正式驗證仍拒絕非有限貨幣等值。比較用JSON序列化後的數值域，不能把int變float誤判遺失，也不放寬任務整數邊界。
- [RFC8259 §6](https://www.rfc-editor.org/rfc/rfc8259.txt)：數字精度有互通界線，超大數字不可任意強轉。物品與照片ID維持原字串與完整集合。
- [MDN Storage quotas](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria)：儲存失敗須處理；採用失敗必須可見、狀態須回滾的原則，不把瀏覽器額度當Godot檔案限制。既有衣櫃檔案拒寫反例保留。
- [Steam Stats and Achievements](https://partner.steamgames.com/doc/features/achievements)：SetAchievement後還有StoreStats與非同步回報；SDK自己有離線快取。現階段保存的是遊戲內成就與未掛SDK的待同步事件，不宣稱Steam已收到；未來掛SDK時不能另做會互相衝突的第二套SDK快取。
- [Steam achievement guide](https://partner.steamgames.com/doc/features/achievements/ach_guide)：初始化／登入可能失敗，StoreStats成功與回呼是兩個時點。保留既有adapter成功／失敗測試，不將單純布林回傳當線上平台認證。

Godot saving-games與pytest tmp_path頁本次HTTP403，沒有重試或算成已讀；既有Godot／隔離規範另依原研究及實際程式。此批沒有外部影片試玩或聽感評估。可視結果見[本輪設定／換裝圖](../../pm/Snapland-art/images/ART-25-verify-20261020-overview.png)，不是保存正確性的替代證據。

## 兩個真正的引擎程序

`game/tests/progress_restart_review.tscn`是可選的驗證場景，不加入或取代正式92項清單。使用獨立絕對SNAPLAND_SAVE_PATH，透過既有`run_validated_godot`先啟動writer（`-- --write-review`），等程序退出，再在同一路徑啟動reader。

writer以現行API建立普通／惡魔照片、成就、未完成任務、音量／文字速度／降低動態／輔助、外觀、購買與穿戴；另保存前向相容欄位。照片與成就是測試資料，不冒充自然通關。reader的PID必須不同；autoload載入後核對15個欄位的完整樹、離線待同步事件、未完成步驟、持有與穿戴，以及存檔位元組SHA256完全不變。

本輪writer PID17735、reader PID17745，兩者exit0、0ERROR及各自完成行成立。這補足同一程序`load_progress()`與真正退出重啟的差別；損毀／備份／無備份預設、交易失敗回滾、重複購買、未擁有穿戴和舊存檔遷移仍由原核心／衣櫃回歸覆蓋，沒有刪減。

本輪原生UI是800×450、1280×720與1920×1080，文字1.25倍，最大尺寸實際夜間／降低動態。舊800×600圖保留為歷史，沒有冒稱本輪又跑該尺寸。新照片與結算UI中的合成資料只驗導覽；真實取卡另有MAIN-13／16的原生流程。
