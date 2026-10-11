# [ART-18] 同步換裝分層與角色動畫

> 狀態：進行中

## 內文

### 需求
衣服、帽子、頭髮與配件能分開選擇，又能隨主角站姿、待機、走路與各種動作自然同步。不同衣物有自己的輪廓；髮尾、衣襬與背帶適度隨動，帽子、頭髮、手和道具前後關係正確。

### 來源
2026-10-12 使用者要求研究業界如何處理主角服飾、配件與頭髮的動畫，認為可能需分開處理；此前要求紙娃娃購買／自訂服飾、基礎外觀免費無限更換，高像素 HD-2D 與角色一致性。

### 驗收條件
- [x] 比較至少六個來源的逐幀分層、骨架換裝、立體烘焙與次要動作，附來源、觀察和參考圖。
- [ ] 不同衣物能改變服裝輪廓，換裝不是只替同一件外套換色；基礎外觀仍可免費無限更換。
- [ ] 身體、服飾、頭髮、帽子與配件在同一動作進度和八方向下對齊；停走、轉向及動作中換裝不跳位、不露缺口。
- [ ] 帽子遮髮、前後髮束、背包背帶、手與道具的前後順序合理，沒有穿透眼睛、身體或飄離手掌。
- [ ] 次要動作只出現在合適部件，幅度與延遲合理；腳、臉、硬帽與相機保持形狀，不用整身伸縮代替呼吸。
- [ ] 逐衣物／動作／方向覆蓋檢查能指出缺件；素材不完整時安全顯示完整角色，不靜默套用錯誤方向。
- [ ] 原生換裝、正常速度、慢放、降低動態與輸出版本有可審閱證據。

### Research
已實際閱讀八方一手來源：Aseprite、Spine、Unity、Godot、Motion Twin、Universal LPC、Kenney、BrashMonkey。不同方法、閱讀段落、目前素材缺口、逐角色覆蓋與採用理由見[角色動畫與換裝研究](../../design/runtime/character-animation-wardrobe.md)。

![逐幀素材分層時間軸](images/ART-18-reference-aseprite-layers.png)
![可組合服飾參考](images/ART-18-reference-spine-mix-match.png)
![動作與部件分別輸出參考](images/ART-18-reference-lpc-generator.png)

三張皆為實際核對的網站參考截圖，未作為遊戲素材。文字閱讀與靜態截圖不算動畫播放驗收；未觀看教學影片。

### 測試流程
1. 主角在待機、走路、拍照、招呼和慶祝時逐一更換頭髮、帽子、服飾與配件。
2. 逐一觀察八方向以及不對稱服飾／配件，查看遮擋、銜接與完整輪廓。
3. 比較有風、無風、停止與轉向，確認只有適合部件產生次要動作。
4. 檢查缺少服飾姿勢時的完整角色預設、降低動態與輸出版本，附局部結果及原生證據。

---

# 跟其他票的關係

- Blocks：ART-17
- Blocked by：無
- Related：MAIN-8、ART-7、ART-8、ART-14、ART-15、ART-16

---

# 開始

固定基準：affb6b1。分支：feature/island-first-park。需求登記已推送：[22e4fcb](https://github.com/deadline314/Snapland/commit/22e4fcb)。

# Commit-1

### 問題
服裝目前主要換色，部件缺少完整動作覆蓋與遮擋規則。

### 改動
記錄換裝動畫分層研究與驗收要求。

### 驗收
比較八方一手資料，實際核對並保存三張參考截圖；記錄逐幀分層、共用時序、逐格錨點與遮擋順序的取捨。服装轮廓和整套动画尚未製作，驗收保持未勾。

### 測試結果
研究文件與三張參考截圖實際核對，沒有聲稱完成遊戲動畫。

分支：feature/island-first-park。

### 截圖

[原生或研究證據：ART-18-reference-aseprite-layers.png](images/ART-18-reference-aseprite-layers.png)
[原生或研究證據：ART-18-reference-lpc-generator.png](images/ART-18-reference-lpc-generator.png)
[原生或研究證據：ART-18-reference-spine-mix-match.png](images/ART-18-reference-spine-mix-match.png)
