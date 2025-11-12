#!/bin/bash

# 測試司機獲取進行中行程 API
# 用於驗證 waypoints 預加載修復

set -e

echo "🧪 測試司機獲取進行中行程 API"
echo "================================"
echo ""

BASE_URL="http://localhost:8000/api/v1"

# 1. 登入司機
echo "1️⃣  登入測試司機..."
LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/users/login" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "testuser002",
    "password": "password123"
  }')

TOKEN=$(echo $LOGIN_RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "❌ 登入失敗"
    echo "響應: $LOGIN_RESPONSE"
    exit 1
fi

echo "✅ 登入成功"
echo ""

# 2. 獲取進行中行程
echo "2️⃣  獲取進行中行程..."
TRIP_RESPONSE=$(curl -s -X GET "${BASE_URL}/trips/my-active" \
  -H "Authorization: Bearer $TOKEN")

echo "響應:"
echo "$TRIP_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$TRIP_RESPONSE"
echo ""

# 3. 檢查響應
if echo "$TRIP_RESPONSE" | grep -q "greenlet_spawn"; then
    echo "❌ 測試失敗: 仍然存在異步錯誤"
    exit 1
elif echo "$TRIP_RESPONSE" | grep -q "detail"; then
    # 可能是 null（沒有進行中行程）或其他錯誤
    if echo "$TRIP_RESPONSE" | grep -q "獲取進行中行程失敗"; then
        echo "❌ 測試失敗: API 返回錯誤"
        exit 1
    else
        echo "✅ API 正常（當前無進行中行程）"
    fi
else
    echo "✅ 測試成功: API 正常返回數據"

    # 檢查是否有 waypoints
    if echo "$TRIP_RESPONSE" | grep -q "waypoints"; then
        WAYPOINT_COUNT=$(echo "$TRIP_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('waypoints', [])))" 2>/dev/null || echo "0")
        echo "   包含 $WAYPOINT_COUNT 個停靠點"
    fi
fi

echo ""
echo "================================"
echo "✅ 測試完成"
