# 🔗 合約層與後端交互流程

## 📋 1. 用戶註冊流程

```mermaid
sequenceDiagram
    participant U as 用戶
    participant B as 後端API
    participant C as 智能合約
    participant DB as 數據庫

    U->>B: POST /api/v1/users/register
    B->>DB: 保存用戶基本信息
    B->>C: user_registry::register_user()
    C->>C: 創建 UserProfile 對象
    C-->>B: 返回交易哈希
    B->>DB: 更新 blockchain_object_id
    B-->>U: 返回用戶信息 + 交易哈希
```

## 🚗 2. 車輛註冊流程

```mermaid
sequenceDiagram
    participant D as 司機
    participant B as 後端API
    participant C as 智能合約
    participant DB as 數據庫

    D->>B: POST /api/v1/vehicles/
    B->>DB: 保存車輛信息
    B->>C: vehicle_registry::register_vehicle()
    C->>C: 創建 Vehicle 對象
    C-->>B: 返回交易哈希 + object_id
    B->>DB: 更新 blockchain_object_id
    B-->>D: 返回車輛信息
```

## 🚕 3. 完整支付流程

```mermaid
sequenceDiagram
    participant P as 乘客
    participant D as 司機
    participant B as 後端API
    participant E as 託管服務
    participant C as 智能合約
    participant DB as 數據庫

    Note over P,DB: 1. 行程創建階段
    P->>B: POST /api/v1/trips/
    B->>DB: 創建行程記錄
    
    Note over P,DB: 2. 司機接單階段
    D->>B: POST /api/v1/trips/{id}/accept
    B->>DB: 更新行程狀態為 "accepted"
    
    Note over P,DB: 3. 行程進行階段
    D->>B: PUT /api/v1/trips/{id}/pickup
    B->>DB: 更新狀態為 "picked_up"
    
    Note over P,DB: 4. 支付處理階段
    D->>B: PUT /api/v1/trips/{id}/complete
    B->>E: escrow_service.lock_payment()
    E->>C: payment_escrow::lock_payment()
    C->>C: 鎖定乘客資金
    C-->>E: 返回託管對象ID
    E->>C: payment_escrow::release_payment()
    C->>C: 釋放資金給司機
    C-->>E: 返回交易哈希
    E-->>B: 返回支付結果
    B->>DB: 更新支付狀態
    B-->>D: 返回完成結果
```

## 🔍 4. 數據查詢流程

```mermaid
sequenceDiagram
    participant U as 用戶
    participant B as 後端API
    participant I as IOTA服務
    participant C as 智能合約
    participant DB as 數據庫

    Note over U,DB: 錢包餘額查詢
    U->>B: GET /api/v1/trips/payment/wallet/balance
    B->>I: iota_service.get_wallet_balance()
    I->>C: 查詢鏈上餘額
    C-->>I: 返回餘額數據
    I-->>B: 返回格式化餘額
    B-->>U: 返回餘額信息

    Note over U,DB: 交易狀態查詢
    U->>B: GET /api/v1/trips/payment/transaction/{hash}
    B->>I: iota_service.get_transaction_status()
    I->>C: 查詢交易狀態
    C-->>I: 返回確認狀態
    I-->>B: 返回狀態信息
    B-->>U: 返回交易狀態
```

## 🛠️ 5. 錯誤處理流程

```mermaid
sequenceDiagram
    participant B as 後端API
    participant C as 智能合約
    participant DB as 數據庫

    B->>C: 調用智能合約
    C-->>B: 返回錯誤
    B->>B: 記錄錯誤日誌
    B->>DB: 回滾數據庫操作
    B->>B: 返回用戶友好錯誤信息
```

## 📊 6. 關鍵交互點

### A. 數據同步
- **後端 → 合約**: 用戶/車輛註冊時同步
- **合約 → 後端**: 通過事件監聽同步狀態變更
- **雙向驗證**: 關鍵操作需要鏈上和鏈下數據一致性檢查

### B. 狀態管理
- **鏈上狀態**: 用戶信譽、車輛驗證、支付託管
- **鏈下狀態**: 行程詳情、位置信息、實時狀態
- **狀態同步**: 定期同步確保一致性

### C. 安全機制
- **權限驗證**: 合約層驗證調用者身份
- **數據完整性**: 使用哈希驗證關鍵數據
- **資金安全**: 託管合約確保支付安全

## 🔧 7. 配置要點

### 環境變量
```env
# IOTA 網絡配置
IOTA_NODE_URL=https://api.testnet.iota.cafe
IOTA_NETWORK=testnet

# 合約地址
CONTRACT_PACKAGE_ID=0xa353f4acea9dbacd0cc7af37479b277299160d9288495d017ec4d824ea7a5d31
USER_REGISTRY_ID=0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f
VEHICLE_REGISTRY_ID=0xfaf54e90664e669943e07e9845dbd2523e71920b04dd5bf264700a68c1370ce4
```

### Mock 模式
- 開發階段使用 `MOCK_MODE=True`
- 生產環境使用 `MOCK_MODE=False`
- 自動切換真實/模擬區塊鏈調用