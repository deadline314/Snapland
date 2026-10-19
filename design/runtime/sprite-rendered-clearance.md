# 完整角色的來源、接地與場景遮擋分開驗收

2026-10-20；ART-15，ART-12／MAIN-2相關。開始main `2cdc3abbd8776ca518d7c2b5a0cdd205a51d96ef`。先讀User-guide，重跑目前正式完整2D人物的原生完整性檢查。沒有啟用拆腿候選或改動角色來源。

## 實際問題

舊檢查確認來源可見範圍在鏡頭內、腳底沒有低於地板，仍把27張畫面全部判過。實際看圖才發現小角左側手腳被花台與燈座蓋住。這是場景遮擋，不是來源裁切或接地失敗。四個姿勢與降低動態下，實際渲染的人物範圍有約7.9%–16.1%像素和只呈現人物的同光照參照不同；其他角色及主角案例為0。

調整小角到旁邊開放站位，任務互動位置一起跟隨；保留既有花台、燈、場景深度測試和角色尺度。沒有用關閉深度、抬高人物或加全身描邊遮住問題。

## 六個不同來源團隊的文字比較

本輪實際閱讀下列文字；沒有宣稱觀看參考影片或取得外部圖。LearnOpenGL頁面原始下載收到406，Blender／Valve頁面取回失敗，均未當成看過圖片。以下以本作實際原生前後圖呈現問題。

| 來源 | 採用與界線 |
|---|---|
| [Godot Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)／[Visibility Ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) | 相機可用層遮罩隔離可渲染物件；距離可見與畫面遮擋不同。只在檢視時隔離，正式場景繼續一般深度。 |
| [Unity Layers](https://docs.unity3d.com/Manual/Layers.html) | 場景分組及編輯器隔離便於檢查，但物件被分到可見層不等於最後像素沒有被遮住。 |
| [Epic Visibility and Occlusion Culling](https://dev.epicgames.com/documentation/en-us/unreal-engine/visibility-and-occlusion-culling-in-unreal-engine) | 視錐、物件邊界與GPU遮擋是不同階段。原本僅測四角進入畫面仍不夠。 |
| [Three.js Layers](https://threejs.org/docs/pages/Layers.html) | 相機與物件共用層才會繪製；隔離參照必須保留並復原原遮罩。 |
| [PlayCanvas Layers](https://developer.playcanvas.com/user-manual/graphics/layers/) | 調整繪製順序不會自動略過depthTest。沒有為了讓角色永遠蓋到前景而關閉深度。 |
| [Joey de Vries：LearnOpenGL Depth testing](https://learnopengl.com/Advanced-OpenGL/Depth-testing) | 物件在螢幕內仍可能逐片段被丟棄；地板、幾何、透明來源與投影需分開比較。 |

## GPU檢視與反例

原有來源、足底保護、固定畫布、材質同步、鏡頭範圍、降低動態與恢復檢查保留。新增同一鏡頭、姿勢、光照下的三次讀回：正常場景、僅人物、人物也隱藏的空底。以人物／空底顏色差取得實際渲染範圍，再核對正常場景是否保有這些人物像素。專用檢視層若已被其他場景物件占用就失敗，完成後復原layer、visible及camera cull mask；不會把檢視狀態留到正式角色。新截圖與GPU報告跟隨獨立絕對SNAPLAND_SAVE_PATH，後續直接啟動檢視場景不再覆寫票內歷史圖。

目前參照遮罩取最大色差≥0.10的像素，正常圖與人物圖的最大色差>0.035視為被覆蓋，接受條件是範圍非空且被覆蓋數=0。它是固定相機與同光照的回歸方法，不是所有顏色、動態陰影或其他平台的通用可見性定理；仍須實際看畫面。只做物理射線會漏掉沒有碰撞的花葉與裝飾，因此未以射線代替這次讀回。

新站位的三種實際輸出尺寸與獨立PCK結果、舊站位反例、正常／四分之一速度演出及實際檢視範圍以[本批證據](../../pm/Snapland-art/images/ART-15-clearance-20261020-verification.json)為準。這是完整性局部驗收；主角慶祝仍顯示明確來源缺件警告並用完整內建姿勢安全回退，三位NPC的真正行走與完整作者動作繼續由ART-17驗收。本頁不把安全回退當成新完成的專用動作，也不代表Windows EXE、真人遊玩、完整連續觀看或聽感。
