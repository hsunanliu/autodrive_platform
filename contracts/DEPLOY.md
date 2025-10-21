# 部署智能合約

## 前置條件
1. 安裝 Sui CLI: `cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui`
2. 配置錢包: `sui client`

## 部署步驟

### 1. 切換到 testnet
```bash
sui client switch --env testnet
```

### 2. 檢查錢包地址和餘額
```bash
sui client active-address
sui client gas
```

### 3. 編譯合約
```bash
cd contracts
sui move build
```

### 4. 部署合約
```bash
sui client publish --gas-budget 100000000
```

### 5. 記錄輸出信息
部署成功後會輸出：
- **Package ID**: 合約包地址（更新到 .env 的 CONTRACT_PACKAGE_ID）
- **Transaction Digest**: 部署交易 hash

## 測試合約

### 測試鎖定支付
```bash
sui client call \
  --package <PACKAGE_ID> \
  --module payment_escrow \
  --function lock_payment \
  --args <COIN_OBJECT_ID> <TRIP_ID> <DRIVER_ADDRESS> <PLATFORM_ADDRESS> <PLATFORM_FEE> \
  --gas-budget 10000000
```

### 測試釋放支付
```bash
sui client call \
  --package <PACKAGE_ID> \
  --module payment_escrow \
  --function release_payment \
  --args <ESCROW_OBJECT_ID> <TRIP_ID> \
  --gas-budget 10000000
```

## 更新配置

部署成功後，更新 `.env` 文件：
```
CONTRACT_PACKAGE_ID=<新的 Package ID>
```

重啟後端：
```bash
docker-compose restart backend
```
