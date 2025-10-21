#!/bin/bash

# Flutter 應用啟動腳本
# 支持多種啟動模式

set -e

# 顏色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 顯示使用說明
show_usage() {
    echo "使用方法: $0 [選項]"
    echo ""
    echo "選項:"
    echo "  -d, --device DEVICE    指定設備 (ios, android, 或設備 ID)"
    echo "  -l, --log              啟用日誌記錄到文件"
    echo "  -c, --clean            啟動前清理構建"
    echo "  -h, --help             顯示此幫助信息"
    echo ""
    echo "範例:"
    echo "  $0                     # 默認啟動"
    echo "  $0 -d ios              # 在 iOS 模擬器上啟動"
    echo "  $0 -d android          # 在 Android 模擬器上啟動"
    echo "  $0 -l                  # 啟動並記錄日誌"
    echo "  $0 -c -l               # 清理後啟動並記錄日誌"
    echo "  $0 -d 'iPhone 16 Plus' # 在特定 iOS 設備上啟動"
}

# 默認參數
DEVICE=""
ENABLE_LOG=false
CLEAN_BUILD=false

# 解析參數
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -l|--log)
            ENABLE_LOG=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "未知選項: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 AutoDrive Flutter 應用啟動${NC}"
echo "================================"
echo ""

# 進入 mobile 目錄
cd mobile

# 清理構建（如果需要）
if [ "$CLEAN_BUILD" = true ]; then
    echo -e "${YELLOW}🧹 清理之前的構建...${NC}"
    flutter clean
    echo ""
fi

# 獲取依賴
echo -e "${YELLOW}📦 獲取依賴...${NC}"
flutter pub get
echo ""

# 檢查設備
if [ -z "$DEVICE" ]; then
    echo -e "${YELLOW}🔍 檢查可用設備...${NC}"
    flutter devices
    echo ""
fi

# 構建啟動命令
CMD="flutter run"

if [ -n "$DEVICE" ]; then
    # 處理常見設備別名
    case $DEVICE in
        ios)
            # 啟動 iOS 模擬器
            echo -e "${YELLOW}📱 啟動 iOS 模擬器...${NC}"
            open -a Simulator
            sleep 3
            DEVICE="iPhone 16 Plus"
            ;;
        android)
            echo -e "${YELLOW}📱 使用 Android 模擬器...${NC}"
            # Android 模擬器會自動檢測
            ;;
    esac
    
    if [ -n "$DEVICE" ]; then
        CMD="$CMD -d \"$DEVICE\""
    fi
fi

# 啟動應用
echo -e "${GREEN}▶️  啟動應用...${NC}"
echo ""

if [ "$ENABLE_LOG" = true ]; then
    LOG_FILE="../logs/flutter_debug.log"
    echo -e "${YELLOW}📝 日誌將保存到: $LOG_FILE${NC}"
    echo ""
    eval $CMD 2>&1 | tee $LOG_FILE
else
    eval $CMD
fi

cd ..
