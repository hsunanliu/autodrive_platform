#!/bin/bash

echo "🚀 啟動 Flutter iOS 模擬器應用"
echo "================================"
echo ""
echo "📱 目標設備: iPhone 16 Plus"
echo "🔧 後端 API: http://localhost:8000"
echo ""
echo "⏳ 正在編譯和啟動應用..."
echo ""

# 確保模擬器已啟動
open -a Simulator
sleep 3

cd mobile
flutter run -d "iPhone 16 Plus"
