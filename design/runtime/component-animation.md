# 部件動畫與待機：多來源比較

使用者要求背景、建築、服飾與每位角色依用途有合理動畫或效果，且研究至少六個來源、比較不同方向。下列七個來源已閱讀網頁實際內容；影片沒有播放，不宣稱看過示範影片。

| 來源 | 實際看到的內容 | 本作選擇與原因 |
|---|---|---|
| [Godot AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html) | 動畫播放器、混合節點、狀態機及軌道過濾 | 採原生 AnimationPlayer 管理環境軌道；目前姿態離散，不先增加骨架混合圖 |
| [Godot 共享與個別 shader uniforms](https://godotengine.org/article/godot-40-gets-global-and-instance-shader-uniforms/) | 共享風向與風力可驅動不同物件速度和幅度 | 共用動態設定，植栽根部固定、上部隨風；元件有相位差 |
| [Unity Sprite Skin](https://docs.unity.cn/Packages/com.unity.2d.animation@10.0/manual/SpriteSkin.html) | 骨架與權重使圖片局部變形；CPU/GPU 路徑各有批次與平台限制 | 採局部權重概念，衣襬、髮梢與胸口分區；本批仍保留清楚像素姿態，沒有改用 Unity 或宣稱已有骨骼權重素材 |
| [Fortnite 開發者技術文章](https://www.unrealengine.com/tech-blog/bringing-nanite-to-fortnite-battle-royale-in-chapter-4?lang=en-US) | 植栽分枝支點、風場查表、遠距停止動態；建築受擊效果按需啟用 | 依支點、可見距離與用途控制次級動態；本作量級較小，先採簡單 shader 與原生軌道，沒有引入 Nanite 或模擬烘焙工具 |
| [Dead Cells 美術作者 Thomas Vasseur](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-) | 先讓關鍵姿態與節奏成立，再加輔助幀；3D 工具協助快速重做並烘成像素 | 採關鍵姿態先驗收、可快速改時間；本批使用原創像素圖集，未完成或宣稱使用 3D 烘焙 |
| [Aseprite 動畫標記](https://www.aseprite.org/docs/tags/) | 把一段幀標成有名稱的動畫，可管理循環 | 圖集以明確方向與動作命名，步行與一次性动作分開；保留換素材接口 |
| [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/avoid-any-sudden-unexpected-movement-or-events/) | 非玩法必要的大幅突發動態或聲音可能造成困擾 | 環境動態緩慢、無高頻閃光；降低動態統一關閉裝飾動態，必要操作回饋與清楚角色姿態仍保留 |

## 本作整合

固定建築以棚布、吊牌、窗戶暖光和周邊物件呈現生活感；布旗與衣襬使用固定縫線支點，植物根部固定，水面漣漪與噴泉流動。沒有套用所有物件同一種浮動。

主角呼吸穩定、髮梢與衣襬有微風；票票節奏從容、偶爾整理衣服；小角節奏較快、歪頭与尾巴靈活；阿浪緩慢點頭並看向路口。各角色基準腳底固定，呼吸影響胸口，不整個人漂浮。角色表情与行为要原生視覺驗收。

元件動畫管理以原生 AnimationPlayer 軌道、材質參數和少量明確角色狀態組合。新部件只需註冊用途與預設，不每影格建立 Tween、圖片或物件；場景退出清理軌道，錯誤註冊記位置並跳過。碰撞與地基保持穩定。

截圖證明姿態與畫面，短原生錄影證明時間上的動畫；資料檢查與 headless 不等於已看見動畫。
