# 自由外觀與海港衣櫃

本批 MAIN-8、ART-7、ART-8 的固定起點為 `4c320b9d6eef219d5ea90a9b96cb09ad7a68b3a5`。使用者兩張肯定的像素素材均保留；以新版不對稱眉眼、風向髮束、相機與袖口補丁提高辨識度，沿用原有海港配色。

## 實際查閱的例子

- [Nintendo 外觀更換支援說明](https://www.nintendo.com/en-gb/Support/Purchases-Subscriptions/Games/Can-I-Change-My-Character-s-Appearance-Animal-Crossing-New-Horizons--1747981.html)：頁面明確說鏡子與梳妝台可隨時更換外觀；沒有列出本文全部身份欄位或宣稱免費，免費無限修改是本作使用者需求。
- [Disney Dreamlight Valley 官方更新](https://disneydreamlightvalley.com/ja/news/update-aug-21-2024)：實際閱讀衣櫃分類、整套預設、新物品標記，以及兩種全身拍照姿勢的更新條目。本批先做分類與即時試穿，整套預設不列成本批已交付。
- [Splatoon 開發者訪談](https://www.nintendo.com/en-gb/Iwata-Asks/Iwata-Asks-Splatoon/Splatoon/4-Gaining-Momentum/4-Gaining-Momentum-1021371.html)：實際閱讀角色行為、世界概念與服飾設計一致的討論。本作從海港旅行、攝影與老遊樂園出發，不沿用其造型。
- 提示詞研究與完整讀到的內容見 [美術提示詞指南](art-prompt-guide.md)。以上頁面研究不等於其遊戲試玩。

## 本批玩家行為

基礎外觀含膚色、種族、性別、髮型、髮色與表情。全部免費無限修改；性別不限制服裝，性別欄位是玩家身份；造型由髮型、臉部、種族與穿搭各自決定，不強制分配男女髮型或版型。玩家初始有 120 枚海島幣，迎賓大道每款首次通關得 40 枚；同一款重玩不重複領首次獎勵。貨幣與衣櫃只用離線收藏，沒有交易或真金購買。

衣櫃分免費外觀、已收藏與服飾店。試穿修改草稿；取消保留原穿搭。購買成功才扣款，穿戴只接受已擁有服飾。第一批外套為海港外套不同配色，帽子為可獨立穿戴的草帽、水手帽與花飾。保持固定物品定義，後续增加版型以資料與素材擴充。

## 動作與素材

主角改用有眉眼、袖口、鞋底與相機細節的像素動作素材，四方向待機及兩個實際不同步態；另有招呼、拍照、互動與慶祝姿勢。圖片生成只提供來源候選，需逐格檢視、遊戲畫面與打包驗收才能採用；不以提示中的解析度數字當作素材已達標。

渲染以有界快取合成角色、服飾配色與帽子。動態光影仍由島上實際燈光處理。改外觀不改移動速度或碰撞。所有原生測試使用獨立存檔。


## 跨方向製作參考補充

- [Godot AnimationTree 官方文件](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)：實際閱讀狀態與動作過渡的職責；本批小規模角色用明確姿勢狀態，後續部件共用姿勢同步，不為每件衣服建立獨立時間。
- [Aseprite 官方動畫標籤文件](https://www.aseprite.org/docs/tags/)：實際讀到以名稱標記影格範圍；借鑑四方向、步態與特殊動作的命名和固定排列，換裝跟隨同一個動作索引。
- [Dead Cells 美術作者的流程分享](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-)：實際讀到關鍵姿勢與可修改的動畫流程；採用先核對步態和服飾對齊再接入遊戲的流程，沒有照搬其角色或強制改為 3D 烘圖。

以上與前三個角色外觀、衣櫃介面、世界風格方向共六個來源；元件動畫的更多取捨另見 component-animation.md。
