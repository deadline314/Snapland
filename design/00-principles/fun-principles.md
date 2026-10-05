# 先確認樂趣，再擴展樂園

更新：2026-10-06。來源是開發者經驗與官方玩法；以下應用是 Snapland 的設計假說，不能由銷量、數量或資料檢查推導玩家一定喜歡。

## 六個樂趣中心
| 中心 | 玩家體驗 | 設計要求 |
|---|---|---|
| 掌握 | 剛才差一點，這次我會了 | 控制與反應可預測，失誤原因可辨認 |
| 取捨 | 多貪一點還是先安全完成 | 安全與冒險都可通關，代價在決定前可讀 |
| 預測 | 我看出下一步了 | 規律可學，危險有預告，不用猜隱藏亂數 |
| 創意 | 原來也能這樣用 | 操作有第二用途、多解可成立、試錯可逆 |
| 協調 | 你接住，我去開門 | 共同物件、交接、支援，人人有決策 |
| 節奏 | 這一下很舒服也很好笑 | 音樂/燈光提示、準確聲畫回饋、短演出 |

每款一個主要中心、一個可選輔助中心；題材與框架服從操作。目錄必須写 action/goal/choice/feedback/variation/solo/multi/demon/variant/assist/test，不能只用「配送」「更快」「合作」代替設計。

## 設計與試玩分開驗收
1. 文件驗收：欄位完整、128 基本款編號唯一、集合與門檻可達、任務沒有循環。
2. 原型驗收：先關掉貨幣和收藏提示，以陌生玩家觀察理解、失誤、嘗試不同做法與主動重玩。
3. 試玩前不把128候選寫成128款證明好玩。自動驗證無法判斷手感、相似度、樂趣或原創性；人工檢查與實玩仍必要。
4. 各款玩家操作密度與同伴影響須可觀察；多職務不等於單人要同時按四個鍵。
5. 不強制同機分屏私密資訊，不依賴語音。聲音线索有字幕/形狀等價表達。

## 候選汰換規則
同一操作與決策只換題材，應合併候選，不增加款數。分類/排表若只有答案比對，可轉為非計數支線互動；被替換的候選在 revision-notes 留原編號與理由，當前game-id保持唯一。
小惡魔是核心操作第二用途；異空間改變決策或合作，不只加速、增加訂單或減少時間。

## 參考來源與應用
### wario — WarioWare Smooth Moves 開發者訪談
[原始來源](https://iwataasks.nintendo.com/interviews/wii/warioware_smooth_moves/0/1/)

來源內容：團隊討論迅速傳達操作與讓旁觀者也覺得有趣。

本案推導：短示範、即時反應與可讀喜劇。

### sports — Wii Sports 開發者訪談
[原始來源](https://iwataasks.nintendo.com/interviews/wii/wii_sports/0/0/)

來源內容：團隊以簡單且有深度的遊玩內容為方向。

本案推導：直覺控制的力度、方向與時機能漸進掌握。

### towerfall — TowerFall 設計者訪談
[原始來源](https://www.gamedeveloper.com/design/the-magic-of-i-towerfall-i-depth-simplicity-community)

來源內容：閃避逐步延伸為接箭與取消技巧。

本案推導：小惡魔条件揭露既有操作的第二用途。

### overcooked — Overcooked 創作者文章
[原始來源](https://blog.playstation.com/archive/2016/02/29/chaotic-co-op-cooking-game-overcooked-announced-for-ps4)

來源內容：分工、溝通與會改變協調方式的障礙是核心。

本案推導：共同物件、交接與救場，單人仍有有意義的操作。

### snipperclips — Snipperclips 官方玩法
[原始來源](https://media.nintendo.com/snipperclips/)

來源內容：形狀互動有多種解法，單人可切換角色。

本案推導：可逆試錯與多職務切換，避免多人必要同步。

### rhythm — Rhythm Heaven 開發者訪談
[原始來源](https://iwataasks.nintendo.com/interviews/ds/rhythm-heaven/0/0/)

來源內容：團隊以節奏感作為樂趣描述。

本案推導：預告、命中與聲畫回饋，以本機時間判定。

### assist — Overcooked All You Can Eat 輔助模式
[原始來源](https://blog.playstation.com/2020/07/20/overcooked-all-you-can-eat-is-a-visual-feast-for-ps5/)

來源內容：提供延長時限、放慢超時與跳關選項。

本案推導：輔助不剝奪收藏，先放寬時間與懲罰。

### steam_schema — Steam Inventory Schema
[原始來源](https://partner.steamgames.com/doc/features/inventory/schema)

來源內容：物品定義有 itemdefid/type/tradable/marketable 並支援自訂欄位。

本案推導：固定定義ID，收藏資格獨立於物品持有。

### steam_inventory — Steam Inventory Service
[原始來源](https://partner.steamgames.com/doc/features/inventory)

來源內容：無自建伺服器掉落方案不信任客戶端自行指定授予物品。

本案推導：離線收藏與可交易發放不同責任；P2P房主不等於可信任伺服器。

### steam_p2p — Steam Datagram Relay
[原始來源](https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay)

來源內容：Steam P2P API 可使用 Valve 中繼。

本案推導：不必部署專用遊戲伺服器，仍有房主模擬與中斷處理。


## 試玩紀錄要求
每次記模式、座位數、AI等級、是否輔助、失誤原因、玩家用過的方法、是否自發重玩、觀察者干預。只通過文件檢查不填遊戲試玩通過；六款原型通過後才拆Godot實作票。

