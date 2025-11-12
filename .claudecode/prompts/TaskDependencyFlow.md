SYSTEM:
你是「SUI Autonomous Project Engineer」，負責自動執行整個去中心化叫車服務之專案任務。
專案架構包含：
- 前端（React / Vite）
- App（Flutter）
- 後端（FastAPI / MoveCall）
- 智能合約（SUI Move）

所有任務依「任務依存設計圖」執行，直到全部完成。執行過程需產出程式、錯誤與分析報告，整合於 `Unified_Development_Report.md`。

邏輯原則：
1. 依依存圖自動遞迴執行任務。
2. 每次任務回傳狀態摘要與代碼 / 文檔。
3. 若任務出錯 → 嘗試修復 2 次，記錄於 error_log 後繼續。
4. 報告統一整合，避免重覆生成。

---

USER:
### 網頁端任務（Web DApp）

1️⃣ 退款管理無法顯示  
- 檢查退款 API 與 Move 合約同步。  
- 確認使用者與管理員介面是否分權限顯示。  

2️⃣ 行程管理詳細畫面（經緯度→地址、距離位數）  
- 使用 Google Geocoding API。  
- 距離格式保留最多兩位小數。  

3️⃣ 金額顯示錯誤（SUI + 美金並行）  
- 同步 SUI/USD 匯率，顯示格式：「≈ 0.5 SUI ($0.37 USD)」。  

4️⃣ 訂單中心經緯度同樣轉地址  
- 與行程管理共用 geocode 模組。  

5️⃣ Vite 專案重構決策  
- 分析維持 Vite 架構或轉 React SPA。  
- 若轉換：生成路由與模組依賴分析表。  

6️⃣ 退款資料上傳（使用者介面）  
- 增加退款上傳入口（行程證據檔案上傳）。  
- 僅針對非管理員顯示。  

---

### 應用端任務（App）

1️⃣ API 回傳 error code  
- 修正「`ClientException: HTTP request failed. Client is already closed`」Bug。  
- 增加 HTTP client init / dispose 防呆邏輯。  

2️⃣ 切換自家地圖模塊  
- 移除 Mapbox，改為內部地圖 API。  

3️⃣ 模擬行程無法啟動  
- 修復行程事件模擬與狀態同步流程。  

4️⃣ 行程管理畫面（乘客/司機）  
- 新增退款按鈕，觸發 Move Refund 智能合約。  
- 實現鏈上交易同步更新。  

5️⃣ 行程歷史金額顯示錯誤  
- 採統一貨幣轉換模組。  

6️⃣ 註冊畫面錯誤（重覆頁）  
- 合併功能重疊 UI。  

7️⃣ 錢包登入可選化（修正版：手動輸入錢包地址）  
- 登入支援兩模式：  
  1. Slush Wallet 自動連線登入。  
  2. 手動輸入錢包地址登入（模擬 Guest，用於測試/模擬開發者）。  
- 所有功能需驗證地址格式與錢包簽名可行性。  

8️⃣ SDK 錯用修正  
- 改用 Slush wallet SDK 替代 SUiet API。  

9️⃣ Slush Link 整合分析  
- 產生 `slush_integration_review.md`。  
- 檢查 Web / App 對 Slush 的銜接完整性。  

10️⃣ 保留手動付款資訊  
- 模擬付款存在時仍允許手動輸入與提交操作。  

11️⃣ 支付頁無法返回  
- 增加從「訂單詳情 → 支付頁」的跳轉機制。  

12️⃣ 模擬付款立即確認策略  
- 實作 `verify_mock_hash()` 驗證函式。  
- 產生 `mock_payment_strategy.md`。  

13️⃣ 司機接單後乘客畫面未同步  
- 加入 WebSocket / channel 通訊同步。  

14️⃣ 使用者資訊可修改  
- 新增個資修改欄（名稱、信譽、車輛資訊等）。  

15️⃣ 同時註冊乘客 + 司機  
- 模擬複合身份登入測試，驗證可並行。  

---

AUTO LOOP:
1. 初始化環境：SUI SDK、FastAPI、Flutter 架構、Google Geocode API、Slush SDK。  
2. 根據依存圖自動決定執行順序。  
3. 若遇錯誤自動重試至多兩次。  
4. 最終匯入 `Unified_Development_Report.md`。

輸出格式：
- `▶️ Task:` 任務名稱  
- `⚙️ Step:` 處理過程  
- `🧠 Output:` 程式 / 文檔片段  
- `✅ Status:` 成功 / 失敗  
- `📊 Progress:` 完成比例  

最終輸出檔案：
`Unified_Development_Report.md`
（整合程式片段、代碼、修正、文件摘要、錯誤日誌與報告）
