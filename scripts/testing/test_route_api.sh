#!/bin/bash

# 測試路線 API
# 用於驗證獲取行程路線功能

set -e

echo "🧪 測試路線 API"
echo "================================"
echo ""

BASE_URL="http://localhost:8000/api/v1"

# 1. 登入乘客
echo "1️⃣  登入測試乘客..."
LOGIN_RESPONSE=$(curl -s -X POST "${BASE_URL}/users/login" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "testuser001",
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

# 2. 創建帶停靠點的行程
echo "2️⃣  創建帶停靠點的測試行程..."
CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}/trips/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "pickup_lat": 25.0330,
    "pickup_lng": 121.5654,
    "pickup_address": "台北101",
    "dropoff_lat": 25.0478,
    "dropoff_lng": 121.5173,
    "dropoff_address": "台北車站",
    "passenger_count": 1,
    "waypoints": [
      {
        "lat": 25.0420,
        "lng": 121.5071,
        "address": "西門町"
      }
    ]
  }')

TRIP_ID=$(echo $CREATE_RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['trip_id'])" 2>/dev/null)

if [ -z "$TRIP_ID" ]; then
    echo "❌ 創建行程失敗"
    echo "響應: $CREATE_RESPONSE"
    exit 1
fi

echo "✅ 行程創建成功 (ID: $TRIP_ID)"
echo ""

# 3. 獲取行程路線
echo "3️⃣  獲取行程路線..."
ROUTE_RESPONSE=$(curl -s -X GET "${BASE_URL}/trips/${TRIP_ID}/route" \
  -H "Authorization: Bearer $TOKEN")

echo "路線響應:"
echo "$ROUTE_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$ROUTE_RESPONSE"
echo ""

# 4. 驗證響應
echo "4️⃣  驗證響應..."

# 檢查是否成功
SUCCESS=$(echo "$ROUTE_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null)

if [ "$SUCCESS" = "True" ]; then
    # 獲取路線點數量
    ROUTE_POINTS_COUNT=$(echo "$ROUTE_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('route_points', [])))" 2>/dev/null)

    # 獲取停靠點數量
    WAYPOINTS_COUNT=$(echo "$ROUTE_RESPONSE" | python3 -c "import sys, json; print(len(json.load(sys.stdin).get('waypoints', [])))" 2>/dev/null)

    echo "✅ 測試成功!"
    echo "   - 路線點數量: $ROUTE_POINTS_COUNT"
    echo "   - 停靠點數量: $WAYPOINTS_COUNT"

    # 顯示第一個和最後一個路線點
    FIRST_POINT=$(echo "$ROUTE_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['route_points'][0] if data['route_points'] else 'N/A')" 2>/dev/null)
    LAST_POINT=$(echo "$ROUTE_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['route_points'][-1] if data['route_points'] else 'N/A')" 2>/dev/null)

    echo "   - 起點: $FIRST_POINT"
    echo "   - 終點: $LAST_POINT"
else
    echo "❌ 測試失敗: API 返回錯誤"
    exit 1
fi

echo ""
echo "================================"
echo "✅ 路線 API 測試完成"
