# 潮汐紙劇場美術與介面交付追蹤

本頁彙整 ART-3 至 ART-18、MAIN-8、MAIN-9、SG-14、SG-15 的程式提交與原生檢查。二十張票目前仍為「進行中」；下表只標記已由局部測試或原生檢查支持的條件，不把自動化截圖說成玩家試玩，也不把尚未完成的全動畫／人工檢查寫成通過。

## 交付與畫面

| 票 | 結果與待辦 | 程式提交 | 原生畫面 |
| --- | --- | --- | --- |
| ART-3 海港布景 | 四方向移動、九區入口、日夜與降低動態檢查通過。 | [d886ba7](https://github.com/deadline314/Snapland/commit/d886ba74574c7a45c0bb233512adfb3e662baa08) | [碼頭](Snapland-art/images/ART-3-dock.png) · [日景](Snapland-art/images/ART-3-day.png) · [夜景](Snapland-art/images/ART-3-night.png) · [入口](Snapland-art/images/ART-3-gate-harbor.png) |
| ART-4 角色與遊園動作 | 角色身份及全身 fixture 已查驗。四種 named action 各有一張正面姿勢圖，不代表動畫完成；「不滑步」仍待 ART-14／ART-16。 | [9b3aa65](https://github.com/deadline314/Snapland/commit/9b3aa654d9b02bff17a819a3280addd5ef980f7e) | [小角近景](Snapland-art/images/ART-4-kaku-portrait.png) · [票票近景](Snapland-art/images/ART-4-ticket-portrait.png) · [主角全身待機](Snapland-art/images/ART-15-sprite-clearance-avatar-idle-front.png) · [招手姿勢](Snapland-art/images/ART-15-sprite-clearance-avatar-wave.png) |
| ART-5 十二款小遊戲美術 | 十二款原生自動輸入路線和成功結果檢查通過；並非玩家試玩。 | [53a9dc3](https://github.com/deadline314/Snapland/commit/53a9dc3e15be759e647209c623aaef72c61918f0) | [遊戲 01](Snapland-art/images/ART-5-game-01.png) · [結果 01](Snapland-art/images/ART-5-result-01.png) · [遊戲 05](Snapland-art/images/ART-5-game-05.png) · [結果 05](Snapland-art/images/ART-5-result-05.png) · [遊戲 09](Snapland-art/images/ART-5-game-09.png) · [結果 09](Snapland-art/images/ART-5-result-09.png) |
| ART-6 遊園介面 | layout-v4 在 800×600 與 1280×720 核對衣櫃／設定模態控制範圍及鍵鼠回應 PASS，根任務檢視兩張 800 截圖。 | [7e7f0ff](https://github.com/deadline314/Snapland/commit/7e7f0ff9650c813b9ec67ef8f47dd8e78ed7bf9c) | [HUD](Snapland-art/images/ART-6-hud.png) · [遊戲資訊](Snapland-art/images/ART-6-game-info.png) · [結果](Snapland-art/images/ART-6-result.png) · [收藏冊](Snapland-art/images/ART-6-album.png) · [設定 1280](Snapland-art/images/ART-6-settings.png) · [設定 800](Snapland-art/images/ART-6-settings-800.png) |
| ART-7 像素角色動作 | 27 個全身 fixture 靜態視角通過；四種 action 是單張姿勢，服飾暫為換色、不是完整圖層。動畫品質由 ART-16／17、服裝層由 ART-18 跟進；輸出版本已通過資源載入冒煙檢查，完整動作播放仍未驗收。 | [02ac052](https://github.com/deadline314/Snapland/commit/02ac052d402584fa3dc2e9a4371ed7616faa4ffd) | [角色](Snapland-art/images/ART-7-character-approved.png) · [主角全身待機](Snapland-art/images/ART-15-sprite-clearance-avatar-idle-front.png) · [招手姿勢](Snapland-art/images/ART-15-sprite-clearance-avatar-wave.png) · [行走影片](Snapland-art/images/ART-7-walk-preview.mp4) |
| ART-8 衣櫃與服飾店 | layout-v4 原生輸入與控制範圍在 800×600、1280×720 PASS；根任務檢視兩張 800 截圖。 | [f2d68bb](https://github.com/deadline314/Snapland/commit/f2d68bb030ad19e766c0fb55bb484c60fc87f3da) | [衣櫃 800](Snapland-art/images/ART-8-layout-800.png) · [設定 800](Snapland-art/images/ART-6-settings-800.png) · [1280 視窗](Snapland-art/images/ART-8-layout-1280.png) |
| ART-9 部件動畫 | 19/19 runtime check PASS，含元件動畫；原生角色 fixture 27 視角檢查通過，但不代表全角色 idle set 或服裝動畫。既有部件短片已審閱、輸出資源載入通過；完整角色待機與服裝動畫尚未完成。 | [fb0ba75](https://github.com/deadline314/Snapland/commit/fb0ba7566ebe5820662fce4c4ce6b54b58c931b5) | [旗幟](Snapland-art/images/ART-9-flag-01.png) · [植栽](Snapland-art/images/ART-9-foliage-01.png) · [角色待機靜態姿勢](Snapland-art/images/ART-15-sprite-clearance-avatar-idle-front.png) · [NPC 降低動態姿勢](Snapland-art/images/ART-15-sprite-clearance-npc-imp-reduced.png) |
| ART-10 建築遮擋 | 三組遮擋情境、日夜、降低動態、1600×900 resize 與退出遮擋檢查通過；既有遮擋短片已審閱、輸出資源載入通過；完整輸出情境仍待檢查。情境位置是審查設置，不是玩家操作路線。 | [63f423d](https://github.com/deadline314/Snapland/commit/63f423dfcabc62ede8a09ddb85e30d53165e27ad) | [日景遮擋](Snapland-art/images/ART-10-cutaway-day.png) · [夜景](Snapland-art/images/ART-10-cutaway-night.png) · [降低動態](Snapland-art/images/ART-10-cutaway-reduced-motion.png) · [改尺寸](Snapland-art/images/ART-10-arch-cutaway-resized-equipped.png) |
| ART-11 擴大透視圈 | 六個以上文字來源研究完成；更新大圈在原生 GPU 的日夜、降低動態、尺寸變更與恢復檢查通過。完整短片與輸出情境仍待驗收。 | [b90ecb2](https://github.com/deadline314/Snapland/commit/b90ecb22684d65d071edc0f31b27ddff2ca41102) | [擴大透視圈](Snapland-art/images/ART-11-arch-cutaway-day.png) · [研究](../design/runtime/occlusion.md)。 |
| ART-12 NPC 站位與動作 | 三位角色四格活動、降低動態／模態暫停同步、稱呼與互動位置跟隨已檢查；ART-15 已修正腳底接地與售票員鞋尖遮擋；完整個性動畫集與短片仍待 ART-17。 | [449c328](https://github.com/deadline314/Snapland/commit/449c328b6bd41116b15e190b96ea90a0935d4539) | [售票員](Snapland-art/images/ART-12-ticket-01.png) · [報幕員](Snapland-art/images/ART-12-announcer-01.png) · [小惡魔](Snapland-art/images/ART-12-imp-01.png) · [NPC 研究](../design/runtime/npc-activity.md) |
| ART-13 四時段光影與遊戲布景 | 十二款小遊戲四時段共 48 張原生圖已保存，根工作階段檢視三張接觸表與園區四時段。燈光方向限向下；紙景與部分 sprite 的預繪明暗不代表全場物理受光。 | [e61dd4a](https://github.com/deadline314/Snapland/commit/e61dd4ab4f228853df43f449b0bcb7dcb8623d1e) | [園區凌晨](Snapland-art/images/ART-13-world-dawn.png) · [正午](Snapland-art/images/ART-13-world-noon.png) · [傍晚](Snapland-art/images/ART-13-world-dusk.png) · [夜間](Snapland-art/images/ART-13-world-night.png) · [遊戲 01 凌晨](Snapland-art/images/ART-13-game01-dawn.png) · [遊戲 12 夜間](Snapland-art/images/ART-13-game12-night.png) · [光影研究](../design/runtime/daylight-lighting.md) |
| ART-14 八方向步行與換裝 | 八方向錄影、64 姿勢及 24×3 部件方向圖由根工作階段檢視；來源 PNG 釐清第 6／7 格切片並修正 JSON 區域。腳步自然度與更高動作品質仍待 ART-16。 | [209d95f](https://github.com/deadline314/Snapland/commit/209d95fb5ad0d9c24d6f6213b726efaa9988db43) | [八方向走路錄影](Snapland-art/images/ART-14-eight-direction-walk.mp4) · [64 姿勢圖庫](Snapland-art/images/ART-14-gallery-poses-front.png) · [髮型](Snapland-art/images/ART-14-gallery-hair.png) · [帽子](Snapland-art/images/ART-14-gallery-hat.png) · [種族部件](Snapland-art/images/ART-14-gallery-species.png) · [步態研究](../design/runtime/animation-quality.md) |
| ART-15 角色裁切與完整性檢查 | 原生 27 個全身 fixture 視角檢查 PASS，包含三位 NPC 多姿勢及降低動態畫格、主角八方向待機與四個靜態姿勢。售票員完整鞋尖已重新檢視；這不代表完整待機或步態品質通過。輸出資源載入已通過，輸出全部姿勢仍待驗收。 | [95a2d02](https://github.com/deadline314/Snapland/commit/95a2d027e8743f71acabe0f369dc2d0ffb3e5943) | [主角待機](Snapland-art/images/ART-15-sprite-clearance-avatar-idle-front.png) · [行走姿勢](Snapland-art/images/ART-15-sprite-clearance-avatar-walk-front_right-5-of-8.png) · [招手姿勢](Snapland-art/images/ART-15-sprite-clearance-avatar-wave.png) · [NPC 售票員](Snapland-art/images/ART-15-sprite-clearance-npc-ticket-first.png) · [小角降低動態](Snapland-art/images/ART-15-sprite-clearance-npc-imp-reduced.png) |
| ART-16 動畫流暢與一致性 | 已支援依素材實際格數播放八／十六格，但目前沒有合格十六格素材。使用者拒絕的 rig 已撤回；27 個靜態視角不替代動作品質驗收。 | [12a7aa8](https://github.com/deadline314/Snapland/commit/12a7aa8072fdd075a3c31c9de411136dbb3e7366) | [已撤回 rig 參考圖](Snapland-art/images/ART-16-rejected-rig.png) · [高動態試作 01](Snapland-art/images/ART-16-rejected-pilot-01.png) · [高動態試作 02](Snapland-art/images/ART-16-rejected-pilot-02.png) |
| ART-17 完整角色動畫與個性待機 | 完成八方研究、三張參考截圖及逐角色覆蓋需求。角色四種動作目前各只有一張正面姿勢；完整動作與獨立待機尚未交付。 | [196b2b5](https://github.com/deadline314/Snapland/commit/196b2b586af2f15cd0c79a406833fb3ebfe000c5) | [招手姿勢](Snapland-art/images/ART-15-sprite-clearance-avatar-wave.png) · [拍照姿勢](Snapland-art/images/ART-15-sprite-clearance-avatar-photograph.png) · [慶祝姿勢](Snapland-art/images/ART-15-sprite-clearance-avatar-celebrate.png) |
| ART-18 換裝分層與角色動畫同步 | 完成八方研究及分層共用時序、逐格定位與遮擋設計。現有服裝仍以換色為主，完整輪廓與分層同步未完成。 | [3f87c63](https://github.com/deadline314/Snapland/commit/3f87c63ff57b93ae451276657651a0d6e922d8bb) | [研究與覆蓋需求](../design/runtime/character-animation-wardrobe.md) · [Aseprite](Snapland-art/images/ART-18-reference-aseprite-layers.png) · [Spine](Snapland-art/images/ART-18-reference-spine-mix-match.png) · [LPC](Snapland-art/images/ART-18-reference-lpc-generator.png) |
| MAIN-8 外觀與服飾收藏 | 隔離存檔局部及原生流程涵蓋舊／未知資料、購買、穿戴、取消與重新載入，檢查通過。 | [ca10308](https://github.com/deadline314/Snapland/commit/ca103086e16cf5d36d23ca114ba4c6fe1e1e0456) | [衣櫃原生截圖](Snapland-main/images/MAIN-8-wardrobe.png) |
| MAIN-9 四時段與拍貼收藏 | 四時段切換／重載、四階段成就、單次拍貼獎勵、四格相簿縮圖、小遊戲模態暫停與恢復原生檢查通過；Windows 輸出資源載入已通過實際 GPU 檢查；輸出完整互動流程仍待驗收。 | [52e1f3f](https://github.com/deadline314/Snapland/commit/52e1f3f7d28f6685278b561606abb7d59b09e680) | [凌晨](Snapland-main/images/MAIN-9-time-dawn.png) · [正午](Snapland-main/images/MAIN-9-time-noon.png) · [傍晚](Snapland-main/images/MAIN-9-time-dusk.png) · [夜間](Snapland-main/images/MAIN-9-time-night.png) · [四格相簿](Snapland-main/images/MAIN-9-album-postcards.png) · [時段拍貼研究](../design/runtime/time-of-day.md) |
| SG-14 十二款動作回饋 | 局部測試與十二款原生自動輸入／結果路線檢查通過；不代表真人遊玩。 | [c5195a0](https://github.com/deadline314/Snapland/commit/c5195a099d8f29063ef6246ed9cd559c0c576c22) | [遊戲 01](Snapland-art/images/ART-5-game-01.png) · [結果 01](Snapland-art/images/ART-5-result-01.png) · [成就解鎖](Snapland-small-game/images/SG-14-achievements-unlocked.png) |
| SG-15 氣球快遞 | 滑鼠無失誤達惡魔結果；WASD 輔助與降低動態以 450 分、零失誤完成惡魔結果。輔助／打包的其餘驗收仍待完成。 | [9b45af9](https://github.com/deadline314/Snapland/commit/9b45af90c0a2fcc9880bd93735b03d2a3edf30fd) | [引導](Snapland-small-game/images/SG-15-intro.png) · [風場](Snapland-small-game/images/SG-15-wind.png) · [普通結果](Snapland-small-game/images/SG-15-result-ordinary.png) · [惡魔結果](Snapland-small-game/images/SG-15-result-devil.png) |

表列程式、研究與證據均已逐票提交於 `feature/island-first-park`；票券登記已在 main。更新至最新 main 後，提交連結已改為有效的新 SHA，固定開始基準保留原記錄。提交不代表未完成的動畫或人工驗收已通過。

ART-5／SG-14 全十二款原生畫面及成功結果：

- 01 [遊戲](Snapland-art/images/ART-5-game-01.png)／[結果](Snapland-art/images/ART-5-result-01.png) · 02 [遊戲](Snapland-art/images/ART-5-game-02.png)／[結果](Snapland-art/images/ART-5-result-02.png) · 03 [遊戲](Snapland-art/images/ART-5-game-03.png)／[結果](Snapland-art/images/ART-5-result-03.png)／04 [遊戲](Snapland-art/images/ART-5-game-04.png)／[結果](Snapland-art/images/ART-5-result-04.png)
- 05 [遊戲](Snapland-art/images/ART-5-game-05.png)／[結果](Snapland-art/images/ART-5-result-05.png) · 06 [遊戲](Snapland-art/images/ART-5-game-06.png)／[結果](Snapland-art/images/ART-5-result-06.png) · 07 [遊戲](Snapland-art/images/ART-5-game-07.png)／[結果](Snapland-art/images/ART-5-result-07.png) · 08 [遊戲](Snapland-art/images/ART-5-game-08.png)／[結果](Snapland-art/images/ART-5-result-08.png)
- 09 [遊戲](Snapland-art/images/ART-5-game-09.png)／[結果](Snapland-art/images/ART-5-result-09.png) · 10 [遊戲](Snapland-art/images/ART-5-game-10.png)／[結果](Snapland-art/images/ART-5-result-10.png) · 11 [遊戲](Snapland-art/images/ART-5-game-11.png)／[結果](Snapland-art/images/ART-5-result-11.png) · 12 [遊戲](Snapland-art/images/ART-5-game-12.png)／[結果](Snapland-art/images/ART-5-result-12.png)

## 驗證紀錄

| 範圍 | 結果 | 邊界 |
| --- | --- | --- |
| Runtime 局部與整合 | 乾淨 checkout 的 `runtime-clean-polish.log` 為 19/19 項 PASS，含角色八方向行走、時段、日光、NPC 活動、裁切、衣櫃 UI、元件動畫、遮擋、小遊戲、故事、音訊與主場景整合。 | 這是程式驗證，不是遊戲試玩；輸出資源冒煙通過不等於輸出完整互動通過。 |
| 原生全遊戲與衣櫃 | 十二款遊戲原生自動輸入／結果、園區成就、服飾免費外觀、試穿、購買、穿戴、取消與重載流程 PASS。 | 自動輸入用於功能驗收，不推論真人體驗或難度平衡。 |
| 氣球快遞 | 滑鼠無失誤惡魔結果；WASD 輔助與降低動態惡魔結果 450 分、零失誤 PASS，根任務已檢視錄影。 | 使用審查用輸入路徑，不等於玩家試玩。 |
| 角色全身視角 | `clearance-native-v5.log` 原生 27 個 fixture 視角 PASS：三位 NPC 多格（含降低動態／還原）與主角八方向待機、行走／拍照／招手／慶祝姿勢。主 Session 查看全身比例並在最終版本確認售票員左右鞋尖完整。 | 靜態 pose/framing fixture；不代表 16 個素材全都可用、不代表完整 idle set、也不是玩家試玩。新 rig 已由使用者拒絕並撤回，ART-16 高動態品質仍 pending。 |
| 介面視窗與輸入 | `layout-v4.log` 原生 800×600、1280×720 視窗控制範圍、衣櫃／設定鍵鼠回應 PASS；根任務查看兩張 800 截圖。 | 只對核對頁面與尺寸作結論，不推及其他畫面。 |
| 氣氛與遮擋 | 三組遮擋情境、日夜、降低動態、1600×900 resize、退出後恢復 PASS。 | 固定情境座標是審查布置，不代表自然遊玩路線。 |
| 原生靜態畫面 | 已保存表列 PNG；根任務另檢視全十二款遊戲／結果組、九區入口組、角色身份近景、HUD／設定代表圖、ART-12 三角色、ART-13 四時段與 12×4 小遊戲接觸表、ART-14 八方向步態／部件圖庫、MAIN-9 四格相簿及 clearance 頭部／全身比例。 | 每張 PNG 只證明該時刻畫面；截圖不等於影片審閱或玩家體驗。 |

## 設計研究依據

這些研究只用來形成取捨，不把參考作品素材直接挪作 Snapland 美術，也不把來源閱讀說成遊戲驗收。ART-11、12、13、14、17、18 與 MAIN-9 各自列有六個以上實際文件連結及觀察理由，詳見對應研究筆記與票內「研究來源」。

| 研究筆記 | 實際觀察與本批採用方向 |
| --- | --- |
| [視覺層次與可讀性](../design/runtime/visual-polish.md) | Nintendo《Yoshi's Crafted World》官方素材呈現可辨材質與紙藝層次；《Octopath Traveler II》官方訪談及畫面顯示前後景和光照共同塑造港口氛圍。採用層次與海港色彩，不沿用素材。 |
| [Godot 與執行環境](../design/runtime/core-research.md) | 查閱 Godot 4.7 文件與 4.7.2 版本資訊，確認專案啟動、資源載入及隔離存檔驗證的依據。 |
| [角色與衣櫃研究](../design/runtime/wardrobe.md) | 查閱 Nintendo《Animal Crossing: New Horizons》官方鏡子外觀說明及 Disney Dreamlight Valley 衣櫃更新；採用可返回的免費外觀與分類預覽，不複製角色或介面。 |
| [部件動畫研究](../design/runtime/component-animation.md) | 七個來源涵蓋 Godot 動畫、共享 shader 參數、Unity 骨架、Fortnite 植栽、Dead Cells 像素動作、Aseprite 標籤和動態可及性；據此分開材質節奏並提供降低動態。 |
| [完整角色動畫與換裝分層](../design/runtime/character-animation-wardrobe.md) | 八方一手資料比較逐幀分層、骨架換件與 3D 烘焙；實際核對 Aseprite、Spine、LPC 三張參考截圖。採完整姿勢與分層服飾共用時序、逐格定位及前後遮擋，次級動態限髮尾／衣襬／帶子；逐角色完整動作仍是需求。 |
| [建築遮擋研究](../design/runtime/occlusion.md) | 六個來源比較局部揭露、透明淡出、射線與鏡頭避障；採用角色周圍圓形辨識窗，並只在實際遮擋時顯示。 |
| [氣球快遞操控研究](../design/runtime/balloon-delivery.md) | 六個來源包含 Nintendo Land、Mario Golf 手冊、LostWinds 訪談等；採用明確風向與風力訊號、逐步引導與不同輸入方式。GDC 講座僅按摘要研究，未宣稱完整觀看。 |

## 尚待處理

- 二十張票維持「進行中」。表列局部通過項目已有證據；完整輸出互動、指定完整動作短片、真人操作感受及音訊試聽未全部通過，不升為審查中。
- ART-11 大圈已在原生 GPU 重新檢查；ART-15 已修正接地與售票員鞋尖。靜態全身圖不證明步態自然，ART-16 仍需真正合格的動作素材。
- ART-17 每位角色的独立站姿、呼吸／眨眼、低頻待機及完整互動動作尚未製作；ART-18 完整服裝輪廓、逐格分層與同步尚未完成。研究及需求已提交，不把單張姿勢、換色、短活動循環當成完整動畫。
- ART-13 紙景與 sprite 的部分預繪明暗限制詳見 `daylight-lighting.md`；四時段畫面不證明所有紙質 sprite 都接受完整物理光照。
- 遠端全域設計检查仍有既有 `design/02-minigames/catalog.json` 缺失，本批未停用 CI 或略過檢查。

## 最新穩定性與範圍

- 實際GPU全身fixture27張；售票員移離草地／抬高步道交界後，主 Session 再次確認完整鞋尖。
- Windows輸出以Intel Arc B580實際GPU啟動，角色圖集、NPC動作、部件動畫、遮擋及12款小遊戲所需素材載入通過，無ERROR。此為打包冒煙檢查，不是全動作或真人試玩。
- 完整動作、獨立站姿／待機、服裝輪廓與同步分層仍由ART-16／17／18追蹤，未把單張姿勢、換色或短活動循環算成完整動畫。
- 先前不合格的拆件骨架試作已退出遊戲，僅保留失敗證據。
- 新增時段、動作與接地需在現有共用世界／入口接合；本批修改 game/world/park_world.gd、game/main.gd、game/core/progress.gd、game/minigames/session.gd 及實際執行檢查註冊，均為與本組功能相接的最小範圍，未修改其他小遊戲設計目錄。
- 遠端完整設計檢查目前還有既有 design/02-minigames/catalog.json 缺失；已提交先前漏掉的木材／草地材質，沒有停用CI或略過檢查。

## 最新檢查與預覽包

- 由已提交版本建立全新 checkout，實際執行 19/19 runtime 檢查通過；更新至 main 後另重跑步行、角色完整性與主場景整合均通過。所有流程使用隔離存檔。
- 主場景整合曾以額外的預設 headless 後端執行，測試斷言通過但退出出現資源殘留訊息，因此不記為乾淨通過。按正式 runner 的 Dummy 音訊／gl_compatibility 參數重跑，退出為 0 且無 ERROR／WARNING；原生 GPU 輸出冒煙也無錯誤。
- Windows 預覽包：`build/Snapland-polish-preview-20261012.zip`，約 69.7 MiB，共七個檔案；ZIP 完整性檢查通過。來源提交 `0a302d926cf910a71be5cd058f9d93e425f7035b`，本次後續提交只有票內連結與交付紀錄，不改變遊戲內容。
- ZIP SHA-256：`4e1de975947cd292a519ab5c01a8e24153e3e1aa5393d67d7c78c449e0ad430f`。包內附啟動檔、操作說明、來源紀錄與授權，存檔放在獨立預覽目錄。這是目前穩定預覽，完整角色動畫仍未完成。
