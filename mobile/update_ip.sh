#!/bin/bash
# 自動更新 Flutter app 的後端 IP 配置
# 使用方法: ./update_ip.sh

echo "🔍 正在檢測當前 Mac 的 IP 地址..."

# 獲取當前 Mac 的 IP 地址（優先 Wi-Fi，其次有線網路）
IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

if [ -z "$IP" ]; then
    echo "❌ 無法獲取 IP 地址"
    echo "請確認你的 Mac 已連接到網路"
    exit 1
fi

echo "✅ 檢測到 IP: $IP"
echo ""

# 更新 app_config.local.dart
CONFIG_FILE="lib/config/app_config.local.dart"

cat > "$CONFIG_FILE" << EOF
/// 本地開發配置
/// 這個文件不會被提交到 git（在 .gitignore 中）
///
/// 當你的網路 IP 改變時，只需要修改這個文件即可
/// 不需要改動其他代碼

// 你的 Mac 當前 IP: $IP
String get localBackendUrl => 'http://$IP:8000/api/v1';
EOF

echo "✅ 配置文件已更新: $CONFIG_FILE"
echo "📱 新的後端 URL: http://$IP:8000/api/v1"
echo ""
echo "💡 提示："
echo "   1. 請重新啟動 Flutter app 讓配置生效"
echo "   2. 確認後端服務正在 http://$IP:8000 運行"
echo ""
