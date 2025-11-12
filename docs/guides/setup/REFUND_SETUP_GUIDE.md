# 🔄 退款系統設置指南

## 📋 概覽

目前您的退款系統**已經完成 80%**，只差最後幾個步驟就能實現真正的鏈上退款！

### ✅ 已完成的部分

1. **Move 合約** - `contracts/sources/financial/refund_module.move` ✅
   - 退款池 (RefundPool) 管理
   - 創建退款請求函數
   - 批准並執行退款函數
   - 拒絕退款函數

2. **合約已部署** ✅
   - Package ID: `0xa6232c7f85812fe5e57c2e72071915e538ebd2fd7aba98371bd58490e790380b`
   - 網路: Sui Testnet

3. **後端整合** ✅
   - Sui 區塊鏈客戶端 (`app/services/sui_client.py`)
   - 退款服務 V2 (`app/services/refund_service_v2.py`)
   - API 路由已更新 (`app/api/v1/refunds.py`)

4. **前端支持** ✅
   - 退款按鈕 (Flutter 應用)
   - 退款對話框和表單驗證
   - 交易哈希顯示

### ⚠️ 待完成的步驟

只需要完成以下 2 個步驟，就能實現真正的鏈上退款：

## 🚀 第 1 步：初始化退款池

退款池是一個智能合約對象，用於存放平台的退款資金。

### 1.1 運行初始化腳本

```bash
cd /Users/hsuanliu/autodrive_platform/contracts
chmod +x init_refund_pool.sh
./init_refund_pool.sh
```

這個腳本會：
- 調用合約的 `init_refund_pool()` 函數
- 獲取新創建的 RefundPool Object ID
- 自動更新 `.env` 文件中的 `REFUND_POOL_ID`

### 1.2 或者手動執行

如果腳本執行失敗，可以手動執行：

```bash
# 1. 初始化退款池
sui client call \
    --package "0xa6232c7f85812fe5e57c2e72071915e538ebd2fd7aba98371bd58490e790380b" \
    --module "refund_module" \
    --function "init_refund_pool" \
    --gas-budget 10000000

# 2. 從輸出中複製 RefundPool Object ID
# 看起來像: 0x... (在 Created Objects 或 Mutated Objects 部分)

# 3. 更新 .env 文件
echo "REFUND_POOL_ID=<你的退款池 Object ID>" >> ../.env
```

## 💰 第 2 步：向退款池注資

退款池需要有足夠的 SUI 才能執行退款。

### 2.1 準備資金

確保您的平台錢包有足夠的 SUI：

```bash
sui client gas
```

### 2.2 向退款池轉入資金

這需要兩步操作：

**方法 A：使用 split coin + fund_refund_pool**

```bash
# 1. Split coin (從您的 gas coin 中分離出退款金額)
# 假設要注資 10 SUI (= 10,000,000,000 MIST)
sui client split-coin \
    --coin-id <您的 gas coin ID> \
    --amounts 10000000000 \
    --gas-budget 10000000

# 2. 記下新創建的 coin object ID (從上一步輸出中獲取)

# 3. 調用 fund_refund_pool
sui client call \
    --package "0xa6232c7f85812fe5e57c2e72071915e538ebd2fd7aba98371bd58490e790380b" \
    --module "refund_module" \
    --function "fund_refund_pool" \
    --args "<REFUND_POOL_ID>" "<新創建的 coin object ID>" \
    --gas-budget 10000000
```

**方法 B：直接從後端代碼轉帳（推薦用於開發測試）**

如果只是測試，可以先跳過注資，系統會優雅降級到資料庫記錄模式。

## 📊 第 3 步：驗證設置

### 3.1 檢查環境變數

確保 `.env` 文件包含：

```bash
# Sui 網路配置
SUI_NODE_URL=https://fullnode.testnet.sui.io:443
SUI_NETWORK=testnet

# 合約配置
CONTRACT_PACKAGE_ID=0xa6232c7f85812fe5e57c2e72071915e538ebd2fd7aba98371bd58490e790380b
REFUND_POOL_ID=<您的退款池 Object ID>

# 平台錢包
PLATFORM_WALLET_ADDRESS=0x6dfff9f4efba3579ce7db6e2f40cfb23461f2aa4e632eb477454bf8c10e0e7b7
OPERATOR_PRIVATE_KEY=suiprivkey1qq9rmshnl84zrl0yjg47lfr9lf9dn5sgzwnh9f0szmyy2w4qs7lpya2cu6x
```

### 3.2 查詢退款池餘額

```bash
# 使用 sui client object 查看退款池
sui client object <REFUND_POOL_ID>
```

您應該看到退款池的詳細信息，包括當前餘額。

### 3.3 重啟後端服務

```bash
cd /Users/hsuanliu/autodrive_platform/backend
docker-compose restart backend
# 或
pkill -f uvicorn && python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

## 🧪 第 4 步：測試退款流程

### 4.1 檢查後端日誌

後端啟動時應該看到：

```
✅ Sui 客戶端初始化成功: testnet
```

### 4.2 創建測試退款

1. 在 Flutter 應用中找一個已完成的行程
2. 點擊「申請退款」按鈕
3. 填寫退款原因（至少 10 個字）
4. 提交退款申請

### 4.3 檢查結果

**如果退款池已初始化並有資金：**
- 後端日誌會顯示：`💸 開始鏈上退款: trip_id=X, amount=X SUI`
- 資料庫中的退款記錄狀態為 `approved`
- 返回交易哈希

**如果退款池未配置：**
- 後端日誌會顯示：`⚠️ REFUND_POOL_ID 未配置，跳過鏈上退款`
- 資料庫中的退款記錄狀態為 `pending_blockchain`
- 退款已記錄，可以後續手動處理

## 🔍 故障排除

### 問題 1: "REFUND_POOL_ID 未配置"

**解決方案：** 完成第 1 步 - 初始化退款池

### 問題 2: "Sui 客戶端不可用"

**可能原因：**
- `pysui` 套件未安裝
- Sui 節點 URL 不正確

**解決方案：**
```bash
pip install pysui==0.65.0
```

檢查網路連接：
```bash
curl https://fullnode.testnet.sui.io:443
```

### 問題 3: "退款池餘額不足"

**解決方案：** 完成第 2 步 - 向退款池注資

### 問題 4: Transaction 執行失敗

**可能原因：**
- Gas 預算不足
- 對象 ID 不正確
- 權限問題

**解決方案：**
```bash
# 增加 gas 預算
--gas-budget 20000000

# 確認使用正確的錢包地址
sui client active-address
```

## 🎯 系統架構說明

### 當前實作狀態

```
用戶申請退款
    ↓
Flutter App (trip_history_page.dart)
    ↓
Backend API (/api/v1/refunds/create)
    ↓
RefundServiceV2.create_and_execute_refund()
    ↓
    ├─→ [檢查退款池配置]
    │       ↓
    │   ✅ 配置完整 → 調用 SuiClient.create_refund_request_transaction()
    │       ↓
    │   📝 生成鏈上交易數據
    │       ↓
    │   ⚠️ 需要用戶簽署（TODO: 前端整合錢包簽署）
    │       ↓
    │   💾 數據庫記錄 (status: approved/pending_blockchain)
    │
    └─→ ❌ 配置不完整 → 降級到資料庫記錄模式
            ↓
        💾 數據庫記錄 (status: pending_blockchain)
            ↓
        📋 可以後續手動處理或批次處理
```

### 下一步優化 (可選)

1. **前端錢包整合**
   - 整合 Sui Wallet 到 Flutter 應用
   - 讓用戶自己簽署退款交易

2. **自動批次處理**
   - 定時任務掃描 `pending_blockchain` 狀態的退款
   - 批次執行鏈上退款

3. **退款池自動補充**
   - 監控退款池餘額
   - 餘額不足時自動補充

## 📚 相關文件

- Move 合約: `contracts/sources/financial/refund_module.move`
- Sui 客戶端: `backend/app/services/sui_client.py`
- 退款服務 V2: `backend/app/services/refund_service_v2.py`
- API 路由: `backend/app/api/v1/refunds.py`
- Flutter 退款 UI: `mobile/lib/trip_history_page.dart`

## ❓ 常見問題

**Q: 為什麼不能立即執行真正的鏈上退款？**

A: 因為需要先初始化退款池並注資。這是 Move 合約的安全設計，確保平台有足夠的資金支付退款。

**Q: 退款池需要多少資金？**

A: 建議至少準備預期退款總額的 2-3 倍。例如，如果預計每天有 10 SUI 的退款，準備 20-30 SUI。

**Q: 如果退款池餘額不足會怎樣？**

A: 系統會優雅降級，退款請求會被記錄為 `pending_blockchain`，可以後續手動處理或等待退款池補充後自動執行。

**Q: 資料庫記錄的退款和鏈上退款有什麼區別？**

A:
- **資料庫記錄**: 只記錄退款意圖，資金還在司機或 escrow 中
- **鏈上退款**: 真實執行區塊鏈交易，資金從退款池轉到用戶錢包

**Q: 測試階段可以跳過退款池嗎？**

A: 可以！系統會自動降級到資料庫記錄模式，所有退款記錄都會正常保存，只是不會真正執行鏈上轉帳。

## 🎉 總結

完成上述步驟後，您的退款系統將能夠：

✅ 真實執行鏈上退款
✅ 記錄完整的退款歷史
✅ 顯示交易哈希供用戶查詢
✅ 優雅處理各種邊界情況
✅ 在後台管理界面查看所有退款記錄

如果有任何問題，請查看後端日誌或提交 issue！
