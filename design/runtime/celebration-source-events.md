# 慶祝事件與既有動作來源

2026-11-02（Asia/Taipei），ART-17／ART-7。固定起始版本：`1a76480`。

## 玩家行為與來源邊界

成功結算後返回島嶼，主角以既有正面八格跳躍表達慶祝，完整播放起跳、騰空和落地後回待機。事件仍稱為慶祝，來源為跳躍；沒有新增原畫、額外方向或重複圖集。若未來具有有效的專用慶祝來源，優先使用專用來源；共享來源缺件時維持完整舊人物回退。

共用來源解析集中於世界的動作選擇，身體、衣料、髮型、帽子及附件都收到同一來源名稱、方向、格位和時間。結果頁僅透過既有關閉事件啟動視覺動作，不修改結算、碰撞、獎勵或存檔。暫停保持動作時間，換裝保留進度，移動取消定點動作，降低動態保留第一張完整站姿。

動作長度由已驗證的逐格停留時間總和決定，未指定停留時間則使用格數／幀率。無效來源回傳零長度，由世界套用既有安全預設與上限。沒有另建貼圖快取、複製 atlas 或預載未使用角色。

## 六方實際閱讀

本輪實際取得並閱讀下列文字；完整取回文字、網址與摘錄收在票附的重播資料包。沒有觀看來源影片，也沒有將參考素材放入遊戲。

| 團隊／方法 | 閱讀來源 | 本次採用的決策 |
|---|---|---|
| Aseprite | [Animation](https://www.aseprite.org/docs/animation/) | 來源 cels 與時間軸分開，重用現有完整姿勢，不把重用算新繪圖 |
| Esoteric Software／Spine | [Keys](https://esotericsoftware.com/spine-keys) | 區分離散附件／影格切換與骨架插值，本次保留離散原畫 |
| Godot | [2D sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html) | 使用同一動作時計選格，避免事件與渲染各自走時間 |
| Unity | [Sprite Swap introduction](https://docs.unity3d.com/Packages/com.unity.2d.animation@10.0/manual/SpriteSwapIntro.html) | 語意名稱解析到實際素材；共同骨架有前提，不任意套用到不同角色 |
| Universal LPC | [Character Generator README](https://raw.githubusercontent.com/liberatedpixelcup/Universal-LPC-Spritesheet-Character-Generator/master/README.md) | 保留真實動畫循環與來源覆蓋盤點，不增加不存在的方向 |
| Kenney | [Importing characters and animations](https://kenney.nl/knowledge-base/game-assets-3d/importing-characters-and-animations) | 動作 loop 與根位移需明確；本次慶祝單次播放，不推動物理角色 |

## 驗證界線

正常速度原生 fixture 使用真正的噴泉節拍輸入完成一局，關閉結算後觀察慶祝；互動姿勢本身由動作入口演練，沒有聲稱完成 NPC 任務。四分之一速度以合成結果頁只檢查動作，不作慢速玩法通關證據。兩者相機、初始站位及已讀教學為檢查 fixture。

觀察器在實際 frame_post_draw 記錄八格來源，核對當前外觀的身體與附件一致；影片為實際視窗錄製後轉成 H.264，慢放使用真實 Engine.time_scale=0.25，沒有把同一影片複製成慢速。實際檢視範圍為實際保存的原生截圖、來源格與影片解碼格；程式代操作不稱為真人遊玩，Dummy 不稱為人耳試聽，固定 30fps 不當作硬體效能測量。

局部測試涵蓋專用來源優先、共享來源缺失、完整八格、暫停／換裝／移動／降低動態，並驗證逐格停留時間和損壞時間資料。既有 172 格服飾合成與島上髮型生命週期亦回歸。完整主角／NPC 動作及服飾品質仍按 ART-17／18 原驗收逐項檢查。
