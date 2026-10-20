# [MAIN-9] 提供四時段切換與拍貼收藏

> 狀態：完成

## 內文

### 需求
建立凌晨、中午、傍晚、晚上四時段，玩家隨時可切换；提供可融入時段的拍貼收藏及獎勵，保留自由遊園與既有收藏規則。

### 問題—改動—驗收
問題：玩家想在園區自由選擇時段，也需要能收集不同時段的拍貼回憶。

改動：提供四個可選時段、相應拍貼收藏與一次性獎勵，並在收藏冊及成就中顯示進度。

驗收：玩家切換或重新進入遊戲後仍能查看四時段進度；重複取得不會重複領獎，原有收藏規則維持一致。

### 來源
2026-10-12 使用者要求：加大透視圈並考慮效果、NPC 避免遮擋且有個性動作、修正光影、自由切換四時段並融入拍貼或任務、小遊戲有時段布景。研究需超過五個來源，來源與已看過的截圖一同附票。

### 驗收條件
- [x] 至少六個來源比較日夜、自由切時與收藏機制，記錄採用理由。
- [x] 四時段可隨時選取，重開後已保存；未知存檔有安全回退。
- [x] 時段拍貼來源與獎勵清楚；重複領取不重複發獎，既有普通與惡魔收藏門檻不變。
- [x] 收藏冊可查看四時段收集狀態，完成後有遊戲內成就與平台接口。
- [x] 原生切時、重載、拍貼獎勵和收藏冊流程已檢查並有截圖；局部驗證通過。
- [x] 本機執行檔打包與成品驗收通過。

### 研究來源
已閱讀六個以上來源的文件文字；實際觀察及取捨記錄於[四時段與拍貼研究](../../design/runtime/time-of-day.md)。相關原始文件：[Animal Crossing: New Horizons 官方更新](https://www.nintendo.com/us/whatsnew/animal-crossing-new-horizons-free-update/)、[Dreamlight Valley Dapper Delights](https://disneydreamlightvalley.com/news/update-aug-21-2024)、[Dreamlight Valley Jungle Getaway](https://disneydreamlightvalley.com/fr/news/update-oct-9-2024)、[Minecraft Bedrock 時間命令](https://learn.microsoft.com/en-us/minecraft/creator/commands/commands/time?view=minecraft-bedrock-stable)、[Minecraft Bedrock 編輯器世界設定](https://learn.microsoft.com/en-us/minecraft/creator/documents/bedrockeditor/editorworldoptions?view=minecraft-bedrock-stable)、[Godot Environment](https://docs.godotengine.org/en/4.5/classes/class_environment.html)、[Godot DirectionalLight3D](https://docs.godotengine.org/en/4.2/classes/class_directionallight3d.html)、[Steamworks 成就與統計](https://partner.steamgames.com/doc/features/achievements?l=english&title=partner.steamgames.com)。只記錄已閱讀的文字，未宣稱看過更新影片。

原生驗收：四時段切換與重載、四階段成就、拍貼一次性獎勵、四格相簿縮圖適配，以及小遊戲模態暫停與恢復均通過。根工作階段已實際查看最新四格相簿圖，所有縮圖均完整顯示。

### 測試流程
1. 啟動獨立測試存檔，原生操作本票功能。
2. 檢查四時段、設定、重啟與不同視窗的相關行為。
3. 保存實際看過的截圖和短片，執行受影響局部驗證。

---

# 跟其他票的關係
- Blocks：無
- Blocked by：無
- Related：ART-13、MAIN-5、MAIN-6、MAIN-7

---

# 開始

固定基準：c8202d69779497456ee55ae1ca051d21f7952dec。分支：feature/island-first-park。

# Commit-1

### 問題
玩家缺少自由切換四時段和保存時段拍貼的入口。

### 改動
提供時段切換與海港拍貼收藏。

### 驗收
原生四時段按鈕、四格拍貼相簿、地點限制、單次20獎勵、成就、重載與模態暫停／恢復檢查通過。測試入口可由Godot --script實際執行。

### 測試結果
受影響的執行專案檢查19/19通過；Windows輸出以實際GPU檢查角色圖集、NPC活動、場景動畫與遮擋資源載入通過，無ERROR。

分支：feature/island-first-park。

### 截圖

[原生或研究證據：MAIN-9-album-postcards.png](images/MAIN-9-album-postcards.png)
[原生或研究證據：MAIN-9-postcard-dawn.png](images/MAIN-9-postcard-dawn.png)
[原生或研究證據：MAIN-9-postcard-dusk.png](images/MAIN-9-postcard-dusk.png)
[原生或研究證據：MAIN-9-postcard-night.png](images/MAIN-9-postcard-night.png)
[原生或研究證據：MAIN-9-postcard-noon.png](images/MAIN-9-postcard-noon.png)
[原生或研究證據：MAIN-9-time-dawn.png](images/MAIN-9-time-dawn.png)
[原生或研究證據：MAIN-9-time-dusk.png](images/MAIN-9-time-dusk.png)
[原生或研究證據：MAIN-9-time-night.png](images/MAIN-9-time-night.png)
[原生或研究證據：MAIN-9-time-noon.png](images/MAIN-9-time-noon.png)

### 程式與證據提交
分支：feature/island-first-park。更新至最新main後的本票提交：[52e1f3f](https://github.com/deadline314/Snapland/commit/52e1f3f7d28f6685278b561606abb7d59b09e680)。


# Commit-2 — 2026-10-20 獨立桌面成品與重開驗收

補齊本機成品：官方4.7.2 release範本產生Linux x86_64獨立執行檔，從只有成品的資料夾啟動。外部鍵鼠實際跳過開場、由碼頭步行到票票旁、切四時段並收集四張紀念拍貼；重點不重發獎，120→200幣、四時成就、普通與惡魔數仍0。

完整儲存退出後用新程序重開，收藏冊四時分頁及四張原圖都能開啟；存檔和全部四原圖／四縮圖SHA256保持相同。兩程序均exit0、0ERROR。最終成品修正舊打包冒煙對共用背景的假設後，另用第三個新程序以單擊打開收藏／四時／夜間原圖並正常退出；保存結果不變。

最終成品逐一畫出十二款專用場景，四背景／十六道具／八類植栽完整載入，角色、場景動畫及遮擋資源門檻保留。故意漏包背景圖的真正成品仍報缺圖退出1；錯誤版本範本及覆寫舊成品也被拒絕。四項受影響Godot回歸及104項Python回歸通過。本次是Linux Compatibility／軟體GPU與外部程式化輸入，不冒稱Windows EXE、真人試玩、硬體效能或聽感。

[六團隊研究與可重現成品流程](../../design/runtime/desktop-release-acceptance.md) · [來源／成品SHA與完整驗證範圍](images/MAIN-9-release-20261020-verification.json) · [實際成品十二款總覽](images/MAIN-9-release-20261020-art-twelve-overview.png) · [實際重開後四時收藏](images/MAIN-9-release-20261020-reader-04-time-album.png) · [最後成品夜間原圖](images/MAIN-9-release-20261020-final-08-night-original-single.png)。大型成品依流程可重建，未將219MB二進位塞入Git。
