#!/bin/bash
# 創建測試用的錢包和退款池

set -e

echo "🔑 創建測試錢包..."

# 1. 創建新錢包
echo "1️⃣ 生成新的 Sui 地址..."
sui client new-address ed25519 test_refund_wallet

# 2. 切換到新地址
echo "2️⃣ 切換到新地址..."
sui client switch --address test_refund_wallet

# 3. 顯示新地址
NEW_ADDRESS=$(sui client active-address)
echo "✅ 新錢包地址: $NEW_ADDRESS"

# 4. 獲取測試 SUI (testnet faucet)
echo ""
echo "3️⃣ 從 faucet 獲取測試 SUI..."
sui client faucet
sleep 5
sui client faucet
sleep 5

# 5. 檢查餘額
echo ""
echo "4️⃣ 檢查餘額..."
sui client gas

# 6. 獲取私鑰
echo ""
echo "5️⃣ 匯出私鑰..."
PRIVATE_KEY=$(sui keytool export --key-identity $NEW_ADDRESS --json | jq -r '.exportedPrivateKey')

echo ""
echo "=========================================="
echo "✅ 測試錢包創建成功！"
echo "=========================================="
echo ""
echo "請將以下信息添加到 .env 文件："
echo ""
echo "PLATFORM_WALLET_ADDRESS=$NEW_ADDRESS"
echo "OPERATOR_PRIVATE_KEY=$PRIVATE_KEY"
echo ""
echo "=========================================="

# 保存到臨時文件
cat > test_wallet_info.txt <<EOF
測試錢包信息
============
地址: $NEW_ADDRESS
私鑰: $PRIVATE_KEY

⚠️ 警告：這是測試錢包，僅用於開發測試！
請勿在生產環境使用！
EOF

echo "信息已保存到: test_wallet_info.txt"
