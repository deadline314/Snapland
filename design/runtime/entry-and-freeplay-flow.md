# 攤位與自由探索：減少入口阻力

2026-10-20（Asia/Taipei）；基準 `244536b`，追蹤 MAIN-14／21、ART-20。

## 本次先讀的六個方向

以下為實際閱讀的文字；圖片另依證據紀錄，沒有把搜尋摘要、影片連結或失敗下載當成完整影片／圖片審閱。

| 來源 | 觀察與採用理由 | 不採用／界線 |
|---|---|---|
| [Nintendo：WarioWare 操作提示](https://play.nintendo.com/news-tips/tips-tricks/warioware-microgames-quick-tips/) | 選遊戲後可查看詳細說明，Play-o-pedia 另供重玩與練習。保留簡短邀請、按需規則與不影響收藏的練習。 | 不引入花金幣續命。 |
| [NN/g：Progressive Disclosure](https://www.nngroup.com/articles/progressive-disclosure/) | 常用動作先顯示，次要選項有清楚入口；次頁也要好返回。減少長駐數字和多層卡框。 | 本遊戲沒有玩家研究統計，不據此宣稱所有人更喜歡。 |
| [Godot：InputEvent](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) | GUI 與未處理事件有明確順序。驗收必須派送真實輸入並檢查目的控制項，不只發出按鈕訊號。 | 不讓教學輸入穿透園區或回合。 |
| [inkle：Getting Started](https://www.inklestudios.com/inklewriter/getting-started/) | 初次可選教學或直接開始；重看不應破壞原本工作。普通與輔助入口共用可取消／略過的首次教學。 | 這是編輯器案例，不據此推論遊戲手感。 |
| [Ren'Py：Text](https://www.renpy.org/doc/html/text.html#slow-text-concerns) | 逐字文字的行距和實際溢出需檢查；完整文字、顯示進度與輸入是分開的狀態。教學與對話皆驗看實際文字及焦點。 | 不更換引擎，不把字體數值當可讀性保證。 |
| [A Short Hike：介面圖集](https://interfaceingame.com/games/a-short-hike/) | 頁面將互動、對話、商店與探索分別列出；採用情境單一主要動作，詳細進度移到旅券。 | 圖片下載回傳 403，未重試；未宣稱本次在本機看過該兩張圖。 |

本機重新查看既有 Nintendo 官方頁面擷取 [Mario Party 圖例](../../pm/Snapland-art/images/ART-21-ref-mario-party.png)：實際遊戲畫面與簡短目標並置。也重新看過使用者否定的 [捲動式暫停反例](../../pm/Snapland-main/images/MAIN-20-user-rejected-scroll-pause.jpg)：不恢復小窗、大卡、按鈕被捲出畫面的布局。這兩張是既有圖，不冒充本次新下載。

## 自由互動的六方比較

| 第一方來源 | 實際讀到的範圍與選擇 |
|---|---|
| [Nintendo：Animal Crossing 日夜／花園](https://play.nintendo.com/news-tips/tips-tricks/animal-crossing-new-horizons-tips-tricks/) | 日夜有不同可發現內容，花園的照料有環境結果。採用閘門影響水流和場景，不把每次互動都綁獎勵。 |
| [House House：Untitled Goose Game](https://untitled.goose.game/) | 官方頁確認以村莊與鵝為中心的日常場景，另有官方截圖／媒體包。只取在世界裡直接行動的方向，未觀看完整玩法影片。 |
| [Adam Robinson-Yu：A Short Hike](https://ashorthike.com/) | 沿標示路線或探索旁路，遇見旅人、發現細節。自由物件安排於已可走海岸，不另外堆一排選單。 |
| [Team ASOBI：Astro Bot](https://www.playstation.com/en-us/games/astro-bot/) | 官方介紹不同能力改變探索、道具帶出角色演出。採取操作後可見的物件回應，不複製角色或宣稱具備硬體觸覺。 |
| [Ben Esposito：Donut County](https://www.donutcounty.com/) | 官方定位為物理與敘事結合。小物件的方向、動量和結果比多一個進度條更適合自由玩。 |
| [Godot：RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html) | 用衝量讓物件自然受力、碰撞，避免每幀直接改剛體位置；暫停和收回需獨立處理。 |

Nintendo explore 頁回傳 502，LEGO 候選頁不可讀，沒有採為本次證據。Astro 頁只讀文字與圖片連結，未宣稱完整影片檢視。額外 Godot 輸入流程圖下載也回傳 403，未重試。

## 已確認的入口問題

原本一般開始會檢查首次教學，但「玩法與選項 → 輔助挑戰」直接開始回合。先補反例，原版確實失敗，再讓輔助入口共用首次判定。取消教學不記已讀、不發獎；略過或開始後保持所選輔助模式。既有回歸保留全部原斷言，追加輔助首次、取消與略過路徑。

## 自由遊玩的範圍

海岸先做三種可以直接玩的物件：可控制方向的海漂球、依玩家節奏敲響並擺動的潮鐘、可開關水流並影響轉速的水閘。不另開計分畫面，不發拍貼、金幣或任務獎勵。場景物件用可見形狀和附近的一句操作提示呈現，保留玩家隨時走開的自由。

這是已開放海岸的小批品質標準；其他九區仍是未開放入口，不能在本票宣稱每張地圖已填滿內容。


## 乘坐設施的完整結果

MAIN-15 最後核對發現舊動作只繞 0.6 圈便回程，改為十二秒完整一圈。回歸量測實際座位在四分之一、半圈及接近完成時的相對位置，再核對自然退出；只測「角度有變」無法抓到少轉一段。兩個可見木棧台燈具各綁真正局部光源，加入最近八盞／最多兩盞影子限制；日間關閉、夜間檢查實際能量及照明畫面。原生從碼頭實際走 18.49 公尺、日夜完整乘坐與重訪退出通過，實際證據和限制見本票。
