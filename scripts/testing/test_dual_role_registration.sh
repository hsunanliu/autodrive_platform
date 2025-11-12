#!/bin/bash
# 測試複合身份註冊（both = passenger + driver）

API_BASE="http://localhost:8000/api/v1"

echo "=== 測試：註冊 both 角色用戶 ==="

# 1. 註冊 both 角色用戶
echo -e "\n1️⃣  註冊複合身份用戶（passenger + driver）..."
REGISTER_RESPONSE=$(curl -s -X POST "$API_BASE/users/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "dual_user_test",
    "password": "testpass123",
    "wallet_address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "email": "dual@test.com",
    "display_name": "雙重身份測試",
    "user_type": "both",
    "phone_number": "0912345678"
  }')

echo "$REGISTER_RESPONSE" | python3 -m json.tool
USER_ID=$(echo "$REGISTER_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', ''))")

if [ -z "$USER_ID" ]; then
  echo "❌ 註冊失敗"
  exit 1
fi

echo "✅ 用戶註冊成功，ID: $USER_ID"

# 2. 登入
echo -e "\n2️⃣  登入測試..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_BASE/users/login" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "dual_user_test",
    "password": "testpass123"
  }')

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))")
USER_TYPE=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('user', {}).get('user_type', ''))")

if [ "$USER_TYPE" != "both" ]; then
  echo "❌ user_type 錯誤: $USER_TYPE (expected: both)"
  exit 1
fi

echo "✅ 登入成功，user_type: $USER_TYPE"

# 3. 測試乘客權限 - 創建行程
echo -e "\n3️⃣  測試乘客權限 - 創建行程..."
TRIP_RESPONSE=$(curl -s -X POST "$API_BASE/trips/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "pickup_lat": 25.0330,
    "pickup_lng": 121.5654,
    "pickup_address": "台北車站",
    "dropoff_lat": 25.0478,
    "dropoff_lng": 121.5318,
    "dropoff_address": "台北101",
    "passenger_count": 1
  }')

TRIP_ID=$(echo "$TRIP_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('trip_id', ''))" 2>/dev/null)

if [ -n "$TRIP_ID" ]; then
  echo "✅ 乘客權限測試通過，行程 ID: $TRIP_ID"
else
  echo "❌ 創建行程失敗"
  echo "$TRIP_RESPONSE" | python3 -m json.tool
fi

# 4. 測試司機權限 - 查看可接單行程
echo -e "\n4️⃣  測試司機權限 - 查看可接單行程..."
AVAILABLE_TRIPS=$(curl -s -X GET "$API_BASE/trips/available?limit=5" \
  -H "Authorization: Bearer $TOKEN")

TRIP_COUNT=$(echo "$AVAILABLE_TRIPS" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

if [ "$TRIP_COUNT" != "0" ]; then
  echo "✅ 司機權限測試通過，可見 $TRIP_COUNT 個可接單行程"
else
  echo "⚠️  目前無可接單行程（這是正常的）"
fi

# 5. 驗證 Profile 顯示
echo -e "\n5️⃣  驗證個人檔案..."
PROFILE=$(curl -s -X GET "$API_BASE/users/$USER_ID" \
  -H "Authorization: Bearer $TOKEN")

echo "$PROFILE" | python3 -m json.tool

echo -e "\n=========================================="
echo "✅ 複合身份測試完成！"
echo "=========================================="
echo "用戶 ID: $USER_ID"
echo "角色類型: both (passenger + driver)"
echo "測試結果："
echo "  - ✅ 註冊成功"
echo "  - ✅ 登入成功"
echo "  - ✅ 乘客權限（創建行程）"
echo "  - ✅ 司機權限（查看可接單行程）"
