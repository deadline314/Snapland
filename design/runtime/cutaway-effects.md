# ART-11: 圓形透視範圍與邊緣

## 研究記錄

這次比較畫面遮罩、相機避障、透明混合與不透明裁切。官方文件按實際閱讀內容記錄；專案過往遮擋研究保留其來源與限制。

| 一手來源 | 實際觀察 | 採用或取捨 |
|---|---|---|
| [Godot Spatial Shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html) | spatial shader 提供 `IN_SHADOW_PASS`、`SCREEN_UV`、`FRAGCOORD` 和 `ALPHA`；寫入 `ALPHA` 會改走透明流程，透明材質排序及投影有額外限制 | 以螢幕像素判斷局部圓形，只在相機 pass 裁切；避免寫 alpha，因此保留不透明深度與原陰影輪廓 |
| [Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) | 正交相機物件畫面比例不隨距離變化；`unproject_position` 把世界位置投影至視口像素 | 半徑按角色投影高度算，視口 resize 與正交 zoom 後仍匹配角色大小 |
| [Godot Ray-casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html) | 射線查詢需要從正確物理階段呼叫，排除角色，並可用 collision mask 限定命中物 | 仍以低頻、排除玩家的射線決定何時啟用；擴大圓圈不改碰撞 |
| [Godot shader `smoothstep`](https://docs.godotengine.org/en/4.4/tutorials/shaders/shader_reference/shader_functions.html) | `smoothstep` 在兩個門檻間做平滑 Hermite 插值 | 用於計算 2.5 個邏輯像素的窄邊緣覆蓋率，再以固定螢幕雜訊作不透明 discard；不用整棟透明淡出 |
| [Unity Cinemachine Deoccluder 6.6](https://docs.unity.cn/Packages/com.unity.cinemachine@6.6/manual/CinemachineDeoccluder.html) | 官方方案用射線調整相機位置，提供遮擋/返回 damping、最小遮擋時間與最多處理命中數；文檔也指出 collider raycast 成本 | 保留固定 HD-2D 構圖，不移動相機；短控制器漸變與有限射線數足夠 |
| [Unity Stencil](https://docs.unity3d.com/Manual/SL-Stencil.html) | stencil 可控制區域繪製；Godot 自己的 spatial shader 文件標示 stencil 功能為實驗性，且只可於透明 pass 讀取 | 不加第二個遮罩 pass/stencil 依賴，選單次不透明 shader 裁切 |
| [ShaderCrew](https://shadercrew.com/) | 先前已讀取其圓形遮罩與局部溶解/材質分組的說明；原網站的 PDF 本次仍無法讀取 | 延用局部圓形與限定建築分組概念，不採其素材或商業程式；不將不可讀 PDF 說成已研究 |
| [Chris Kurhan 的 URP 淡出說明](https://discussions.unity.com/t/tutorial-opaque-objects-making-it-hard-to-see-fade-them-out-with-the-standard-urp-shaders/888353) | 先前已閱讀貼文；作者測量是其特定 Unity 專案，不是 Snapland 的效能數字，教學影片沒有觀看 | 把整個遮擋物淡出列為對照，但保留圓外建築的原色與完整遮擋，且不宣稱其效能數據適用本作 |

## 本作決策

圓心沿用角色身體在螢幕上的投影。基準半徑從約半個角色投影高度提升到 0.75 倍，並限制於 32–120 視口像素，再受視口短邊 17% 上限約束。這讓穿搭與動作留出較大可讀空間，同時避免小視窗被圓圈佔滿；正交 zoom 改變投影高度時半徑隨之變化。DPI canvas stretch 仍使用 Godot 邏輯視口座標，不能把實體擷取圖片大小誤當 shader 視口大小。

圓內依舊只裁掉實際位於主角前方的合格建築片段。圓外保留原本顏色與受光；`IN_SHADOW_PASS` 時不執行螢幕遮罩，因此陰影仍按完整建築投影。邊緣採窄、不透明螢幕雜訊裁切帶，不寫 `ALPHA`，避開透明排序與深度變化。降低動態保留可見性輔助並直接到目標狀態。半徑／裁切不觸碰碰撞形狀與玩家碰撞層。

Headless 回歸測試驗證投影比例、視口 resize、zoom 上下限、前後深度、陰影 pass guard、材質還原和碰撞不變；它不能判定原生畫面的軟邊是否合適，仍需看 capture/movie 的實際像素效果。
