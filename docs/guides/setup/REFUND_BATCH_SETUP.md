# 🚀 批次退款系統設置指南

## ✅ 已完成的部分

1. **批次處理腳本** - `/backend/scripts/process_pending_refunds.py`
2. **定時任務調度器** - `/backend/app/services/scheduler_service.py`
3. **Sui 客戶端服務** - `/backend/app/services/sui_client.py`
4. **測試錢包創建** - 地址和私鑰已生成並保存到 `.env`

## ⚠️ 剩餘步驟（需要完成才能啟用鏈上退款）

### 步驟 1: 從 Faucet 獲取測試 SUI

您的測試錢包地址：
```
0x013a90ee08199af4cdb1158fec0eca54e1174b93492180a33ea8298e94f3af36
```

**方法 A: 使用網頁 Faucet（推薦）**

訪問: https://faucet.sui.io/?address=0x013a90ee08199af4cdb1158fec0eca54e1174b93492180a33ea8298e94f3af36

點擊「Request SUI」按鈕獲取測試代幣（每次 1 SUI，可以多點幾次）

**方法 B: 使用 Discord Faucet**

1. 加入 Sui Discord: https://discord.gg/sui
2. 進入 #testnet-faucet 頻道
3. 輸入: `!faucet 0x013a90ee08199af4cdb1158fec0eca54e1174b93492180a33ea8298e94f3af36`

### 步驟 2: 確認收到測試 SUI

```bash
cd /Users/hsuanliu/autodrive_platform/contracts
sui client gas
```

應該看到類似輸出：
```
╭─────────────────────────────────────────────────────────────────╮
│ gasCoinId                                        │ gasBalance │
├─────────────────────────────────────────────────────────────────┤
│ 0x...                                            │ 1000000000 │  (1 SUI)
╰─────────────────────────────────────────────────────────────────╯
```

### 步驟 3: 初始化退款池

```bash
cd /Users/hsuanliu/autodrive_platform/contracts
chmod +x init_refund_pool.sh
./init_refund_pool.sh
```

**預期輸出：**
- 腳本會調用智能合約的 `init_refund_pool` 函數
- 返回一個 RefundPool Object ID（類似 `0x123abc...`）
- 複製這個 Object ID

### 步驟 4: 更新 .env 文件

編輯 `/Users/hsuanliu/autodrive_platform/.env`，找到：

```bash
# 退款池 Object ID（需要先運行 init_refund_pool.sh 獲取）
# 暫時留空，初始化退款池後再填寫
REFUND_POOL_ID=
```

改成：

```bash
# 退款池 Object ID（需要先運行 init_refund_pool.sh 獲取）
# 暫時留空，初始化退款池後再填寫
REFUND_POOL_ID=<您從步驟 3 獲取的 Object ID>
```

### 步驟 5: 向退款池注資（可選，用於測試）

如果想立即測試退款功能，可以向退款池注入一些測試 SUI：

```bash
# 1. 查看您的 gas coins
sui client gas

# 2. 選擇一個 coin，分離出 2 SUI 用於注資
sui client split-coin --coin-id <您的 gas coin ID> --amounts 2000000000 --gas-budget 10000000

# 3. 記下新創建的 coin ID（從輸出中獲取）

# 4. 注資到退款池
sui client call \
    --package "0xa6232c7f85812fe5e57c2e72071915e538ebd2fd7aba98371bd58490e790380b" \
    --module "refund_module" \
    --function "fund_refund_pool" \
    --args "<REFUND_POOL_ID>" "<新創建的 coin ID>" \
    --gas-budget 10000000
```

### 步驟 6: 安裝 APScheduler 套件

如果使用 Docker，需要重建映像：

```bash
cd /Users/hsuanliu/autodrive_platform/backend
docker-compose down
docker-compose build
docker-compose up -d
```

如果使用本地 Python 環境：

```bash
pip3 install --user apscheduler==3.10.4
# 或
python3 -m pip install --user apscheduler==3.10.4
```

### 步驟 7: 重啟後端

```bash
cd /Users/hsuanliu/autodrive_platform/backend

# 如果使用 Docker
docker-compose restart backend

# 如果使用本地開發
pkill -f uvicorn
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

**確認調度器已啟動：**

查看後端日誌，應該看到：

```
⏰ 定時任務調度器已啟動
📋 已添加定時任務: 批次處理退款 (每小時)
```

## 🧪 測試批次退款

### 方法 1: 等待定時任務執行（每小時）

定時任務會在每小時執行一次，自動處理所有待處理的退款。

### 方法 2: 手動執行批次處理腳本

```bash
cd /Users/hsuanliu/autodrive_platform/backend
python3 scripts/process_pending_refunds.py
```

預期輸出：

```
🚀 啟動退款批次處理器...
📋 找到 X 筆待處理的退款請求
💸 開始處理退款: ID=1, Trip=123, Amount=0.5 SUI
📝 創建退款交易...
🔐 簽署交易...
📤 提交交易到區塊鏈...
✅ 退款交易執行成功: 0x...
✅ 退款 1 處理成功!
   交易哈希: 0x...

============================================================
📊 批次處理完成!
   總計: X 筆
   成功: X 筆
   失敗: 0 筆
   耗時: X 秒
============================================================
```

### 方法 3: 通過應用測試

1. 在 Flutter 應用中找一個已完成的行程
2. 點擊「申請退款」按鈕
3. 填寫退款信息並提交
4. 退款會被記錄為 `pending_blockchain` 狀態
5. 等待批次處理器執行（或手動執行腳本）
6. 檢查資料庫，狀態應變更為 `approved`，並有 `blockchain_tx_hash`

## 📝 監控和調試

### 查看後端日誌

```bash
# Docker
docker-compose logs -f backend

# 本地
# 日誌會輸出到控制台
```

### 檢查退款池餘額

```bash
sui client object <REFUND_POOL_ID>
```

### 手動測試腳本

```bash
cd /Users/hsuanliu/autodrive_platform/backend
python3 scripts/process_pending_refunds.py
```

## ⚙️ 配置調整

### 調整批次處理頻率

編輯 `/backend/app/services/scheduler_service.py`：

```python
# 每小時執行一次
IntervalTrigger(hours=1)

# 改成每 30 分鐘執行一次
IntervalTrigger(minutes=30)

# 改成每天凌晨 2 點執行
CronTrigger(hour=2, minute=0)
```

### 禁用批次處理（測試期間）

臨時禁用定時任務，編輯 `/backend/app/main.py`：

```python
# 註釋掉這幾行
# from app.services.scheduler_service import scheduler_service
# scheduler_service.start()
# logger.info("⏰ 定時任務調度器已啟動")
```

## ❓ 常見問題

**Q: 如果退款池餘額不足會怎樣？**

A: 批次處理器會記錄錯誤並保持退款為 `pending_blockchain` 狀態，等待下次重試。

**Q: 批次處理失敗會影響用戶嗎？**

A: 不會。用戶提交退款後立即收到確認，批次處理在後台進行，失敗後會自動重試。

**Q: 可以手動批准單筆退款嗎？**

A: 可以。使用批次處理腳本手動執行，或者通過管理後台 API。

**Q: 測試錢包的私鑰安全嗎？**

A: 這是專門用於 testnet 開發的測試錢包。生產環境必須使用更安全的密鑰管理方案（如 AWS KMS、HashiCorp Vault 等）。

## 🎉 完成！

完成以上步驟後，您的批次退款系統就可以開始處理真正的鏈上退款了！

系統會：
- ✅ 每小時自動處理待處理的退款
- ✅ 調用 Sui Move 智能合約
- ✅ 將 SUI 從退款池轉到用戶錢包
- ✅ 記錄交易哈希供用戶查詢
- ✅ 自動重試失敗的退款

有任何問題，請查看後端日誌或手動運行批次處理腳本進行調試！
