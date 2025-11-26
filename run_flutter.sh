#!/bin/bash

# AutoDrive Flutter 快速啟動腳本
# 適用於測試多停靠點功能和推送通知

set -e

echo "🚀 AutoDrive Flutter 啟動中..."
echo ""

# 進入 mobile 目錄
cd mobile

# 檢查設備並解析
echo "📱 檢查連接的設備..."
devices_output=$(flutter devices 2>/dev/null | grep "•" | grep -v "No devices found" | grep -v "No wireless devices")

# 顯示設備列表
echo ""
echo "可用設備："
echo "─────────────────────────────────────────"

counter=1
declare -a device_ids_array

# 使用 while read 循環來兼容 Bash 3.2
while IFS= read -r device; do
    if [ -z "$device" ]; then
        continue
    fi

    # 提取設備 ID (第二個 • 後面的內容)
    device_id=$(echo "$device" | awk -F '•' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')
    # 提取設備名稱 (第一個 • 前面的內容)
    device_name=$(echo "$device" | awk -F '•' '{gsub(/^[ \t]+|[ \t]+$/, "", $1); print $1}')
    # 提取平台類型 (第三個 • 後面的內容)
    platform=$(echo "$device" | awk -F '•' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')

    # 標記真機
    if [[ "$device" == *"mobile"* ]] && [[ "$device" != *"simulator"* ]]; then
        echo "  [$counter] 📱 $device_name ($platform) ← 真機"
    elif [[ "$device" == *"simulator"* ]]; then
        echo "  [$counter] 📲 $device_name ($platform) ← 模擬器"
    else
        echo "  [$counter] 💻 $device_name ($platform)"
    fi

    device_ids_array[$counter]="$device_id"
    ((counter++))
done <<< "$devices_output"

echo "─────────────────────────────────────────"
echo ""

# 提示用戶選擇
read -p "請選擇設備編號 (按 Enter 使用真機 [1]): " choice

# 默認選擇第一個設備（通常是真機）
if [ -z "$choice" ]; then
    choice=1
    echo "✅ 自動選擇 [1] (真機)"
fi

# 獲取選擇的設備 ID
selected_device="${device_ids_array[$choice]}"

if [ -z "$selected_device" ]; then
    echo "❌ 無效的選擇，使用第一個設備"
    selected_device="${device_ids_array[1]}"
fi

# 運行應用
echo ""
echo "▶️  在設備 $selected_device 上啟動應用..."
echo ""
flutter run -d "$selected_device"
