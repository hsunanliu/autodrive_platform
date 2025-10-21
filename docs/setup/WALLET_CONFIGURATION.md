# 錢包配置說明

## 方案 B：智能合約直接轉帳模式

我們採用的是**方案 B**，資金流向如下：

```
乘客錢包 → 智能合約 (lock_payment) → 司機錢包 (release_payment)
                                    ↓
                              平台錢包 (平台費用)
```

## 需要配置的錢包

### 1. 平台收款錢包（Platform Wallet）

**用途：** 接收平台費用

**配置項：** `PLATFORM_WALLET_ADDRESS`

**是否需要私鑰：** ❌ 不需要

**說明：**
- 這個地址只用來接收平台費用
- 智能合約會自動將平台費用轉到這個地址
- 後端不需要這個錢包的私鑰

**示例：**
```env
PLATFORM_WALLET_ADDRESS=0x6dfff9f4efba3579ce7db6e2f40cfb23461f2aa4e632eb477454bf8c10e0e7b7
```

### 2. 操作錢包（Operator Wallet / Gas Payer）

**用途：** 支付調用智能合約的 gas 費用

**配置項：** `OPERATOR_PRIVATE_KEY`

**是否需要私鑰：** ✅ 需要

**說明：**
- 當司機完成行程時，後端需要調用智能合約的 `release_payment` 函數
- 調用合約需要支付 gas 費用，所以需要一個錢包來支付
- **重要：** 這個錢包不涉及資金轉移，只用來支付 gas
- 資金直接從智能合約轉給司機，不經過這個錢包

**示例：**
```env
OPERATOR_PRIVATE_KEY=suiprivkey1q...（你的私鑰）
```

**如何獲取私鑰：**
1. 打開 Slush Wallet 或其他 Sui 錢包
2. 選擇一個錢包（建議創建專門的操作錢包）
3. 導出私鑰（Export Private Key）
4. 複製私鑰並填入 `.env` 文件

**安全建議：**
- 使用專門的操作錢包，不要使用個人主錢包
- 這個錢包只需要少量 SUI 用於支付 gas（建議 1-10 SUI）
- 定期檢查餘額，確保有足夠的 gas 費用

## 資金流向詳解

### 支付鎖定（乘客支付）

```
1. 乘客在前端點擊「支付」
2. 前端調用 Sui 錢包簽署交易
3. 調用智能合約 lock_payment(payment, trip_id, driver, platform, platform_fee)
4. 資金被鎖定在智能合約中
5. 返回 escrow_object_id（託管對象ID）
```

**涉及的錢包：**
- 乘客錢包（前端簽署）
- 智能合約（接收資金）

### 支付釋放（司機完成行程）

```
1. 司機點擊「完成行程」
2. 後端驗證 escrow_object_id 存在
3. 後端調用智能合約 release_payment(escrow_object_id, trip_id)
4. 智能合約自動執行：
   - 將司機收益轉給司機錢包
   - 將平台費用轉給平台錢包
5. 返回交易哈希
```

**涉及的錢包：**
- 操作錢包（支付 gas，使用 OPERATOR_PRIVATE_KEY）
- 智能合約（釋放資金）
- 司機錢包（接收收益）
- 平台錢包（接收平台費用）

## 常見問題

### Q: 為什麼需要操作錢包私鑰？

A: 因為調用智能合約需要支付 gas 費用。雖然 `release_payment` 是 public entry function（任何人都可以調用），但調用者需要支付 gas。

### Q: 操作錢包會接觸到行程款項嗎？

A: **不會**。資金直接從智能合約轉給司機和平台，操作錢包只用來支付 gas。

### Q: 如果操作錢包餘額不足會怎樣？

A: 調用智能合約會失敗，行程無法完成。建議定期檢查操作錢包餘額。

### Q: 可以使用平台收款錢包作為操作錢包嗎？

A: 可以，但不建議。最好使用專門的操作錢包，方便管理和審計。

### Q: 開發環境需要配置私鑰嗎？

A: 如果設置 `MOCK_MODE=true`，則不需要。Mock 模式會模擬所有區塊鏈操作。

## 配置檢查清單

- [ ] 已配置 `PLATFORM_WALLET_ADDRESS`（平台收款地址）
- [ ] 已配置 `OPERATOR_PRIVATE_KEY`（操作錢包私鑰）
- [ ] 操作錢包有足夠的 SUI 餘額（建議 1-10 SUI）
- [ ] 已部署智能合約並配置 `CONTRACT_PACKAGE_ID`
- [ ] 已測試完整的支付流程

## 測試建議

1. **測試環境：** 使用 Sui Testnet
2. **獲取測試幣：** https://faucet.testnet.sui.io/
3. **測試流程：**
   - 乘客支付（前端錢包簽署）
   - 檢查 escrow_object_id 是否正確保存
   - 司機完成行程（後端調用合約）
   - 檢查司機和平台是否收到款項

## 相關文件

- `.env` - 環境變量配置
- `backend/app/config.py` - 配置類定義
- `backend/app/services/sui_service.py` - Sui 服務（調用合約）
- `backend/app/services/escrow_service.py` - 託管服務（支付邏輯）
- `contracts/sources/financial/payment_escrow.move` - 智能合約
