#!/bin/bash

echo "📱 測試 Firebase 配置"
echo "======================================"
echo ""
echo "✅ 檢查配置文件："

# 檢查 GoogleService-Info.plist
if [ -f "mobile/ios/Runner/GoogleService-Info.plist" ]; then
    echo "  ✓ GoogleService-Info.plist 存在"
else
    echo "  ✗ GoogleService-Info.plist 不存在"
fi

# 檢查 firebase_options.dart
if [ -f "mobile/lib/firebase_options.dart" ]; then
    echo "  ✓ firebase_options.dart 存在"
else
    echo "  ✗ firebase_options.dart 不存在"
fi

echo ""
echo "======================================"
echo "請運行 Flutter app 並查看以下日誌："
echo ""
echo "1. Firebase 初始化成功："
echo "   ✅ Firebase 初始化成功"
echo ""
echo "2. FCM Token 獲取成功："
echo "   🔑 FCM Token: xxxxx"
echo ""
echo "3. WebSocket 連接並發送 FCM Token："
echo "   📤 發送 FCM Token 到後端"
echo ""
echo "======================================"
echo ""
echo "現在運行 Flutter app 進行測試..."
echo ""

cd mobile
flutter run -d 00008130-001A24C201F2001C
