#!/bin/bash

# 快速更新本地開發 IP 地址
# 當你的網路 IP 改變時運行此腳本

echo "🔍 偵測當前 Mac IP 地址..."
echo ""

# 獲取當前 IP（排除 localhost 和 169.254 開頭的）
CURRENT_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | grep -v "169.254" | awk '{print $2}' | head -1)

if [ -z "$CURRENT_IP" ]; then
    echo "❌ 無法偵測到有效的 IP 地址"
    echo "   請確保你已連接到 WiFi 或以太網"
    exit 1
fi

echo "✅ 偵測到 IP: $CURRENT_IP"
echo ""

# 檢查配置文件是否存在
CONFIG_FILE="mobile/lib/config/app_config.local.dart"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  配置文件不存在，從示例創建..."
    cp mobile/lib/config/app_config.local.dart.example "$CONFIG_FILE"
fi

# 更新配置文件
echo "📝 更新配置文件..."
cat > "$CONFIG_FILE" << EOF
/// 本地開發配置
/// 這個文件不會被提交到 git（在 .gitignore 中）
///
/// 當你的網路 IP 改變時，只需要修改這個文件即可
/// 不需要改動其他代碼

// 你的 Mac 當前 IP: $CURRENT_IP
String get localBackendUrl => 'http://$CURRENT_IP:8000/api/v1';
EOF

echo "✅ 配置已更新！"
echo ""
echo "當前後端 URL: http://$CURRENT_IP:8000/api/v1"
echo ""
echo "接下來："
echo "1. 確保後端正在運行: docker-compose ps"
echo "2. 運行 Flutter app: ./run_flutter.sh"
echo ""
