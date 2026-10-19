# [MAIN-8] 建立自由外觀與服飾收藏

> 狀態：完成

## 內文

### 需求
玩家可免費無限更換膚色、種族、性別、髮型與基礎外觀；服飾與帽子以遊戲內貨幣購買、收藏和自由穿戴。衣櫃保留穩定物品定義，與 Steam 可交易經濟分開。

### 來源
2026-10-11 使用者追加紙娃娃系統。Nintendo《Animal Crossing: New Horizons》官方支援說明鏡子可隨時改外觀；Disney Dreamlight Valley 2024-08-21 官方更新說明衣櫃分類、整套預設與拍照姿勢。採用容易返回與看見結果的流程，免費無限修改為本作明確需求。

### 驗收條件
- [x] 基礎外觀可反覆免費更換，服裝不受性別限制。
- [x] 購買扣款一次並收藏；不足額、重複購買及未擁有穿戴不改進度。
- [x] 新玩家能購買首件服飾，遊戲通關可取得明確貨幣獎勵。
- [x] 外觀、貨幣與收藏重新啟動仍保存，舊存檔保留既有拍貼與成就。
- [x] 損毀或未知資料退回安全預設，局部測試通過。

### 測試流程
1. 在隔離存檔重複改基礎外觀，檢查餘額不變。
2. 購買服飾並穿戴，重複購買及不足額操作後檢查金額。
3. 重啟與載入舊存檔，核對外觀、收藏和原有進度。

---

# 跟其他票的關係
- Blocks：無
- Blocked by：無
- Related：ART-7、ART-8、MAIN-6

---

# 開始與研究

固定基準：4c320b9d6eef219d5ea90a9b96cb09ad7a68b3a5。研究與使用者選圖見 [本批設計](../../design/runtime/wardrobe.md) 與 [提示詞指南](../../design/runtime/art-prompt-guide.md)。

---

# Commit-1

問題：玩家需要自由更換基礎外觀，並能以園區貨幣收藏和穿戴服飾。

改動：接通免費外觀修改、服飾收藏、購買、試穿與穿戴保存流程；保持遊戲進度與可交易經濟定義分離。

驗收：局部資料流程和隔離存檔原生輸入覆蓋新舊存檔、錯誤／未知服飾資料、重複購買、不足額、穿戴取消及重新載入，回歸檢查通過。

| 畫面證據 | 說明 |
| --- | --- |
| [衣櫃與外觀流程](images/MAIN-8-wardrobe.png) | 原生靜態畫面；交易及資料檢查另由自動驗證覆蓋 |

程式交付：[Commit 804a497](https://github.com/deadline314/Snapland/commit/804a4977028ff73a8f754e37655d5edfc71646d1)（分支 `feature/island-first-park`；固定基準 `4c320b9d6eef219d5ea90a9b96cb09ad7a68b3a5`）。

### 最新輸出驗證
Windows輸出於Intel Arc B580原生GPU完成圖集、NPC、場景動畫與遮擋資源冒煙檢查，12款場景所需素材均載入，無ERROR；此檢查不代表真人試玩、完整換裝動作、每姿勢或試聽驗收。

### 程式與證據提交
分支：feature/island-first-park。更新至最新main後的本票提交：[ca10308](https://github.com/deadline314/Snapland/commit/ca103086e16cf5d36d23ca114ba4c6fe1e1e0456)。


# 2026-10-20 結案核對

本輪衣櫃資料與UI回歸通過：免費外觀、購買／不足額／重複購買、未擁有穿戴、取消預覽、舊檔遷移、拒寫回滾。兩個新程序另確認購買、穿戴、餘額、外觀及原有照片／成就保持，完整保存樹及檔案雜湊一致。ART-25三尺寸原生換裝／商店／試穿已查看。正式四款外套仍明列為換色款；不同輪廓與所有動作分層仍由ART-18驗收，未在此票假稱完成。

目前正式進度、交易與重整後介面已核對在main；不將無法解析的早期feature提交連結當合入證明。舊Windows圖與本輪Linux／llvmpipe證據分開；沒有新Windows EXE、真人試玩或聽感認證。

[六份比較、驗證流程與限制](../../design/runtime/progress-restart-verification.md) · [兩程序實際結果](images/MAIN-6-restart-20261020-verification.json) · [核心回歸](../Snapland-art/images/ART-23-verify-20261020-core-runtime-tests.log) · [衣櫃回歸](../Snapland-art/images/ART-23-verify-20261020-wardrobe-runtime-tests.log) · [設定／換裝三尺寸](../Snapland-art/images/ART-25-verify-20261020.json)。全域CI後段仍有其他票的角色素材缺口，本結案不等於全案綠燈。
