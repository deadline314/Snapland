# 原生介面的視窗、縮放與證據

2026-10-20；ART-23–26；起始main `dd8318b`。沿用[七方UI研究](pixel-ui-redesign.md)，本輪重新檢視幻想水滸傳／歧路旅人靜態參考，不聲稱重玩作品。補讀[Godot Window](https://docs.godotengine.org/en/stable/classes/class_window.html)、[DisplayServer](https://docs.godotengine.org/en/stable/classes/class_displayserver.html)及[多解析度](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)的視窗所有權、實際大小與內容縮放。

第一次雲端介面工具雖回報DisplayServer為800／1920，但兩張暫停圖像素完全相同、輸出均1280×720。不是介面真的已跨尺寸通過。舊Windows證據另核對為800／1920實際圖，這項雲端行為不抹去舊證據。

現在透過Window設定size，核對Window和對應ID的DisplayServer都已改變，邏輯viewport仍1280×720，final_transform分別為0.625／1.0／1.5。每張PNG另記輸出尺寸，三種尺寸分別真實輸出800×450、1280×720、1920×1080。只改DisplayServer的真實反例會拒絕：請求800、Window1280、後端800，exit1；不延長原有時限掩蓋。

輸入位置以viewport final_transform轉到實際視窗，保留window ID、移動、按下、放開與事件緩衝。驗收繼續檢查真正字形行高、可見行數、固定按鈕和收藏／翻頁不重疊。新證據放獨立絕對存檔旁，再挑選並複製到票，避免改寫舊圖。

時段必須用既有專用setter，並核對Progress和世界實際狀態；通用數值設定會拒絕字串。要求值不是執行結果。1920夜間／降低動態已從真正場景核對，先前要求夜間卻留下中午的候選不算夜間通過。

最終三組原生界面各33張；十四項相關局部套件通過。工具直接開頁並使用隔離的合成照片和練習結算，沒有把它們當自然通關、玩家偏好或新素材品質。本輪只修改原生驗收工具，產品UI及角色來源保持；後續美術、教學照片更新仍依原票。
