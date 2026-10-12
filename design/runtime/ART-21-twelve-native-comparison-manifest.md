# ART-21 原生畫面比較圖來源清單

- 基線：乾淨提交 `049d58a`；Hat Rescue v13 更新來自提交 `f2919ac`，目前可見於 HEAD `0819747fc25198ab891b54a55fc82bfe6f109d0f`。
- 輸出：`pm/Snapland-art/images/ART-21-twelve-native-comparison.png`（1880×2000 PNG；3 欄 × 4 列）。
- 十二張來源均為專案 `pm/Snapland-small-game/images/` 下的已提交檔案；沒有使用 `.review` 外部來源。原生畫面均為 1280×720，依比例完整縮放，未裁切。
- 媒材分類依已審 renderer／scene-node；3D 分類精確為 game-001、game-003、game-004、game-009（共四款）。
- 比較既有原生畫面，不代表目前 Main 版本的十二款 GPU 試玩已全數完成或通過。
- SG-25 泡泡拍貼採 v2 相機截圖，對應 Photo checkpoint `80ca160`。
- SG-20 帽子救援採已提交的 v13 截圖，對應 Hat checkpoint `f2919ac`。

- 比較圖 SHA-256：`fb12a1a44b8155d58dba514a7b9095428d877f767fb0103c75b2dee74d304cc0`

| ID | 遊戲 | Renderer／scene-node 媒材 | 主要操作 | 原始來源 | 狀態 | 原始 SHA-256 |
|---|---|---|---|---|---|---|
| game-001 | 氣球快遞 | 3D 港灣模型 | 方向鍵／WASD／滑鼠；Space 煞車 | `pm/Snapland-small-game/images/SG-16-flight.png` | checkpointed at 049d58a | `358b5be1bcaea252152773851743853d2a52ab3fe06a55783f8814c66cb7964a` |
| game-002 | 風箏穿環 | 2.5D 側向航線 | 滑鼠／↑↓ 調角；Space 衝刺 | `pm/Snapland-small-game/images/SG-17-kite-flight.png` | checkpointed at 049d58a | `eae779de5174b8ec5b7fc98043c38aaebac958025274826739aec6fdca4fd85c` |
| game-003 | 噴泉跳拍 | 3D 噴泉跳台 | Space／點擊起跳 | `pm/Snapland-small-game/images/SG-18-3d-airborne.png` | checkpointed at 049d58a | `860ab7267ca8d5dc667384b232e9d92a1d45f4901aeb3b8156b689a6c83d1b1c` |
| game-004 | 人潮指揮 | 3D 路口模型 | Q／E 或點號誌 | `pm/Snapland-small-game/images/SG-19-spatial-crossing.png` | checkpointed at 049d58a | `1e28016c0948546a23e29da429b23ee21c8f920a0eda0b114ddac7258352f32e` |
| game-005 | 帽子救援 | 2D 橫向接物 | ←／→ 或滑鼠走位 | `pm/Snapland-small-game/images/SG-20-hat-v13-tutorial-02.png` | Hat checkpoint f2919ac (present at HEAD 0819747) | `020ac595b08282c8a6e695709f082808c4f049a7983dc6cc117db268afe8cc9f` |
| game-006 | 彩帶節拍 | 2D 舞台 | ←／→／Space；揮帶需按住 | `pm/Snapland-small-game/images/SG-21-hold.png` | checkpointed at 049d58a | `6ebf7173c5fad63c647bb33ee4e5d280345eb1e1167b5909b7e4d107b88715a5` |
| game-007 | 花壇水路 | 2D 俯視水路 | 方向鍵／Space 或點擊 | `pm/Snapland-small-game/images/SG-22-pipe-plan.png` | checkpointed at 049d58a | `dee4fc68168ab41da5694d00ce76f7272a7bf25ea9f4fea4fffe7f2dfcdad5ac` |
| game-008 | 招牌平衡 | 2D 機械近景（手繪透視） | ←／→ 配重／拖曳 | `pm/Snapland-small-game/images/SG-23-weight.png` | checkpointed at 049d58a | `b01f61363218f428f6e35bf9bb12977ea3011860e7d5f70c6ddc0c017e082c28` |
| game-009 | 影子捉迷藏 | 3D 實際燈光投影 | 方向鍵／Shift 細調 | `pm/Snapland-small-game/images/SG-24-formal-cast-1.png` | checkpointed at 049d58a | `a3ba0d2acbcad42cc6e7b01db49c6679bcb5031fc017f4417feef5c5c208b453` |
| game-010 | 泡泡拍貼 | 2.5D 取景視差 | 方向鍵／滑鼠移框；Space 快門 | `pm/Snapland-small-game/images/SG-25-camera-v2.png` | Photo checkpoint 80ca160; present at 049d58a | `1e751a722286ce7fa97afbc144d88680fa34fffbd481af3554579159058fa9e7` |
| game-011 | 長椅換位 | 2D 透視桌面 | 點兩席／按 1–6 | `pm/Snapland-small-game/images/SG-26-formal-table-1.png` | checkpointed at 049d58a | `ace703a3335740bf7d98462b96203d61f15ebdceee535e6648e08017f534a466` |
| game-012 | 迎賓大合奏 | 2D 樂器盤 | 1–4／A–F 或點擊 | `pm/Snapland-small-game/images/SG-27-perform.png` | checkpointed at 049d58a | `9cb46317fbdca24e833bfb92c919c30c171214f79304be0ae48dd73788cd3a21` |
