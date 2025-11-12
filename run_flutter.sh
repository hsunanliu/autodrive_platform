#!/bin/bash

# AutoDrive Flutter 快速啟動腳本
# 適用於測試多停靠點功能

set -e

echo "🚀 AutoDrive Flutter 啟動中..."
echo ""

# 進入 mobile 目錄
cd mobile

# 檢查設備
echo "📱 檢查連接的設備..."
flutter devices
echo ""

# 確認要繼續
read -p "請選擇設備 (按 Enter 使用第一個設備): " device

# 運行應用
if [ -z "$device" ]; then
    echo "▶️  啟動應用..."
    flutter run
else
    echo "▶️  在設備 $device 上啟動應用..."
    flutter run -d "$device"
fi
