# [ART-11] 擴大透視圈與柔化邊緣

> 狀態：進行中

## 內文

### 需求
加大建築遮擋時的圓形揭露範圍，保留穿搭及動作可讀性；比較柔和邊緣與過渡效果，降低動態仍可辨識主角。

### 問題—改動—驗收
問題：走到建築後面時，玩家不容易看清主角和當下動作。

改動：主角被建築擋住時，以更寬鬆的視野窗保留角色辨識，也評估較柔和的邊緣。

驗收：玩家進出遮擋時能看清完整主角，周圍建築仍自然可辨；主 Session 已檢視更新後的日夜、拱門、1600×900 穿戴與降低動態畫面；原生遮擋移動錄製檢查通過。

### 來源
2026-10-12 使用者要求：加大透視圈並考慮效果、NPC 避免遮擋且有個性動作、修正光影、自由切換四時段並融入拍貼或任務、小遊戲有時段布景。研究需超過五個來源，來源與已看過的截圖一同附票。

### 驗收條件
- [x] 至少六個來源記錄實際觀察及效果取捨。
- [x] 原生畫面可辨識較大的透視圈，邊緣過渡不遮住臉部且圈外建築正常。
- [ ] 不同視窗、日夜、換裝、進出遮擋及降低動態正常；局部測試與截圖、短片齊全。

### 研究來源
已閱讀六個以上來源的文字內容；逐項觀察及採用取捨記錄於[建築遮擋研究](../../design/runtime/occlusion.md)。相關原始文件：[Godot 射線](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html)、[Godot 深度與後處理](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html)、[Godot Spatial Shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)、[Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)、[Godot smoothstep](https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/shader_functions.html)、[Unity Cinemachine Deoccluder](https://docs.unity.cn/Packages/com.unity.cinemachine@6.6/manual/CinemachineDeoccluder.html)、[Unity Stencil](https://docs.unity3d.com/Manual/SL-Stencil.html)、[Chris Kurhan 的 URP 遮擋淡出說明](https://discussions.unity.com/t/tutorial-opaque-objects-making-it-hard-to-see-fade-them-out-with-the-standard-urp-shaders/888353)。未宣稱看過教學影片。

### 測試流程
1. 啟動獨立測試存檔，原生操作本票功能。
2. 檢查四時段、設定、重啟與不同視窗的相關行為。
3. 保存實際看過的截圖和短片，執行受影響局部驗證。

---

# 跟其他票的關係
- Blocks：無
- Blocked by：無
- Related：ART-10、ART-13

---

# 開始

固定基準：c8202d69779497456ee55ae1ca051d21f7952dec。分支：feature/island-first-park。

# Commit-1

### 問題
建築遮擋圈過小，邊緣不夠柔和。

### 改動
擴大建築透視圈並柔化邊緣。

### 驗收
原生遮擋 fixture 錄影檢查通過，主 Session 檢視日夜、拱門、換裝、1600×900 和降低動態画面。

### 測試結果
受影響的執行專案檢查19/19通過；Windows輸出以實際GPU檢查角色圖集、NPC活動、場景動畫與遮擋資源載入通過，無ERROR。

分支：feature/island-first-park。

### 截圖

[原生或研究證據：ART-11-arch-cutaway-clear.png](images/ART-11-arch-cutaway-clear.png)
[原生或研究證據：ART-11-arch-cutaway-day.png](images/ART-11-arch-cutaway-day.png)
[原生或研究證據：ART-11-arch-cutaway-resized-equipped.png](images/ART-11-arch-cutaway-resized-equipped.png)
[原生或研究證據：ART-11-cutaway-clear.png](images/ART-11-cutaway-clear.png)
[原生或研究證據：ART-11-cutaway-day.png](images/ART-11-cutaway-day.png)
[原生或研究證據：ART-11-cutaway-night.png](images/ART-11-cutaway-night.png)
[原生或研究證據：ART-11-cutaway-reduced-motion.png](images/ART-11-cutaway-reduced-motion.png)
[原生或研究證據：ART-11-cutaway-right-kiosk.png](images/ART-11-cutaway-right-kiosk.png)

### 程式與證據提交
分支：feature/island-first-park。更新至最新main後的本票提交：[b90ecb2](https://github.com/deadline314/Snapland/commit/b90ecb22684d65d071edc0f31b27ddff2ca41102)。


# Commit-2

### 問題

拉近鏡頭查看乘坐角色時，透視圈停在固定大小，臉和鞋子仍被設施遮住。

### 改動

一般遊園鏡頭維持克制的開口，近景會隨角色在畫面中的尺寸放大；圈外建築保持正常光影，離開遮擋後恢復完整外觀。

### 驗收

主 Session 實際查看近景完整角色、柔邊、圈外建築陰影與離開後恢復的原生截圖，並查看正常速度與四分之一速度短片。這是獨立遮擋畫面驗收，不代表島上自由遊玩或角色動畫品質已完成。

### 測試結果

| 項目 | 結果 |
|---|---|
| 提交內容獨立匯入、建築遮擋局部檢查 | 2 / 2 通過，0 ERROR |
| 一般及近景、1280×720 與 800×600 尺寸檢查 | 通過 |
| 原生近景遮擋及恢復 | 通過，0 ERROR；近景半徑約 209 像素 |

本輪固定基準：`c9bf47f`。分支：`feature/island-experience`。遠端提交連結於推送後補入。

### 截圖及影片

![近景完整角色與建築陰影](images/ART-11-zoom-v3-reveal.png)
![離開後恢復完整建築](images/ART-11-zoom-v3-restored.png)
[正常速度](images/ART-11-zoom-v3-normal.mp4) · [四分之一速度](images/ART-11-zoom-v3-quarter.mp4) · [原生記錄](images/ART-11-zoom-v3-native.log)
