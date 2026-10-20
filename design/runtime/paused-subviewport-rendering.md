# 暫停教學時保留 3D 子畫面

2026-10-20，MAIN-10。十三課素材更新後，原生完整生命週期在噴泉讀教學時超過原本每款六十秒的牆鐘限制。原始失敗保留；沒有延長正式測試期限。調查同時發現遊戲時鐘已凍結，但 3D 子畫面仍以 Always／When Visible 反覆繪製相同像素。

## 六個團隊的方法

| 原始來源 | 實際閱讀與採用 |
|---|---|
| [Godot SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html) | 原文的 Disabled、Once、When Visible、Always；暫停要求一張完整畫面，再保留原生紋理，恢復原先的更新政策。 |
| [Three.js：Rendering on Demand](https://threejs.org/manual/pages/rendering-on-demand.html) | 原文說明無變化時持續繪製會耗電；相機、資料、貼圖或尺寸改變仍須請求新畫面。採用明確更新事件，而非永久停止畫面。 |
| [Epic：UMG optimization](https://dev.epicgames.com/documentation/en-us/unreal-engine/optimization-guidelines-for-umg-in-unreal-engine) | 原文的 invalidation、Retainer Panels 與避免逐 Tick 輪詢。穩定畫面可保留，持續變化的遊玩仍正常繪製。 |
| [Unity：URP camera render order](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@14.0/manual/cameras-advanced.html) | 原文的 Render Texture／畫面相機順序及未初始化 color buffer 的平台差異。保留已繪製的完整紋理，不以未知 buffer 或空白替代。 |
| [PixiJS：Render Loop](https://pixijs.com/8.x/guides/concepts/render-loop) | 原文分開 Ticker、場景更新與 GPU drawing；只停止遊戲邏輯不等於 GPU 工作已停止。本作保留 UI 導航與焦點更新。 |
| [Babylon.js：Optimizing your scene](https://doc.babylonjs.com/features/featuresDeepDive/scene/optimize_your_scene) | 原文的 freeze／unfreeze 與 RenderTargetTexture 注意事項。恢復時必須讓原更新政策回來；不把凍結活動列表照搬成所有內容永遠不更新。 |

本輪閱讀文字與相關引擎原始碼，沒有觀看這些來源的影片或宣稱 SDK 整合。教學原有六方視覺參考另見 [MAIN-10 的參考圖與來源](tutorial-current-sources.md)。本輪畫面比較使用本作真正 GPU 輸出。

## 本作行為

暫停或讀教學時，先把暫停狀態送到畫面，再讓實際啟用的 SubViewport 更新一次；最後完整紋理繼續顯示。每款自己的解析度、光照、角色原畫與手腳不降級。已經 Disabled 的子畫面維持原狀。

正常暫停 Tick 不反覆把同一份狀態送給場景。明確的時段或版面變動仍能請求一次新畫面。繼續或重試會恢復各自的原更新政策，包括 Always 和 When Visible；重複暫停不把一次性狀態誤記成原政策。記錄使用弱參照，場景釋放後安全略過。2D 水流也在按下暫停時立刻停住，恢復後繼續。

## 真實量測與界線

同一引擎的噴泉、招牌、影子三款，經真站點入口、HUD 說明、關閉、恢復與確認離開。暫停前後的完整子畫面逐位元一致、回合時鐘不變，繼續後時鐘前進並恢復各自原政策；個別舞台仍為 1280×720。原生圖與輸入、模式、時間和計數紀錄跟隨隔離存檔保存。

引擎元件的 `get_update_mode()` 保留設定值。設定 Once 後，元件 getter 仍會是 Once；Render Server 在一次繪製後停止持續更新，不能期待元件值自動變成 Disabled。此行為已對照[引擎公開原始碼](https://github.com/godotengine/godot/blob/master/scene/main/viewport.cpp)，並以實際 4.7.2 的輸出核對。子視窗的 draw-call counter 同樣可能保留最後一次繪製的數字，不能把它讀成每個新影格都再次繪製。

第一次新診斷誤將 getter 當成 Render Server 的即時狀態，後一輪又直接比較教學 UI 與繼續後不同畫面的整幀工作量，兩輪都保留為拒收量測。最後診斷核對正確更新政策、真實完整像素、凍結時鐘與恢復；全幀計數只記錄，不把兩種不同 UI 硬算成節省百分比。軟體渲染的牆鐘數字不代表玩家硬體效能，也不代表試聽或動畫自然度。
