#!/bin/bash

echo "========================================="
echo "部署 Payment Escrow 智能合約"
echo "========================================="
echo ""

# 顏色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. 檢查 Sui CLI
echo -e "${YELLOW}步驟 1: 檢查 Sui CLI${NC}"
if ! command -v sui &> /dev/null; then
    echo -e "${RED}❌ Sui CLI 未安裝${NC}"
    echo "請安裝: cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui"
    exit 1
fi
echo -e "${GREEN}✅ Sui CLI 已安裝${NC}"
echo ""

# 2. 檢查當前網絡
echo -e "${YELLOW}步驟 2: 檢查網絡配置${NC}"
CURRENT_ENV=$(sui client active-env 2>/dev/null || echo "未配置")
echo "當前網絡: $CURRENT_ENV"

if [ "$CURRENT_ENV" != "testnet" ]; then
    echo -e "${YELLOW}切換到 testnet...${NC}"
    sui client switch --env testnet
fi
echo ""

# 3. 檢查錢包地址
echo -e "${YELLOW}步驟 3: 檢查錢包地址${NC}"
WALLET_ADDRESS=$(sui client active-address 2>/dev/null)
if [ -z "$WALLET_ADDRESS" ]; then
    echo -e "${RED}❌ 未找到活躍錢包${NC}"
    echo "請先配置錢包: sui client"
    exit 1
fi
echo -e "${GREEN}✅ 錢包地址: $WALLET_ADDRESS${NC}"
echo ""

# 4. 檢查餘額
echo -e "${YELLOW}步驟 4: 檢查 SUI 餘額${NC}"
sui client gas --json > /tmp/sui_gas.json 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 有可用的 gas${NC}"
    echo "詳細餘額:"
    sui client gas | head -5
else
    echo -e "${RED}❌ 餘額不足或查詢失敗${NC}"
    echo "請從水龍頭獲取測試幣: https://faucet.testnet.sui.io/"
    exit 1
fi
echo ""

# 5. 編譯合約
echo -e "${YELLOW}步驟 5: 編譯合約${NC}"
sui move build
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ 編譯失敗${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 編譯成功${NC}"
echo ""

# 6. 部署合約
echo -e "${YELLOW}步驟 6: 部署合約到 testnet${NC}"
echo "這可能需要幾秒鐘..."
echo ""

DEPLOY_OUTPUT=$(sui client publish --gas-budget 100000000 --json 2>&1)
DEPLOY_STATUS=$?

if [ $DEPLOY_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ 部署成功！${NC}"
    echo ""
    
    # 解析 Package ID
    PACKAGE_ID=$(echo "$DEPLOY_OUTPUT" | jq -r '.objectChanges[] | select(.type == "published") | .packageId' 2>/dev/null)
    
    if [ -n "$PACKAGE_ID" ] && [ "$PACKAGE_ID" != "null" ]; then
        echo "========================================="
        echo -e "${GREEN}📦 Package ID:${NC}"
        echo "$PACKAGE_ID"
        echo "========================================="
        echo ""
        
        # 保存到文件
        echo "$PACKAGE_ID" > .package_id
        echo -e "${GREEN}✅ Package ID 已保存到 .package_id${NC}"
        echo ""
        
        # 更新 .env 文件
        echo -e "${YELLOW}更新 .env 文件...${NC}"
        ENV_FILE="../.env"
        if [ -f "$ENV_FILE" ]; then
            # 備份
            cp "$ENV_FILE" "${ENV_FILE}.backup"
            
            # 更新 CONTRACT_PACKAGE_ID
            if grep -q "CONTRACT_PACKAGE_ID=" "$ENV_FILE"; then
                sed -i.bak "s|CONTRACT_PACKAGE_ID=.*|CONTRACT_PACKAGE_ID=$PACKAGE_ID|" "$ENV_FILE"
                echo -e "${GREEN}✅ 已更新 CONTRACT_PACKAGE_ID${NC}"
            else
                echo "CONTRACT_PACKAGE_ID=$PACKAGE_ID" >> "$ENV_FILE"
                echo -e "${GREEN}✅ 已添加 CONTRACT_PACKAGE_ID${NC}"
            fi
            
            rm -f "${ENV_FILE}.bak"
        fi
        echo ""
        
        # 顯示交易詳情
        TX_DIGEST=$(echo "$DEPLOY_OUTPUT" | jq -r '.digest' 2>/dev/null)
        if [ -n "$TX_DIGEST" ] && [ "$TX_DIGEST" != "null" ]; then
            echo "========================================="
            echo -e "${GREEN}🔗 交易 Hash:${NC}"
            echo "$TX_DIGEST"
            echo ""
            echo "查看交易:"
            echo "https://testnet.suivision.xyz/txblock/$TX_DIGEST"
            echo "========================================="
        fi
        echo ""
        
        echo -e "${GREEN}🎉 部署完成！${NC}"
        echo ""
        echo "下一步:"
        echo "1. 重啟後端: docker-compose restart backend"
        echo "2. 測試合約功能"
        echo ""
        
    else
        echo -e "${YELLOW}⚠️ 無法解析 Package ID${NC}"
        echo "完整輸出:"
        echo "$DEPLOY_OUTPUT"
    fi
else
    echo -e "${RED}❌ 部署失敗${NC}"
    echo "錯誤信息:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi
