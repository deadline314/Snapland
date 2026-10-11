# 建築遮擋：圓形透視研究
使用者要求主角在建築後方仍可看見，保留圓形區域而不破壞 HD-2D 構圖。以下六個來源已閱讀實際文字；沒有播放影片。外部圖片只存票內作審閱。

| 來源 | 實際內容 | 採用與取捨 |
|---|---|---|
| [ShaderCrew 原作者](https://shadercrew.com/) | 圓形、溶解、半徑與多角色定位；分組替換及排除材質 | 採跟隨主角的局部圓形與建築用途分組；不用其素材或商業程式 |
| [ChrisKurhan 的 URP 淡出教學說明](https://discussions.unity.com/t/tutorial-opaque-objects-making-it-hard-to-see-fade-them-out-with-the-standard-urp-shaders/888353) | 用標準材質淡出遮擋物，作者提供成本數據與專案 | 比較整棟淡出，決定保留圓外建築。未觀看教學影片，作者效能數字不代表本作 |
| [Godot 射線文件](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html) | 物理時機、排除角色、遮罩；正交鏡頭的射線原點隨畫面位置變化 | 用實際遮擋判斷啟用，避免從鏡頭中心錯射、把後方建築當遮擋 |
| [Godot 深度與後處理](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html) | 同視口深度、4.3 後反向 Z、不同渲染器投影範圍 | 採畫面座標與主角前後深度限制；不直接套舊版深度公式 |
| [Unity Cinemachine Deoccluder](https://docs.unity.cn/Packages/com.unity.cinemachine@6.6/manual/CinemachineDeoccluder.html) | 透過射線移鏡頭避障，指定層、阻擋時間與平滑，碰撞有成本 | 採分層和短過渡；固定 HD-2D 構圖保留，故不採鏡頭突然推近 |
| [Unity Stencil 文件](https://docs.unity3d.com/Manual/SL-Stencil.html) | 額外遮罩比較與通過/失敗操作，可控制區域繪製 | 比較多次繪製方案；目前一名玩家與局部建築遮罩較簡單，暫不增加額外鏡頭或 stencil 管線 |

## 本作決策
透視圓跟隨主角身體中心，大小依畫面中的角色高度調整，為帽子和動作留出空間。適用建築目前包括 15 個亭與 3 個拱門；只有實際射線命中符合資格的遮擋幾何時才啟用。透視圈外的建築保留原材質與光影，地面、水面和角色碰撞不變；離開遮擋後恢復。

主角前方的標題只有在同時位於角色前方、且與透視圓相交時才隱藏，避免其他標題無故消失。降低動態時仍保留角色辨識用的透視圓，不播放過渡動畫。

最新原生 helper 的完整驗收仍待完成；目前已查看的售票亭畫面不能代表 15 個亭與 3 個拱門均已驗收。待驗收項目包括不同建築、前後移動、換裝、視窗大小、日夜、降低動態及進出後的恢復；截圖只能證明單幀，需短影片補足進出效果。官方 Spring Arm 頁只取得標題，ShaderCrew PDF 讀取失敗，均不算已讀來源。
