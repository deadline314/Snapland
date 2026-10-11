# 園區與介面研究

研究日期 2026-10-11；在畫面實作前完成閱讀。

## 已讀來源與實際觀察

1. [Octopath Traveler 官方開發訪談](https://www.unrealengine.com/spotlights/octopath-traveler-s-hd-2d-art-style-and-story-make-for-a-jrpg-dream-come-true)：作者訪問 Acquire；美術描述 PS1 時代角色疊在 3D／預渲染背景的啟發，並指出添加效果點光源產生環境投影。已實際查看 Haanit 戰鬥截圖：像素角色、立體石台、霧與遠景樹林，亮部指引注意力。採用正交立體場景、最近鄰人物與分層燈光，不複製原作像素或人物。截圖 ART-1-reference-octopath.jpg。
2. [Godot 3D introduction](https://docs.godotengine.org/en/stable/tutorials/3d/introduction_to_3d.html)：固定相機與 Sprite3D／AnimatedSprite3D 可結合3D背景與光影；本作採實際 3D 而非平面插圖冒充HD-2D。
3. [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/full-list/)：實際讀到 basic 提供可重映射輸入、按玩家步調前進的文字、清楚文字／對比與調整速度；intermediate 包含分開音量與降低背景動態。採用可跳過對話、鍵盤焦點、三種音量與降低動態，不讓視覺特效蓋過操作提示。第一版尚未實作按鍵重映射，不能宣稱符合全部指南。
4. [Super Mario Party minigames 官方展示](https://media.nintendo.com/supermarioparty/minigames/)：以獨立遊戲介紹呈現玩法與模式；採用設施名稱、短指令與開始前明示小惡魔目標。
5. [Overcooked 輔助模式官方說明](https://blog.playstation.com/2020/07/20/overcooked-all-you-can-eat-is-a-visual-feast-for-ps5/)：提供延長時間與放慢超時。採用首次遊玩即可開輔助，保持收藏資格。

## 與玩家喜好資料的界線

官方開發者說明是方法參考，並非本作玩家研究。搜尋出現 WarioWare 玩家討論中對操作不直覺／動作偵測不準的負面回饋，但本輪不以小樣本聲稱全體玩家偏好。對可玩性仍需真人後續試玩。

## 原創素材

程序生成像素角色、低面數海島、園區設施、地面與水 shader 為本專案原創；研究圖限 pm 審閱，不納入 export 資產。
