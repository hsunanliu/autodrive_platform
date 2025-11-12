#!/usr/bin/env python3
"""
測試多停靠點（waypoints）功能
"""
import requests
import json

BASE_URL = "http://localhost:8000/api/v1"

def test_create_trip_with_waypoints():
    """測試創建帶有停靠點的行程"""

    print("=" * 60)
    print("測試：創建帶有停靠點的行程")
    print("=" * 60)

    # 1. 登入獲取 token
    print("\n1. 登入測試用戶...")
    login_data = {
        "identifier": "testuser001",
        "password": "password123"
    }

    response = requests.post(f"{BASE_URL}/users/login", json=login_data)
    if response.status_code != 200:
        print(f"❌ 登入失敗: {response.text}")
        return

    token = response.json()["access_token"]
    print(f"✅ 登入成功! Token: {token[:20]}...")

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    # 2. 創建帶有停靠點的行程
    print("\n2. 創建帶有 2 個停靠點的行程...")
    trip_data = {
        "pickup_lat": 25.0340,
        "pickup_lng": 121.5645,
        "pickup_address": "起點：台北市中心",
        "dropoff_lat": 25.0478,
        "dropoff_lng": 121.5173,
        "dropoff_address": "終點：台北車站",
        "waypoints": [
            {
                "lat": 25.0420,
                "lng": 121.5071,
                "address": "停靠點 1：西門町"
            },
            {
                "lat": 25.0330,
                "lng": 121.5654,
                "address": "停靠點 2：信義區"
            }
        ],
        "passenger_count": 1,
        "use_dynamic_pricing": False,
        "notes": "測試多停靠點功能"
    }

    response = requests.post(f"{BASE_URL}/trips/", json=trip_data, headers=headers)

    if response.status_code != 200:
        print(f"❌ 創建行程失敗: {response.status_code}")
        print(response.text)
        return

    trip = response.json()
    print(f"✅ 行程創建成功!")
    print(f"   行程 ID: {trip['trip_id']}")
    print(f"   距離: {trip['distance_km']:.2f} km")
    print(f"   預估時間: {trip['estimated_duration_minutes']} 分鐘")
    print(f"   總金額: {trip['fare_breakdown']['total_amount']} micro SUI")

    # 3. 檢查停靠點
    print(f"\n3. 檢查停靠點...")
    if 'waypoints' in trip and trip['waypoints']:
        print(f"✅ 找到 {len(trip['waypoints'])} 個停靠點:")
        for waypoint in trip['waypoints']:
            print(f"   {waypoint['sequence']}. {waypoint['address']}")
            print(f"      座標: ({waypoint['lat']}, {waypoint['lng']})")
    else:
        print("❌ 沒有找到停靠點!")
        return

    # 4. 查詢行程詳情
    print(f"\n4. 查詢行程詳情...")
    response = requests.get(f"{BASE_URL}/trips/{trip['trip_id']}", headers=headers)

    if response.status_code != 200:
        print(f"❌ 查詢失敗: {response.status_code}")
        return

    trip_detail = response.json()
    print(f"✅ 查詢成功!")

    if 'waypoints' in trip_detail and trip_detail['waypoints']:
        print(f"✅ 停靠點已正確儲存:")
        for waypoint in trip_detail['waypoints']:
            print(f"   {waypoint['sequence']}. {waypoint['address']}")
    else:
        print("❌ 查詢的行程詳情中沒有停靠點!")

    print("\n" + "=" * 60)
    print("✅ 測試完成!")
    print("=" * 60)

if __name__ == "__main__":
    try:
        test_create_trip_with_waypoints()
    except Exception as e:
        print(f"\n❌ 測試過程中發生錯誤: {e}")
        import traceback
        traceback.print_exc()
