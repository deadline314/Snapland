# 潮汐紙劇場：首區美術完善

來源：2026-10-11 使用者要求持續完善十二款遊戲與島嶼；先研究成熟實例，採用自己的風格，不停在半完成品。

本批固定基準：92e885390967bff3abbde3cf52716076124b1383。ART-3、ART-4、ART-5、ART-6、SG-14 已先於 main 開票。沿用 feature/island-first-park 與獨立 worktree。

## 自己的風格與本批完成標準

潮汐紙劇場是一座海港老遊樂園：暖紙、印刷墨輪廓、木與銅、青綠海色、珊瑚亭棚、奶油石材與夜間靛藍。人物與遊園維持像素角色配立體光影；小遊戲採插畫布景與可操作道具。地標使用拍貼、潮汐、燈塔和小角的原創意象。

港口、廣場、迎賓大道、九區入口須有材質、建築設備、可辨識植物與前中後景；改善現在方盒、球樹與過亮光線。主角、票票、小角、阿浪須有不同外型与行走方向。每款遊戲須有完整主題構圖、具體道具、命中回饋與讀得懂的進度。介面使用海港遊園票和收藏冊風格。

美術改進不可改掉普通/惡魔拍貼、輔助、成就與任務規則。渲染目標與碰撞範圍須一致；降低動態仍可閱讀節拍與遊戲訊號。完成後逐款真實輸入原生驗收、觀看截圖與重新輸出 Windows 預覽包。

## 實際查閱來源與觀察

1. [Octopath Traveler II 官方開發訪談](https://www.unrealengine.com/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style?lang=en-US)。實際讀到：環境解析度與有機像素細節提高；角色比例增加動作空間；日夜動態光線；固定探索相機下讓想前往的地方同屏可見。查看官方港口圖：船索、木板、石岸、岸邊燈與遠海提供尺度及材質；平面角色靠地面陰影融入環境。本作用層次、可讀地標與光影，不複製其船、角色或場景。
2. [Nintendo《耀西的手工世界》官方頁](https://www.nintendo.com/en-gb/Games/Nintendo-Switch-games/Yoshi-s-Crafted-World-1233953.html)。實際讀到：紙、紙箱與日常物材組成前後場景、翻面探索。查看官方圖：紙邊、軟材質、立體植物与玩具欄杆形成一致的物料世界。本作採印刷與海港木銅材料的一致語言，不使用角色、圖案或辨識性構圖。
3. [Nintendo《WarioWare: Move It!》官方頁](https://www.nintendo.com/us/store/products/warioware-move-it-switch/)。實際讀到且查看官方微遊戲圖：不同簡短行為用獨立場景與大尺度操作主體呈現；When Our Eyes Meet 用近景人物與視線突出動作。本作維持原十二款玩法，學清楚主體與每款獨立意象，使用自己的人物與道具。

4. [Game Accessibility Guidelines：避免頻閃與重複規律圖案](https://gameaccessibilityguidelines.com/avoid-flickering-images-and-repetitive-patterns/)。實際讀到：盡可能避免頻閃，若核心訊號無法取消，提供清楚的效果選項。本批用局部命中章、粒子與角色姿態取代全螢幕閃白；降低動態仍保留不閃爍的玩法訊號。

[GDC Juice It or Lose It](https://www.gdcvault.com/play/1016487/juice-it-or-lose) 只讀到講座資訊，沒有完整觀看影片，不把細節寫成已查證。

5. [Splatoon 官方開發訪談](https://www.nintendo.com/en-gb/Iwata-Asks/Iwata-Asks-Splatoon/Splatoon/4-Gaining-Momentum/4-Gaining-Momentum-1021371.html)。實際讀到：角色形態、動作措辭、服裝與音樂由同一個世界概念串起來。採這種一致性，讓相機旅人、海港工作服及小角的不對稱輪廓互相呼應；沒有複製街頭塗鴉或魷魚角色。頁內影片未播放。
6. [Dead Cells 美術作者的製作分享](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-)。實際讀到：先確定關鍵姿態、時機與可修改的動作流程，再烘出像素幀。採姿態清楚及便於重做的流程；本批直接製作像素圖集，没有宣稱完成 3D 烘焙。

這六個來源分別處理立體光影、材料語言、玩法構圖、動態舒適度、角色世界觀與動作製程；不依單一作品決定風格。部件動畫另有七個來源的比較與採用原因，見 [動畫研究](component-animation.md)；換裝與生成提示詞見 [衣櫃設計](wardrobe.md) 與 [提示詞指南](art-prompt-guide.md)。

參考圖僅供票券審閱，版權屬原作者；不放進遊戲資源或匯出執行檔。

![官方港口材質與光影](../../pm/Snapland-art/images/ART-3-reference-octopath-ii.jpg)
![官方手工場景材質](../../pm/Snapland-art/images/ART-5-reference-crafted-world.png)
![官方微遊戲主體構圖](../../pm/Snapland-art/images/ART-5-reference-warioware.png)

## 實作分工與驗收

- ART-3/4：world 範圍；島岸、建物、植物、日夜、角色与動作。
- ART-5/SG-14：minigames 範圍；十二款布景、道具、介面與回饋，保留玩法契約。
- ART-6：main/UI 範圍；遊園 HUD、入口、結果與收藏。
- 主 session：原創場景底圖生成、來源與資源紀錄、GPU 畫面與真實輸入驗收、逐票提交及 Windows 包裝。

所有測試、截圖、執行檔驗收皆使用獨立 SNAPLAND_SAVE_PATH；沒有設定就中止。只跑受影響 runtime 套件；完整設計驗證交 CI。原生截圖保存新票名稱，不覆蓋上一輪證據。
