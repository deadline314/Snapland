# Snapland

以單人遊園為中心的HD-2D拍貼收藏遊戲，預留1–4人同機與P2P。当前交付階段是設計，沒有可執行Godot專案。

閱讀 [設計入口](design/README.md)、[需求票](pm/README.md) 與 [工作規範](AGENTS.md)。

## 局部驗證
python tools/verify_design.py --scope park
python tools/verify_design.py --scope games
python tools/verify_design.py --scope story
python tools/verify_design.py --scope items

完整可用驗證由GitHub Actions在變更及每小時排程執行；排程只在workflow合併預設分支後生效，並可能受GitHub排程延遲影響。這些是設計資料測試，不是Godot遊戲測試。
