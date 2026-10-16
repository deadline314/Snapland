# 島上 2D 待機與髮尾整合

2026-10-16。承接使用者明確順序：ART-32 穩定待機／眨眼 → ART-33 微風短髮接島 → ART-34 其他現有髮型。

沿用原畫、固定畫布及已審核的頭部所有權。原專用待機頭身比例與行走不合，直接拼接的首版在近看時拒收。待機改用以步行原畫為嚴格參考的同畫風完整站姿，保留原行走頭頸並固定共用地面；眨眼借原閉眼眼部來源。胸肩呼吸限一像素，位移權重在脖子與骨盆為零，雙腳不動。變動範圍明列並驗證，禁止重新按每格鞋子置中。先保存失敗基準與全身／近看再製作。

髮尾沿用真實 Skeleton2D／Bone2D 的受保護根點和有界彈簧。島上人物仍為原本 2D billboard；骨架僅處理髮尾。透過透明 2D 合成輸出保留既有世界光影、遮擋與角色比例，靜止合成須與原畫逐像素對照。共用島上實際移動、暫停及降低動態，不另起動畫時鐘。姿勢、方向、帽子或髮型切換必須重設不相容慣性；停止後自然收斂。

通過原生正常與真正四分之一模擬速度、固定參考線、根部／帽子受保護像素與全身來源比較後，才採用下一款髮型。不能把來源檢查當真人試玩，不能跳過失敗或使用未提交候選。


## 待機重建

```text
python tools/island_avatar/export_sources.py .review/island-idle-rebuild-source
python tools/island_avatar/register_standing.py assets/characters/traveller-idle-standing-v3.png .review/island-idle-rebuild-source
python tools/island_avatar/build_idle.py .review/island-idle-rebuild-source assets/characters/idle-stability-v1
python tools/island_avatar/check_idle.py assets/characters/idle-stability-v1
```

站姿生成使用 built-in image_gen；原始輸出、完整提示詞、參考、雜湊與登錄資料保存在 `assets/characters/traveller-idle-standing-v3-provenance.json`。它是原本 2D 原畫的站姿修復，沒有建立人物 3D 模型。首版被拒收的水平接縫另有證據；素材測試加上舊下巴殘留、非眨眼眼部改動、腳部一像素偏移等負例。
