# Snapland 需求票

| 資料夾 | 代號 | 範圍 |
|---|---|---|
| Snapland-main | MAIN | 園區、收藏、多人與共通框架 |
| Snapland-small-game | SG | 設施與小遊戲設計 |
| Snapland-story | ST | 主線、支線與探索故事 |
| Snapland-music | MIC | 音樂與聲音 |
| Snapland-art | ART | 美術與介面 |

各專案獨立編號；名稱格式與交付請讀 [.agents/skills/pm-ticket/SKILL.md](../.agents/skills/pm-ticket/SKILL.md)。截圖是交付證據，設計票的圖片為文件預覽而非遊戲截圖。

## 媒體保留

每張票預設只留一張必要的 PNG，不放影片、壓縮檔與原始紀錄。未結案票與各專案最近五張完成票保留媒體；更早的完成票由 `python tools/prune_pm_media.py --apply` 精簡，連結改為文字，舊媒體可從 git 歷史取回。先不加 `--apply` 可預覽會移除的數量。

[最新逐票未結案清單](open_tickets.md)收錄 125 張票，其中 118 張完成、6 張未結案、1 張封存。

## 本輪需求
- MAIN-1：重整園區與收藏玩法。
- SG-1：重設小遊戲樂趣目錄。
- ST-1：重整主線與園區支線。
- MAIN-2：建立設計驗證與定時CI。

設計內容由 [設計入口](../design/README.md) 閱讀；完成票只代表其驗收範圍完成，不代表遊戲已實作。
