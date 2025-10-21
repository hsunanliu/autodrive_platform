#!/bin/bash

# 日誌監控腳本
# 支持監控後端、支付等不同類型的日誌

set -e

# 顏色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 顯示使用說明
show_usage() {
    echo "使用方法: $0 [類型]"
    echo ""
    echo "類型:"
    echo "  backend    監控後端 API 日誌 (默認)"
    echo "  payment    監控支付相關日誌"
    echo "  all        監控所有日誌"
    echo ""
    echo "範例:"
    echo "  $0              # 監控後端日誌"
    echo "  $0 backend      # 監控後端日誌"
    echo "  $0 payment      # 監控支付日誌"
    echo "  $0 all          # 監控所有日誌"
}

# 默認類型
LOG_TYPE="${1:-backend}"

case $LOG_TYPE in
    backend)
        echo -e "${BLUE}📊 監控後端 API 日誌${NC}"
        echo "================================"
        echo ""
        echo "按 Ctrl+C 停止監控"
        echo ""
        docker-compose logs -f backend
        ;;
    payment)
        echo -e "${BLUE}💰 監控支付相關日誌${NC}"
        echo "================================"
        echo ""
        echo "按 Ctrl+C 停止監控"
        echo ""
        docker-compose logs -f backend | grep -i "release_payment\|escrow\|contract\|完成行程\|支付"
        ;;
    all)
        echo -e "${BLUE}📊 監控所有服務日誌${NC}"
        echo "================================"
        echo ""
        echo "按 Ctrl+C 停止監控"
        echo ""
        docker-compose logs -f
        ;;
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        echo "未知類型: $LOG_TYPE"
        show_usage
        exit 1
        ;;
esac
