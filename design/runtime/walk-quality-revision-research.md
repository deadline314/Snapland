# Walk quality revision research

> **Pre-revision baseline.** The measurements in the opening analysis and the six original revision hypotheses below describe the prior gait before the current Hero candidate. They are retained for comparison, not as current values or evidence of acceptance.

本研究供步態修訂使用，不代表已看過當前畫面的實機效果。實際限制已讀 [avatar_motion_rig.gd](../../game/world/avatar_motion_rig.gd)：走路時上身是一張固定方向的 `_upper` 精靈；只有腿由 IK 網格重算。`FOOT_STROKE=0.28m`、步行支撐期 `0.60`，單腳完整週期距離因而是 `0.467m`；在 2m/s 下約每 0.23 秒一個完整週期。支撐期腳掌相對身體線性後移，擺動期以 `sin(πt)` 抬腳，步行骨盆 bob 僅 0.012m。走路時 idle 位移會隨 `blend` 淡出；靴子只設偏航，沒有落地／離地俯仰。這些數值提供可查的假說：短步幅、快節拍、幾乎不動的上身會讀成急促滑步；需用錄影確認，不能僅憑參數宣告成因。

## 可執行的修訂方向

1. **先讓「移動速度—腳步週期—落地」一致。** 目前腳相位按實際位移推進，這是保住落地不滑的正確基礎；不要改成獨立時間循環。現有週期約 0.47m，而角色整體高度 2.4m，測試需量同一隻腳每週期跨距、接地時間及接地段世界座標殘差。用角色身高與真實 2m/s／0.55m/s速度反推可接受步頻；若步幅想加長，先檢查 0.45m 固定腿長能否在不超解算距離下支援，不能靠壓縮／拉長骨頭掩蓋。Insomniac 的 Walk Guide 以實際速度移動導軌，並要求每個接地影格的腳標記貼住導軌；這正適合當本 rig 的量測原則。[Insomniac 技術總監的原文](https://www.gamedeveloper.com/programming/giving-life-to-ratchet-clank-enabling-complex-character-animations-by-streamlining-processes)；[Spine IK 文件](https://us.esotericsoftware.com/spine-ik-constraints)

2. **用四個可辨認姿勢檢查連續曲線。** 每腳循環至少驗 contact、承重下沉、passing、high point，左右腳反相；contact 時支撐腳貼地，passing 時擺動腳越過支撐腳，接近下一次 contact 時平順減速。Blender 步態教學明確列出這四類姿勢，並提醒路徑暫停不能把角色凍在一腳懸空的 walk pose。[Blender walk-cycle 教學](https://docs.blender.org/api/htmlI/x8053.html)（舊版手冊，概念參考）；[Röki 開發者步態文章](https://store.steampowered.com/news/posts/?appids=1067540&enddate=1605779951&feed=steam_community_announcements)

3. **把重量交接畫出來。** Röki 開發者指出承重髖移向支撐腳，骨盆 yaw／roll 讓髖、腿作為一體延伸步幅。Snapland 可先試極小側向骨盆移動、對應 roll，以及隨支撐腳交接的微量轉向；變化需平滑集中在中段支撐期，而非全程正弦晃動。把腰部位移限制在 IK 可達範圍內，持續保留 `solve_support_pelvis` 的 reach assertions。以同一相位視圖量腿根是否穿腰、膝蓋是否突然彈跳。[Röki](https://store.steampowered.com/news/posts/?appids=1067540&enddate=1605779951&feed=steam_community_announcements)；[Spineboy 腿部 IK 實例](https://en.esotericsoftware.com/spine-examples-spineboy)

4. **加上腳踝的落地／蹬離訊號。** 現在靴子只設定 yaw。可以測試擺動期小幅腳尖上翹、接地前回到平腳、支撐末段腳跟抬起，並讓真正的世界接觸點繼續由現有 ground provider 決定。先從小角度、單一方向開始，確保 boot silhouette、鞋底接觸點和世界錨點不因旋轉偏移；不需要改足部材質或放寬固定骨長。Spineboy 案例把腿 IK 和足部 IK 分成兩個有順序的約束，說明腳掌朝向／足尖接觸值得獨立處理。[Spineboy](https://en.esotericsoftware.com/spine-examples-spineboy)

5. **承認上身凍結的表現上限。** Röki 描述自然步態的對側手臂與腿交替；但目前 `_upper` 是整張精靈，沒有獨立手臂骨或手臂圖層，無法產生真正的反向擺臂。可先用非常小的肩線／上身反向旋轉和軀幹節奏試驗輪廓，不要大幅傾斜像素精靈。若仍僵硬，最有效的修正是新增經核准的方向性上身 walk 姿勢，或把手臂分成可獨立變形的 source layer；只調腿 IK 無法解決這個結構限制。Insomniac 的作者也強調程序技術不能取代動畫師對動作和轉場的設計。[Röki](https://store.steampowered.com/news/posts/?appids=1067540&enddate=1605779951&feed=steam_community_announcements)；[Insomniac 技術總監](https://www.gamedeveloper.com/programming/giving-life-to-ratchet-clank-enabling-complex-character-animations-by-streamlining-processes)

6. **不要用一個漂亮 loop 蓋過起步、轉向與停步。** 先用當前控制器的實際加減速錄下起步、直走、90°轉向、停步四段。保留明確 replant／settle；不要在站立期間延續半空腳，也不要讓攝影機轉向被誤當成角色重定向。Ubisoft 的 GDC 內容摘要指出，被動、即時反應式腳 IK 容易帶來遲滯與程序感；其方向是預測生物力學接觸並保留動作細節。另一場 GDC 講座摘要指出 path/turn 和動畫能力要互相限制，否則會出現 pivot／footskate。兩場僅讀到官方摘要，沒有看完整影片。[Ubisoft foot IK GDC](https://gdcvault.com/play/1023009/Fitting-the-World-A-Biomechanical)；[Animation-driven locomotion GDC](https://gdcvault.com/play/1015614/Animation-Driven-Locomotion-for-Smoother)

## 驗收方式

固定相機與 1280×720 畫面，並排比較 2m/s 與 0.55m/s、正面／側面／斜向；再拍起步、90°轉向、停步。疊加地面接觸點與骨盆軌跡，量支撐腳世界座標殘差、步頻、腳尖離地時間、最大膝 reach、上身像素位移。先 CPU 驗 reach／接觸不變量，再由人檢視 native 影片；測試 PASS 不能代替視覺驗收。Godot 的 blend 文件亦提醒，狀態缺少明確初始化屬性會以初值參與混合，因此新增動態上身參數需定義休息預設與停止回復，不可留下最後一幀姿勢。[Godot AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html)

## 來源閱讀紀錄

- 已讀原文：Spine IK 官方文件、Spineboy 官方骨架實例、Röki 開發團隊步態文章、Insomniac《Ratchet & Clank》動畫技術總監 John Lally 原文、Godot AnimationTree 官方文件、Adobe Animate 幀／關鍵影格官方文件。
- 已讀官方 GDC session 摘要，未看影片：Ubisoft《Fitting the World: A Biomechanical Approach to Foot IK》、IO Interactive／Eidos《Animation Driven Locomotion for Smoother Navigation》。
- Blender walk-cycle 頁面是舊版官方手冊中的作者教程；頁面直接開啟遇到 402，但搜尋回傳全文摘要涵蓋 contact/recoil/passing/high-point 與停步 transition。只採用這些概念，不把它當當代 Blender 功能規格。
- 沒有宣稱本輪執行或觀看任何遊戲，也未做 native 視覺驗收。

## Current Hero candidate (visual review pending)

The current working candidate measures a 0.600 m walk cycle at 0.55 m/s (about 110 steps/min) and a 1.4 m run cycle at 2.0 m/s (about 171 steps/min). Its configured peak lift values are 35 mm for walking and 65 mm for running; gait roll is bounded to ±0.6° and yaw to ±1.2°. The profile also uses measured side-view foot articulation of 4°/8° and a fixed, source-measured chain of 0.374064327 m. These are implementation parameters, not a claim that the motion looks natural or has passed native review. The latest native GPU review has not passed.

The upper body is still one deforming source sprite/mesh: it has no independently rigged arms. It therefore cannot provide a true opposing arm swing. Preserve that structural limitation in review notes rather than describing torso motion as authored arm animation.
