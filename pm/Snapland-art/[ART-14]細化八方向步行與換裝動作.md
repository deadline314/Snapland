# [ART-14] 細化八方向步行與換裝動作

> 狀態：進行中

## 內文

### 需求
改善主角走路姿勢與過少的影格，提供八方向行走與自然的重心、擺臂、跨步及腳底接地。斜向行走有相應圖像，髮型、服飾、帽子與種族部件同步，保留自己的高細節像素風格。

### 問題—改動—驗收
問題：原本走路方向和姿勢變化不足，衣帽和不同外觀也需要跟上每個方向。

改動：補上八個方向的全身走路圖和相應外觀部件，讓玩家能順著行走方向看清角色。

驗收：玩家在八個方向都能看到完整角色和相符的外觀；自然腳步、重心與連續性仍待更高動作標準的 ART-16 複核，不把目前的八方向素材說成已完美。

### 來源
2026-10-12 使用者實際看過四方向走路錄影後指出姿勢怪、需要更多姿勢及八方向圖。研究至少六個來源，保留實際觀察、採用理由、素材來源與已檢視截圖；錄影留作改進前對照。

### 驗收條件
- [x] 至少六個來源比較步行週期、八方向圖、像素影格及分層換裝，記錄取捨。
- [x] 八方向全身走路圖、移動距離驅動的動畫節奏及停步方向待機已在原生錄影中檢視。
- [ ] 腳步、重心與擺臂自然，斜向動作完整，沒有明顯滑步或跳幀；高動作品質仍由 ART-16 驗收。
- [x] 髮型、帽子及種族部件三套各 24 格的方向圖與 64 張全身姿勢已檢視；切格對應已按原圖修正。
- [ ] 日夜、降低動態、碰撞與打包的完整局部驗收通過。
- [x] 八方向原生錄影與逐姿勢、部件對照圖已保存並由根工作階段實際檢視。

### 研究來源
已閱讀六個以上來源的文字內容；實際觀察、採用與不採用理由記錄於[動畫品質研究](../../design/runtime/animation-quality.md)及[八方向步行規格](../../design/runtime/eight-direction-walk.md)。相關原始文件：[Aseprite 動畫](https://www.aseprite.org/docs/animation)、[Aseprite Onion Skin](https://www.aseprite.org/docs/onion-skinning/)、[Pixel Joint 步行回饋](https://pixeljoint.com/forum/forum_posts.asp?PID=215709&TID=25611)、[Raymond Schlitter 步態研究](https://www.slynyrd.com/blog/2020/1/23/pixelblog-25-motion-cycles)、[UNM walk-cycle 課程](https://swardson.com/unm/animation1/mod13-walkcycle.php)、[Godot 2D Skeleton](https://docs.godotengine.org/en/4.7/tutorials/animation/2d_skeletons.html)、[Spine Weights](https://us.esotericsoftware.com/spine-weights)、[Spine IK](https://esotericsoftware.com/spine-ik-constraints)、[Spine Graph interpolation](https://en.esotericsoftware.com/spine-graph)、[Dead Cells 美術作者流程](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-)。未宣稱看過影片。

原生證據：八方向走路錄影、64 張逐姿勢檢視圖，以及 24×3 髮型／帽子／種族部件方向圖已由根工作階段實際查看。來源圖確認第 6、7 格切片對應有誤，現已修正區域資料。這些檢查不能證明步態已自然流暢；較高動作驗收仍在 ART-16 進行。

### 測試流程
1. 使用獨立測試存檔，以鍵盤走八個方向並停步、換裝。
2. 比較舊版與新版影格，檢查腳底、衣帽定位與移動距離。
3. 保存實際錄影及截圖，執行相關局部驗證與打包檢查。

---

# 跟其他票的關係
- Blocks：無
- Blocked by：無
- Related：ART-4、ART-7、ART-9、ART-12、ART-13

---

# 開始

固定基準：7c2aa9542e1abe095cf32049469d251b6e95bb3d。分支：feature/island-first-park。

# Commit-1

### 問題
四方向步態與方向配件不足，來源切片也有邊界錯誤。

### 改動
提供八方向步態與方向部件。

### 驗收
八方向正常播放、64格全身圖與髮型／帽子／種族方向圖已檢視。修正相鄰來源切片，素材可輸出載入；自然度和完整動作仍由ART-16／17／18追蹤。

### 測試結果
受影響的執行專案檢查19/19通過；Windows輸出以實際GPU檢查角色圖集、NPC活動、場景動畫與遮擋資源載入通過，無ERROR。

分支：feature/island-first-park。

### 截圖

[原生或研究證據：ART-14-eight-direction-walk.mp4](images/ART-14-eight-direction-walk.mp4)
[原生或研究證據：ART-14-gallery-hair.png](images/ART-14-gallery-hair.png)
[原生或研究證據：ART-14-gallery-hat.png](images/ART-14-gallery-hat.png)
[原生或研究證據：ART-14-gallery-poses-back.png](images/ART-14-gallery-poses-back.png)
[原生或研究證據：ART-14-gallery-poses-back_left.png](images/ART-14-gallery-poses-back_left.png)
[原生或研究證據：ART-14-gallery-poses-back_right.png](images/ART-14-gallery-poses-back_right.png)
[原生或研究證據：ART-14-gallery-poses-front.png](images/ART-14-gallery-poses-front.png)
[原生或研究證據：ART-14-gallery-poses-front_left.png](images/ART-14-gallery-poses-front_left.png)
[原生或研究證據：ART-14-gallery-poses-front_right.png](images/ART-14-gallery-poses-front_right.png)
[原生或研究證據：ART-14-gallery-poses-left.png](images/ART-14-gallery-poses-left.png)
[原生或研究證據：ART-14-gallery-poses-right.png](images/ART-14-gallery-poses-right.png)
[原生或研究證據：ART-14-gallery-species.png](images/ART-14-gallery-species.png)
[原生或研究證據：ART-14-walk-back.png](images/ART-14-walk-back.png)
[原生或研究證據：ART-14-walk-back_left.png](images/ART-14-walk-back_left.png)
[原生或研究證據：ART-14-walk-back_right.png](images/ART-14-walk-back_right.png)
[原生或研究證據：ART-14-walk-front.png](images/ART-14-walk-front.png)
[原生或研究證據：ART-14-walk-front_left.png](images/ART-14-walk-front_left.png)
[原生或研究證據：ART-14-walk-front_right.png](images/ART-14-walk-front_right.png)
[原生或研究證據：ART-14-walk-left.png](images/ART-14-walk-left.png)
[原生或研究證據：ART-14-walk-right.png](images/ART-14-walk-right.png)

### 程式與證據提交
分支：feature/island-first-park。更新至最新main後的本票提交：[209d95f](https://github.com/deadline314/Snapland/commit/209d95fb5ad0d9c24d6f6213b726efaa9988db43)。
