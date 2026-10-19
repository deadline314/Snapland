# 像素字體與多語系基礎

2026-10-14，MAIN-19／ART-27，固定開始基準 `bbba056`。

## 本次設計

介面的預設字體採 Fusion Pixel 12px 比例版，繁中選台灣字形，拉丁、日文、韓文保留對應地域版。主要文字維持既有可讀尺寸，實際檢查新字面、行高、換行與較大文字；不靠縮小文字塞回版面。另保留 Noto 的清晰閱讀選擇及獨立後備。字型原始檔、版本、雜湊與授權見 [來源清單](../../assets/fonts/font-provenance.json)。

使用 Godot 原生 TranslationServer 管理文字呈現，語系清單及詞條獨立於遊戲程式。新詞條有穩定識別與完整句子，變數使用具名欄位，譯者可調整語序。角色、任務、物品、拍貼與存檔識別維持原資料值。既有原文字串保留為遷移的安全來源，原生 Control 可使用已登錄詞條的來源別名。

對外只有完成發布條件的繁體中文。英文與不同文字方向的資料用於隔離驗收，未表示全作已翻譯；正式語言清單不列出未完成的語系。這是為後續翻譯提供基礎，並非英、日、韓、阿拉伯語全內容交付。

設定新增「語言與文字」分類，保留固定主要操作，讓聲音、畫面與操作頁的資訊密度維持合理。更換呈現時沿用當前節點及原生翻譯通知，保留選單分類、焦點、對話行與揭字進度；字體更新以事件觸發，繪圖期間直接取已準備的資源。

## 實際參考與取捨

| 第一手來源 | 實際查閱內容 | 本作採用／取捨 |
|---|---|---|
| [Fusion Pixel](https://github.com/TakWolf/fusion-pixel-font)／[作者展示](https://fusion-pixel-font.takwolf.com/) | 8／10／12px，比例版較自然；繁中與台灣、日、韓、拉丁等地域字形；字體 OFL，建置程式 MIT。 | 選固定 2026.09.25 的 12px 比例版。實際下載包的原始 OFL 與 Ark、Cubic、Galmuri 子授權一併保存；不把程式的 MIT 誤認成字型授權。 |
| [Cubic 11](https://github.com/ACh-K/Cubic-11) | 開源繁中點陣體，OFL；作者保留名稱。 | 繁中字形方向適合本作，Fusion 的 12px 發行包已含相關來源及子授權；不另混入不同基線的獨立字型。 |
| [Galmuri](https://github.com/quiple/galmuri) | 韓文像素字體、多種尺寸與限定字符集，OFL。 | 參考韓文與多文字的像素呈現；使用 Fusion 韓文地域版及其已附子授權，不因「CJK」名稱推定所有字符都齊全。 |
| [Ark Pixel](https://github.com/TakWolf/ark-pixel-font) | 字形仍在建置；10／12px 引用 Fusion 作暫時方案，OFL。 | 採成熟的 Fusion 發行包；缺字仍有明確後備。 |
| [GNU Unifont](https://unifoundry.com/unifont/) | 廣範圍 Unicode 覆蓋；不同發行的授權與字型例外需逐版核對。 | 保留為廣字集方案參考；本次用既有 Noto CJK 與針對性後備，避免增加另一套大範圍字體。 |
| [Godot 字型與後備](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html)／[FontFile](https://docs.godotengine.org/en/stable/classes/class_fontfile.html) | 字型後備、反鋸齒、MSDF、子像素與匯入選項；固定尺寸縮放只適用相應 bitmap font。 | Fusion 本次是 OTF 輪廓發行檔；像素模式停用平滑與 MSDF，不把 bitmap-only 設定硬套到 OTF。清晰模式使用正常平滑；資源有界快取，系統字型不作驗收依賴。 |
| [Godot 國際化](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html) | 原生翻譯通知、語系、字型後備、文字方向與複數形；偽本地化不能代替真 CJK／RTL 檢查。 | 使用資料詞條、完整句子及原生翻譯與 [Translation 複數規則](https://docs.godotengine.org/en/stable/classes/class_translation.html)，實際測繁中、長英文與 RTL 混合數字。不同語系正式發布另有翻譯與畫面條件。 |
| [SIL OFL 官方](https://openfontlicense.org/) | 字型隨軟體散布、原始授權及保留名稱規範。 | 原字型不改名或改輪廓，附授權與來源；使用者的 CC0 限制適用音樂音效，字型採其合法 OFL。 |

參考截圖見 ART-27 票，僅作研究與審閱，不當成遊戲畫面或本作素材。

## 字形、後備與版面

四款 Fusion 原檔各有 36,999 個 cmap 字符。最新靜態盤點涵蓋介面、資料與主場景文字共 975 個不同字符；主字體仍有部分標點、星形符號及阿拉伯文字缺字，因此加入已隨遊戲攜帶的 Noto CJK、Noto Arabic 和 Noto Symbols 2。三種後備合併後涵蓋此快照全部字符。這是目前資料快照，非全 Unicode 支援承諾；真正的字形選取、連字與可見內容另作 Godot 及原生驗收。

平常介面優先免捲動，長資料採既有分類、分頁及對話。以 800×450、1280×720、1920×1080 與 1.25 文字大小檢查主要頁面；字框數值、字形可用性與實際畫面分別記錄。不同字體的標準字級不保證相同行高或行數，需檢查完整可見內容。

## 驗收範圍

新增語系、字體、授權及偏好驗證，並重跑受影響 UI 與主場景局部測試。原生截圖包括設定、暫停、對話與分頁字體樣本；舊有全介面驗收也需在新預設字體下重看。英文／RTL 樣本是文字與排版 QA；地圖的實際探索、角色動畫、日夜混音與十二款獨立配樂仍有各自的票及實際驗收，不由此文字工作代替。

## 字型度量與相容性修正

原生回歸確認 [Godot Font 實作](https://github.com/godotengine/godot/blob/4.7/scene/resources/font.cpp) 會把所有後備的最大上升／下降量納入行高，即使該行沒有使用後備字形。24px 繁中／拉丁主字體原生行高為 32，加入所有後備後變成 51，曾擠出固定介面。以 [FontFile 的 raster cache 度量介面](https://docs.godotengine.org/en/4.7/classes/class_fontfile.html) 約束每個 locale profile 的後備行距，保留字形、字寬與原始檔；阿拉伯主字體仍使用原生 51 行高。覆蓋有界的 1–128px 字級，繪圖只讀已準備資源。

換字體後同時重查真正完整句子的分行：成就卡依可用高度分頁，試衣鏡刪除重複的即時預覽標題；不靠縮小文字或裁切條件句塞入。按鈕立體邊緣留在自己的繪製順序內，後開的對話與遮罩可正確覆蓋。

## 2026-10-20 全字形與高行距回歸

重新盤點 75 個正式程式／JSON（排除測試及 Unicode 格式／組合字控制），共 1025 個非 ASCII 字符。初次查出三個隨附字體沒有的符號：長椅訪客標記、靠窗規則及園區徽記；改用現有合法字型中的波紋、窗格及六角形，玩法與身份識別不變，最終字集聯集 0 缺字。這不是全 Unicode 支援。

字集聯集仍不足以證明每個 locale profile：實際 Godot 回歸另外抓到 pixel RTL 缺少錨與齒輪。該 profile 現在加入已攜帶的 Fusion Latin 後備；不依賴作業系統字型。原 30 項字型斷言保留，另以正式訪客標記、靠窗規則及世界徽記在五個語系 × 兩種風格驗證，共 40 項；完成契約跟隨新增計數，沒有降低字級或篡改原行高度量。

已重讀 [Godot Font](https://docs.godotengine.org/en/stable/classes/class_font.html) 的覆蓋與行高，以及 [Using Fonts](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html) 的後備、授權及繪製尺寸；沿用上文八方研究與原始 OFL 字型。實際符號原生圖另外核對十種 profile，包含 QA RTL。

原生審閱另發現高行距 RTL 在 1.25 文字下把暫停操作擠出底部。維持主要文字、九個入口、繼續與離開按鈕，將兩個用途群組內部依實際行高重排；窄視窗優先顯示操作，收起重複的側邊狀態與保存說明。中文原排列保留。1280×720 與 800×450 的大字 RTL 實際原生重驗通過；新增控制項必須完整在 viewport 內的反例與不重疊檢查。原中文／預設三尺寸的幾何、Tab、滑鼠返回及設定回歸仍通過。

六組語系／字體原生 fixture 含三種尺寸，另重驗最終 RTL 標準／窄視窗。查看的具體畫面及未查看範圍見 ART-27 本輪 JSON；不把生成全組圖片稱全部人工看過。英文與 RTL 依舊是未發布 QA，缺譯文明確回繁中；本輪沒有完整英／阿翻譯、真人試玩或音樂驗收。
