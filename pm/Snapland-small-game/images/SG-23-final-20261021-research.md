# 2026-10-21 招牌平衡：力學回饋與介面收尾

動手前閱讀User-guide、原力矩模型及先前圖片。本輪先重讀Nintendo、Panic、Lucas Pope、Drool、Ben Esposito與House House六方官方資料（同批SG-25研究），再補下面六個不同團隊；不把官網一句宣傳當實際試玩，也不由Steam好評百分比斷言玩家偏好某個機制。

| 團隊／官方資料 | 實際閱讀與取捨 |
|---|---|
| [Dry Cactus：Poly Bridge3官方商店](https://store.steampowered.com/app/1850160/Poly_Bridge_3/) | 作者明列自訂物理的可重現性、sandbox、材料與預建結構。採可重複的真實受力／結果，失敗也保留逐段成果；不新增橋梁建造。保存並查看首張150+levels宣傳圖與第二張橋體遊玩靜圖，兩者分開標示，不由宣傳圖推論物理。 |
| [Spiderling：Besiege官方商店](https://store.steampowered.com/app/346010/Besiege/) | 物理機械建造、障礙與sandbox說明。採用操作造成可見機械後果的比較原則，不加入戰鬥、破壞或複雜建造選單。此輪只有文字。 |
| [Max Inferno：A Little to the Left官方商店](https://store.steampowered.com/app/1629520/A_Little_to_the_Left/) | 已讀完整作者說明：直覺拖曳、多解、玩家決定提示揭示量與LetItBe略過。採操作物本身優先、提示離開操作區與可返回；不把精準判定改成整齊擺放謎題。下載並看工具箱整理靜圖：主要物件大、顏色克制、幾乎沒有常駐文字。 |
| [Witch Beam：Unpacking官方商店](https://store.steampowered.com/app/1135690/Unpacking/) | 物品放入新家、空間與敘事線索的作者描述。採讓物件和空間講清楚目標的原則；本作仍保留七段計分，未冒稱改成無時間模式。此輪只有文字。 |
| [Toukana：Dorfromantik官方商店](https://store.steampowered.com/app/1455840/Dorfromantik/) | 完整說明把平和景觀、配合度得分、指定數量任務及可選模式分開。採明確得分資格、練習與正式成果分開；不是把更多數字疊上畫面。下載並看靜圖：世界佔主畫面，計數集中角落，留白不等於內容空洞。 |
| [DON’T NOD：Jusant官方介紹](https://dont-nod.com/en/games/jusant/) | 攀爬工具、耐力、自訂步調、風坡及不同探索路線的作者說明。採必要狀態可判斷、主體與環境層次清楚，不複製攀爬或耐力系統；此輪未看影片／未聽音樂。 |

另重讀OpenStax的平衡／外力原理；Apple降低動態頁已開啟但本次取回的主要是導覽文字，不新增宣稱。原數值模型與其研究不變。PolyBridge／Besiege／MaxInferno原官網網址取回失敗，Unpacking／Toukana官網逾時；改正常讀各作者的公開官方商店頁，不算作原網址已成功。所有保存的圖都只是原始官方靜態文件，不是本作素材或連續動畫；來源API、URL與SHA另存。

## 本輪選擇

新的失衡路線先被原生嚴格幾何護欄攔下：上方提示與大幅傾斜招牌的外框相交，原局部檢查只在小角度要求牌面完整避讓。將短提示移到右側預告卡下方空間；完整55個角度（−1.35到1.35，每0.05）都保留招牌、標題與配重的完整避讓要求，不取消原生護欄。HUD持續刷新及重排也保存位置，避免只在提示剛出現時正確。

每個實際完成段都有得分或零分原因；撞線另列次數。五段安全成功、七段全精準零撞線才得小惡魔，力矩、停留、配重速度及風都不變。結果使用既有分頁，不增加長捲動。
