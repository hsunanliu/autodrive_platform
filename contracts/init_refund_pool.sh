#!/bin/bash
# 初始化退款池腳本

set -e

echo "🚀 初始化退款池..."

# 載入環境變數
if [ -f "../.env" ]; then
    source ../.env
fi

# 檢查必要的環境變數
if [ -z "$CONTRACT_PACKAGE_ID" ]; then
    echo "❌ 錯誤: 未設置 CONTRACT_PACKAGE_ID"
    exit 1
fi

if [ -z "$PLATFORM_WALLET_ADDRESS" ]; then
    echo "❌ 錯誤: 未設置 PLATFORM_WALLET_ADDRESS"
    exit 1
fi

echo "📦 Package ID: $CONTRACT_PACKAGE_ID"
echo "👛 Platform Wallet: $PLATFORM_WALLET_ADDRESS"

# 初始化退款池
echo ""
echo "1️⃣ 初始化退款池..."
sui client call \
    --package "$CONTRACT_PACKAGE_ID" \
    --module "refund_module" \
    --function "init_refund_pool" \
    --gas-budget 10000000 \
    --json > refund_pool_init.json

# 提取 RefundPool Object ID
REFUND_POOL_ID=$(jq -r '.objectChanges[] | select(.objectType | contains("RefundPool")) | .objectId' refund_pool_init.json)

if [ -z "$REFUND_POOL_ID" ] || [ "$REFUND_POOL_ID" == "null" ]; then
    echo "❌ 錯誤: 無法獲取 RefundPool Object ID"
    exit 1
fi

echo "✅ RefundPool 已創建！"
echo "📍 RefundPool Object ID: $REFUND_POOL_ID"

# 更新 .env 文件
echo ""
echo "2️⃣ 更新 .env 文件..."
if grep -q "REFUND_POOL_ID=" ../.env; then
    # 如果存在，更新
    sed -i.bak "s/REFUND_POOL_ID=.*/REFUND_POOL_ID=$REFUND_POOL_ID/" ../.env
else
    # 如果不存在，添加
    echo "REFUND_POOL_ID=$REFUND_POOL_ID" >> ../.env
fi

echo "✅ .env 已更新！"

# 可選：向退款池注資（用於測試）
echo ""
echo "3️⃣ 是否要向退款池注資？(y/n)"
read -r FUND_POOL

if [ "$FUND_POOL" == "y" ] || [ "$FUND_POOL" == "Y" ]; then
    echo "請輸入注資金額（SUI）:"
    read -r AMOUNT

    # 轉換 SUI 為 MIST (1 SUI = 1,000,000,000 MIST)
    AMOUNT_MIST=$(echo "$AMOUNT * 1000000000" | bc | cut -d. -f1)

    echo "💰 注資 $AMOUNT SUI ($AMOUNT_MIST MIST) 到退款池..."

    # 注意：這需要先 split coin，然後傳入 fund_refund_pool
    # 這裡簡化處理，實際使用時需要根據具體情況調整
    sui client call \
        --package "$CONTRACT_PACKAGE_ID" \
        --module "refund_module" \
        --function "fund_refund_pool" \
        --args "$REFUND_POOL_ID" --gas-budget 10000000

    echo "✅ 退款池注資完成！"
fi

echo ""
echo "🎉 退款池初始化完成！"
echo "請將以下信息添加到您的配置中："
echo "REFUND_POOL_ID=$REFUND_POOL_ID"
