# 畫面打磨研究

2026-11-27。為 ART-39 到 ART-53、MAIN-51 所做的網路研究摘要。以下是閱讀來源後的整理與對 Snapland 的應用判斷，不是遊戲試玩結果；標「未驗證」者尚未在 Godot 4.7.2 實跑確認。

## 現況量測（1920×1080，RX 9070 XT，同一台機器）

| 視點 | 每幀 | 繪製數 |
|---|---:|---:|
| 迎賓碼頭、廣場、大道（白天） | 2.2–2.3 ms | 1100–1860 |
| 迎賓廣場（夜晚） | 8.5 ms | 2047 |
| 其他六區 | 約 1.8 ms | 150–510 |
| 換區 | 凍結約 3.1 秒 | — |

白天成本很低，夜晚約四倍（燈具陰影），換區凍結需要轉場遮蔽。其他六區的節點數只有 190–560，場景內容明顯不足。

## 採用的做法

1. **看板貼圖融入場景**：貼圖要受光並共用時段色調；腳下要有接地陰影；影子用自己的剪影投出。固定鏡頭下看板可以一次轉向鏡頭，影子才不會歪。
2. **水面**：用同一個水深值同時控制顏色、泡沫與邊緣淡出；泡沫用兩層反向捲動的噪聲加硬切，高光硬切成亮點。Godot 4.3 起深度是反向的，要先還原到視圖空間再比較。
3. **風**：用世界座標取樣噪聲，鄰近植物不同步但共享同一片陣風；高度遮罩讓根部不動；玩家位置用全域參數傳入，靠近時把植物推開。
4. **讓單張背景活起來**：遮罩驅動的單一畫布著色器（搖擺、水波、燈光閃爍分區）、純程式的光束疊層、少量飄塵粒子、遠近層微幅視差。
5. **環境生命感**：每區 3–4 組低數量粒子（塵、葉、螢火、蒸氣），生命週期內隨機化大小與速度；時段切換粒子種類。
6. **光照**：泛光只讓發光體過門檻，避免像素圖泛白；環境遮蔽可半解析度；方向光陰影距離越短越清楚也越省；固定鏡頭可減少陰影分段。抗鋸齒只用不會模糊像素圖的多重取樣。
7. **效能**：批次繪製重複物件；特效在場景建立時先放一個隱藏實例預熱著色器；畫質切換只在設定畫面做。
8. **介面手感**：補間不可重用，重播前先停掉舊的；進場用緩出、離場用緩入、小回彈用 Back；軸心用比例置中；提示文字要短、滑鼠與鍵盤焦點都要觸發。
9. **小遊戲回饋**：震動用「創傷值」模型（位移乘創傷的平方，輕擊幾乎不動）；命中停格 60–120 毫秒；受擊閃白約 0.12 秒；落地壓扁再回彈；音高微幅隨機。
10. **減少動態**：鏡頭晃動、背景動畫與閃爍都必須可關閉。

## 不採用或暫緩

- 景深與移軸模糊：正交鏡頭下效果不穩，且會糊到像素角色，暫不採用。
- 體積霧：成本高，改用高度霧與霧面疊層。
- 螢幕折射水面：需要螢幕拷貝，內顯成本高，先不做。

## 來源

- Godot 文件：[SpriteBase3D](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html)、[Decals](https://docs.godotengine.org/en/stable/tutorials/3d/using_decals.html)、[Spatial shader](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)、[Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)、[Environment and post-processing](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)、[Lights and shadows](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html)、[3D antialiasing](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html)、[Pipeline compilations](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)、[GPU optimization](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)、[MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)、[Visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)、[2D parallax](https://docs.godotengine.org/en/stable/tutorials/2d/2d_parallax.html)、[Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html)、[Control](https://docs.godotengine.org/en/stable/classes/class_control.html)
- [Introducing Reverse Z](https://godotengine.org/article/introducing-reverse-z/)、[Global and instance shader uniforms](https://godotengine.org/article/godot-40-gets-global-and-instance-shader-uniforms/)
- 水面：[ameye.dev stylized water](https://ameye.dev/notes/stylized-water-shader)、[godotshaders water with foam and depth](https://godotshaders.com/shader/water-with-foam-and-depth/)
- 風與草：[hexaquo grass series part 3](https://hexaquo.at/pages/grass-rendering-series-part-3-animating-and-interacting-with-grass-in-godot/)、[2D pixel-perfect wind sway](https://godotshaders.com/shader/2d-pixel-perfect-wind-sway-effect/)
- 背景光束：[god rays shader](https://godotshaders.com/shader/god-rays-shader-inspired-by-pend00-godot-4-5/)
- 2D 融入 3D：[HD-2D](https://en.wikipedia.org/wiki/HD-2D)、[Eastward 開發者分享](https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures)、[A Short Hike 幕後](https://blog.playstation.com/2021/08/05/crafting-a-tiny-open-world-a-look-behind-the-scenes-at-the-creation-of-a-short-hike/)
- 手感：[KidsCanCode screen shake](https://kidscancode.org/godot_recipes/4.x/2d/screen_shake/index.html)、[Squeezing more juice out of your game design](https://www.gameanalytics.com/blog/squeezing-more-juice-out-of-your-game-design)
- 無障礙與提示：[Xbox Accessibility Guideline 117](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117)、[NN/g tooltip guidelines](https://www.nngroup.com/articles/tooltip-guidelines/)

未能讀到內文、只取得摘要的來源（《Juice it or lose it》《The Art of Screenshake》、Octopath 的 Unreal 訪談）沒有列為依據。
