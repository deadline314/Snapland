# 設計驗證與完整可用CI

需求票：MAIN-2。所有命令使用Python 3.12標準函式庫，沒有外部套件或Godot安裝依賴。

## 提交前局部命令
| 變更 | 命令 |
|---|---|
| 園區/門檻 | python tools/verify_design.py --scope park |
| 128款小遊戲 | python tools/verify_design.py --scope games |
| 任務/探索 | python tools/verify_design.py --scope story |
| 物品 | python tools/verify_design.py --scope items |
| 連結/截圖 | python tools/verify_design.py --scope links |

validator本身有變更時執行 python -m unittest discover -s tests -v。完整套件執行五個scope、validator反例與runtime覆盖检查。

## 自動執行
GitHub Actions在相關變更push、所有pull request、手動workflow_dispatch、每小時UTC第17分鐘執行完整可用套件；台灣時間亦為每小時第17分鐘。排程是GitHub best-effort，可能延遲；排程只讀預設分支，feature branch的排程檔合併main後才生效。每小時不重新開需求票或建立新commit。
程式觸發涵蓋GDScript、C#、場景、資源、addons、src/game/assets与project.godot；即使新檔在其他目錄也以副檔名觸發。加入Godot專案/執行檔後，runtime覆蓋檢查先失敗，要求補實際遊戲測試，避免把設計測試當遊戲全套。

## 檢查什麼
- 編號、128數量、12/8園區分配、六種樂趣、欄位、來源與完全相同操作/目標/取捨。
- 180/120收藏、分組門檻可達、第一組可不靠設施開放、終區不要求惡魔收藏。
- 二十支線、三十探索、五十獎勵資格覆蓋、同區前置與依賴無環。
- 339個Steam相容樣本定義、ID、分類、固定來源與遊戲映射、交易旗標。
- 文件本機連結與截圖存在，不訪問所有外站。

## 不代表什麼
完全相同字串檢查不等於已證明128種原創或全部好玩。資料無環不等於已實機走完任務。人工一致性審查與六款陌生玩家原型試玩仍必要。本輪截圖是實際瀏覽器中的文件預覽，不是Godot畫面。
