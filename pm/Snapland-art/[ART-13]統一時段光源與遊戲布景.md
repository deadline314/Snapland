# [ART-13] 統一時段光源與遊戲布景

> 狀態：進行中

## 內文

### 需求
檢查並修正島上光影，投影方向與實際光源一致；四時段展現不同氛圍，小遊戲同步使用時段背景與光影，不影響操作目標辨識。

### 問題—改動—驗收
問題：園區與小遊戲的時段氛圍可能不一致，光影也容易讓玩家誤判方向或目標。

改動：讓四個時段在園區和十二款小遊戲中都能清楚辨認，同時保留易讀的遊戲目標。

驗收：玩家在每個時段都能看清操作目標，園區光源和影子方向一致；目前已檢視四時段與小遊戲畫面，完整光影及打包驗收仍待完成。

### 來源
2026-10-12 使用者要求：加大透視圈並考慮效果、NPC 避免遮擋且有個性動作、修正光影、自由切換四時段並融入拍貼或任務、小遊戲有時段布景。研究需超過五個來源，來源與已看過的截圖一同附票。

### 驗收條件
- [x] 至少六個來源比較太陽光、局部光源、像素角色與二維布景，記錄取捨。
- [ ] 四時段島上光源與投影方向相符，角色、植栽及建築不出現明顯反向或漂浮影子。
- [ ] 夜間燈具發光、日間受控，降低動態不關閉必要照明。
- [x] 十二款小遊戲的四時段背景已檢視；遊戲目標、提示與規則保持清楚。
- [ ] 夜間燈具、所有角色／紙景受光效果的原生檢查、局部測試與打包驗證完成。

### 研究來源
已閱讀六個以上來源的文字內容；實際觀察、光照方向及預繪紙景的限制記錄於[四時段光源研究](../../design/runtime/daylight-lighting.md)。相關原始文件：[Godot DirectionalLight3D](https://docs.godotengine.org/en/stable/classes/class_directionallight3d.html)、[Godot 3D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)、[Godot OmniLight3D](https://docs.godotengine.org/en/stable/classes/class_omnilight3d.html)、[Godot Light3D](https://docs.godotengine.org/en/stable/classes/class_light3d.html)、[Godot SpriteBase3D](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html)、[Godot Environment](https://docs.godotengine.org/en/stable/classes/class_environment.html)、[Godot 2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)、[Octopath Traveler II 官方訪談](https://www.unrealengine.com/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style?lang=en-US)、[Yoshi's Crafted World 官方頁](https://www.nintendo.com/en-gb/Games/Nintendo-Switch-games/Yoshi-s-Crafted-World-1233953.html)。已讀頁面文字；未宣稱看過訪談影片。預繪紙景與 shader 色調不等於每個 sprite 都受物理光照。

原生畫面：四時段園區與十二款遊戲各四時段共 48 張截圖已保存；根工作階段檢視了全部三張小遊戲接觸表及園區四時段畫面。局部最終 integration 檢查單獨通過；此前一輪首格順序發現問題後已修正來源，目前未重跑整套 18 項檢查。套件尚待本機執行檔驗收。

### 測試流程
1. 啟動獨立測試存檔，原生操作本票功能。
2. 檢查四時段、設定、重啟與不同視窗的相關行為。
3. 保存實際看過的截圖和短片，執行受影響局部驗證。

---

# 跟其他票的關係
- Blocks：無
- Blocked by：無
- Related：MAIN-9、ART-3、ART-5、ART-9、ART-11

---

# 開始

固定基準：c8202d69779497456ee55ae1ca051d21f7952dec。分支：feature/island-first-park。

# Commit-1

### 問題
時段光源方向與布景缺少共同基準；部分材質未提交，乾淨匯入失敗。

### 改動
統一四時段光源與遊戲布景。

### 驗收
四時段與12款×4時段共48張原生布景已檢視；相關局部檢查通過。預繪紙景和像素陰影仍有限制，未勾選全場物理受光。

### 測試結果
受影響的執行專案檢查19/19通過；Windows輸出以實際GPU檢查角色圖集、NPC活動、場景動畫與遮擋資源載入通過，無ERROR。

分支：feature/island-first-park。

### 截圖

[原生或研究證據：ART-13-game01-dawn.png](images/ART-13-game01-dawn.png)
[原生或研究證據：ART-13-game01-dusk.png](images/ART-13-game01-dusk.png)
[原生或研究證據：ART-13-game01-night.png](images/ART-13-game01-night.png)
[原生或研究證據：ART-13-game01-noon.png](images/ART-13-game01-noon.png)
[原生或研究證據：ART-13-game02-dawn.png](images/ART-13-game02-dawn.png)
[原生或研究證據：ART-13-game02-dusk.png](images/ART-13-game02-dusk.png)
[原生或研究證據：ART-13-game02-night.png](images/ART-13-game02-night.png)
[原生或研究證據：ART-13-game02-noon.png](images/ART-13-game02-noon.png)
[原生或研究證據：ART-13-game03-dawn.png](images/ART-13-game03-dawn.png)
[原生或研究證據：ART-13-game03-dusk.png](images/ART-13-game03-dusk.png)
[原生或研究證據：ART-13-game03-night.png](images/ART-13-game03-night.png)
[原生或研究證據：ART-13-game03-noon.png](images/ART-13-game03-noon.png)
[原生或研究證據：ART-13-game04-dawn.png](images/ART-13-game04-dawn.png)
[原生或研究證據：ART-13-game04-dusk.png](images/ART-13-game04-dusk.png)
[原生或研究證據：ART-13-game04-night.png](images/ART-13-game04-night.png)
[原生或研究證據：ART-13-game04-noon.png](images/ART-13-game04-noon.png)
[原生或研究證據：ART-13-game05-dawn.png](images/ART-13-game05-dawn.png)
[原生或研究證據：ART-13-game05-dusk.png](images/ART-13-game05-dusk.png)
[原生或研究證據：ART-13-game05-night.png](images/ART-13-game05-night.png)
[原生或研究證據：ART-13-game05-noon.png](images/ART-13-game05-noon.png)
[原生或研究證據：ART-13-game06-dawn.png](images/ART-13-game06-dawn.png)
[原生或研究證據：ART-13-game06-dusk.png](images/ART-13-game06-dusk.png)
[原生或研究證據：ART-13-game06-night.png](images/ART-13-game06-night.png)
[原生或研究證據：ART-13-game06-noon.png](images/ART-13-game06-noon.png)
[原生或研究證據：ART-13-game07-dawn.png](images/ART-13-game07-dawn.png)
[原生或研究證據：ART-13-game07-dusk.png](images/ART-13-game07-dusk.png)
[原生或研究證據：ART-13-game07-night.png](images/ART-13-game07-night.png)
[原生或研究證據：ART-13-game07-noon.png](images/ART-13-game07-noon.png)
[原生或研究證據：ART-13-game08-dawn.png](images/ART-13-game08-dawn.png)
[原生或研究證據：ART-13-game08-dusk.png](images/ART-13-game08-dusk.png)
[原生或研究證據：ART-13-game08-night.png](images/ART-13-game08-night.png)
[原生或研究證據：ART-13-game08-noon.png](images/ART-13-game08-noon.png)
[原生或研究證據：ART-13-game09-dawn.png](images/ART-13-game09-dawn.png)
[原生或研究證據：ART-13-game09-dusk.png](images/ART-13-game09-dusk.png)
[原生或研究證據：ART-13-game09-night.png](images/ART-13-game09-night.png)
[原生或研究證據：ART-13-game09-noon.png](images/ART-13-game09-noon.png)
[原生或研究證據：ART-13-game10-dawn.png](images/ART-13-game10-dawn.png)
[原生或研究證據：ART-13-game10-dusk.png](images/ART-13-game10-dusk.png)
[原生或研究證據：ART-13-game10-night.png](images/ART-13-game10-night.png)
[原生或研究證據：ART-13-game10-noon.png](images/ART-13-game10-noon.png)
[原生或研究證據：ART-13-game11-dawn.png](images/ART-13-game11-dawn.png)
[原生或研究證據：ART-13-game11-dusk.png](images/ART-13-game11-dusk.png)
[原生或研究證據：ART-13-game11-night.png](images/ART-13-game11-night.png)
[原生或研究證據：ART-13-game11-noon.png](images/ART-13-game11-noon.png)
[原生或研究證據：ART-13-game12-dawn.png](images/ART-13-game12-dawn.png)
[原生或研究證據：ART-13-game12-dusk.png](images/ART-13-game12-dusk.png)
[原生或研究證據：ART-13-game12-night.png](images/ART-13-game12-night.png)
[原生或研究證據：ART-13-game12-noon.png](images/ART-13-game12-noon.png)
[原生或研究證據：ART-13-world-dawn.png](images/ART-13-world-dawn.png)
[原生或研究證據：ART-13-world-dusk.png](images/ART-13-world-dusk.png)
[原生或研究證據：ART-13-world-night.png](images/ART-13-world-night.png)
[原生或研究證據：ART-13-world-noon.png](images/ART-13-world-noon.png)
