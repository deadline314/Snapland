# ART20／ART21｜紙本介面的偽 3D 深度調查與實作基線

## 研究範圍與實際閱讀紀錄

我實際開啟並閱讀下表列出的正文段落／手冊文字。來源頁面的示意圖與遊戲截圖沒有逐張檢視，文章內影片沒有播放；因此以下結論取自文字，不宣稱看過它們呈現的像素或動態細節。

| 第一手來源 | 已讀內容 | 可轉用的具體規則與採用邊界 |
|---|---|---|
| Apple Human Interface Guidelines，[Materials](https://developer.apple.com/design/human-interface-guidelines/materials) | 「Materials」正文說明材料用來區分前景控制與背景內容，並提醒保持文字對比；搜尋結果所呈現的官方正文段落已實讀，網頁圖例未檢視。 | 先把控件與內容分層，再選擇材料；本作卡片保持不透明紙色，避免透底降低墨字可讀性。沒有搬用 Liquid Glass。 |
| Apple Human Interface Guidelines，[Motion](https://developer.apple.com/design/human-interface-guidelines/motion) | 「Best practices」「Providing feedback」正文：動態應服務資訊、不應為裝飾而動、應允許停用、回饋須短而精準。官方正文段落已讀，示意圖／影片未看。 | 旅券的紙層採靜態陰影；按鈕狀態只瞬時改變樣式，不加入進場、漂浮或反覆擺動。提供 reduced-motion 狀態 API，讓主程式可讓任何可選過場歸零。 |
| Microsoft Fluent 2，[Elevation](https://fluent2.microsoft.design/elevation/) | 正文第 8–40 行談深度、固定光源方向、近處銳利與遠處柔化、key/ambient 影的差別。 | 全介面光影方向固定為右下；一般卡片用短小淡影，較高層彈窗才用較寬柔影。沒有照搬 Fluent 數值或陰影美術。 |
| Microsoft Windows Apps，[Layering and elevation](https://learn.microsoft.com/en-us/windows/apps/design/signature-experiences/layering) | 正文第 31–40、101–120 行：層級先用來讓人理解導航與重要性；影子和輪廓共同表示高度；過度用影會製造噪音。 | 只保留基底、一般卡片、互動按鈕、模態這些少數層級；當前共用 helper 只加卡片紙邊和按鈕狀態差異，不給每張內容卡不同陰影。 |
| Google Android Developers，[Add shadows in Compose](https://developer.android.com/develop/ui/compose/graphics/draw/shadows) | 正文第 155–165 行區分預設 elevation shadow、可調 drop shadow 和內陰影，指出陰影可提示互動並回饋動作。程式片段正文已讀；沒有用其截圖作比對。 | 選用 Godot 已有 `StyleBoxFlat` 的單層陰影；不堆多層陰影或內陰影，避免旅券變成塑膠／霓虹質感。 |
| Godot Engine，[StyleBoxFlat](https://docs.godotengine.org/en/latest/classes/class_styleboxflat.html) | 正文第 253–288 行：`shadow_color`、`shadow_offset`、`shadow_size` 語義，以及 expand margin 不會擴大 Control 點擊區、應以 content margin 保護文字。 | 直接調現有 StyleBox 的 shadow 與底邊；不使用 expand margin 製造外擴假厚度，保留既有 Control 點擊矩形和內容邊距。 |
| Nintendo 團隊訪談，[Interview: Super Paper Mario](https://www.nintendo.com/en-gb/News/2007/Interview-Super-Paper-Mario-249673.html) | 正文第 92–97 行：製作人 Kensuke Tanabe 與首席遊戲設計／導演 Ryota Kawade 說明「紙」概念和 2D／3D 切換是遊戲機制的表現方式。 | 只借鑑把紙面層次當作介面語法的概念；不複製角色剪影、折紙圖案或其 2D／3D 轉換。Snapland 用郵戳、票券邊和頁片層表達港口身份。 |
| Nintendo 官方《Super Paper Mario》Wii 電子手冊，[PDF](https://csassets.nintendo.com/noaext/image/private/t_KA_PDF/Wii_Super_Paper_Mario?_a=DATAg1AAZAA0) | 第 2–3 頁手冊文字（PDF 正文第 311–423 行）：分辨 Score／HP／Coins／Flip Meter；選單標籤、角色資訊、物品、卡片、地圖、章節分區。 | 收藏資訊採明確分類與可讀文字標籤；裝飾不得取代名稱、狀態或分類。參考其資訊分組，不複製選單外觀或遊戲圖像。 |
| Housemarque，《Returnal》UX 設計，[PlayStation Blog](https://blog.playstation.com/2021/05/11/unpacking-returnals-ux-design-gameplay-first-ui-retro-futuristic-tech-and-accessibility/) | UI/UX Director Johannes Koski 的正文第 56–64 行：UI 須支援玩法與美術；移除秒級玩法干擾；最重要訊息靠近焦點，次要資訊放邊緣。 | 遊戲世界中的操作提示保持小而近，旅券／衣櫃才承載較豐富紙本細節。不能因追求「有層次」而讓 HUD 變大或增加常駐容器。 |

## 本作的層級與材質規格

### 小視窗的閱讀驗收補充（2026-10-12，主 Session 實讀）

- [Godot Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)：已讀 Base size、Canvas Items、Stretch Aspect、Stretch Scale 正文。設計解析度不等於實際視窗像素；Canvas Items 會按 stretch/aspect 縮放 UI，Keep 可產生黑邊。本作保留遊戲的座標基準，選單按最終縮放補償文字與點擊尺寸。這是本作的選擇，並非官方指定做法；頁面動畫未播放。
- [Microsoft XAG 101](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101)：已讀 Measuring text size、minimum sizes、Icons and glyph sizes、Text scaling 正文。指南要求檢查實際呈現的字高，並在放大後保留內容、功能與單向捲動。本次以實際視窗變換和原生截圖檢查；字型設定值只作預檢，不能替代字形閱讀驗收，也不宣稱符合整份 XAG。

原生 800 像素寬畫面曾把 13 邏輯像素站點字縮成約 8 像素，屬驗收失敗。新版將主要點擊範圍、正文和次要文字按實際縮放補償；放大後的內容需要垂直捲動與固定返回入口，不能用縮回字體來掩蓋超出畫面的問題。

這不是把整個介面改成三維視窗。海港紙本世界的偽 3D 只用薄紙厚度、同向陰影和按鈕按下的接觸變化來表達可操作性。

| 層級 | 使用位置 | 紙邊／陰影規則 |
|---|---|---|
| 紙面底層 | 旅券／對話／衣櫃等主要容器 | `Paper.box` 使用二像素柔影、右下 `(2,3)` 偏移與三像素底邊；表示紙張放在桌面上，不擴大 Control 點擊區。 |
| 卡片頁片 | `Paper.plaque` 與 `Paper.card` 共用內容卡 | 底邊五像素、四像素柔影、右下 `(2,5)` 偏移；卡片填色維持霧面米白／淡砂色。維持現有內距。 |
| 可點按鈕 | 所有 `Paper.button` 呼叫 | 普通狀態三像素影、四像素底邊；hover 五像素影和稍大的同向偏移；pressed 即時落回零影並縮成兩像素底邊。字色、44px 最小高度、focus outline、pressed callback 和節點尺寸不變。 |
| 焦點 | 鍵盤 focus | 現有金色三像素輪廓獨立保留，不以陰影替代焦點，也不遮蓋文字。 |

不再加裝飾用空 Control、不使用 expand margin、不在每影格建立 stylebox、不增加持續飄浮／翻頁動態。這些限制讓陰影不攔截點擊，也不會引入新的命中區域或節點生命週期。

## Reduced motion hook 與整合

`Paper.set_reduced_motion(enabled)` 保存主程式目前的偏好，`Paper.reduced_motion()` 可讀取；若未來呼叫者要加短過場，可用 `Paper.motion_duration_seconds(requested_seconds)`，降低動態啟用時回傳非負輸入、停用動態時回傳 `0.0`。本次偽 3D 靜態樣式不需要過場，因此偏好開／關下陰影一致，避免設定切換令元件位移或改尺寸。

主程式在讀取設定、以及使用者切換設定後呼叫：

```gdscript
Paper.set_reduced_motion(bool(Progress.settings.get("reduced_motion", false)))
```

驗收應確認呼叫後 `Paper.reduced_motion()` 對應儲存值、`motion_duration_seconds(0.12)` 在開啟時為零；靜態 Theme 預設不建立 Tween 或逐影格資源。此工作不修改主程式，並且沒有 GPU 畫面驗收；單元／整合測試通過也不等同確認陰影實際畫面品質。

## ART20 地圖、收藏簿與成就印章實作

地圖以獨立 2.5D 港島圖承載目的地，陰影下層右移形成可見島岸厚度，珊瑚色路徑串起碼頭與迎賓大道。十二個遊戲站點都有可聚焦的編號控制；其他九座園區畫成衛星入口，直接顯示現有普通拍貼門檻和「準備中」。選取只更換地圖下方的目標說明；不傳送角色，也不表示尚未實作區域已開放。

收藏簿使用暖色封面、左／右紙頁底色、中間書脊溝線與六張一頁的翻頁網格。普通 18 張、小惡魔 12 張、四時明信片 4 張各自成分類；普通和小惡魔卡片使用現存 photo ID，時段卡使用 `TimeOfDay.postcard_id()`。只在原記錄含可讀影格時顯示縮圖；已收藏但影格遺失時保留「照片檔未讀取」提示，未拍格子顯示拍攝方式。零收藏時另顯示明確的第一張照片引導。每張卡依收藏數據顯示狀態，不增加獎勵或修改計數。

成就以編號雙圈印章表達 12 款正式遊戲初次完成，另將迎賓全通關、迎賓小惡魔、全島 120 張與四時明信片分組顯示現況／門檻。渲染沿用原有 IDs 和文字條件，不改 `Progress` 或 Steam 同步定義。新 UI controls 測試在 800×600 和 1280×720 檢查地圖控制是否留在地圖畫布內；原 integration 與衣櫃鍵盤焦點測試仍獨立通過。畫面仍需 root 以原生 GPU 截圖人工檢視，本地 headless 測試不代表視覺驗收。
