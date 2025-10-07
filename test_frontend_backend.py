#!/usr/bin/env python3
"""
前後端整合測試腳本
測試 Flutter 應用與 FastAPI 後端的交互
"""

import asyncio
import httpx
import json

# 配置
BACKEND_URL = "http://localhost:8000/api/v1"

class FrontendBackendTester:
    """前後端整合測試器"""
    
    def __init__(self):
        self.token = None
        self.user_id = None
    
    async def test_all(self):
        """執行所有測試"""
        print("🧪 AutoDrive 前後端整合測試")
        print("=" * 50)
        
        # 1. 測試後端健康狀態
        await self.test_backend_health()
        
        # 2. 測試用戶註冊
        await self.test_user_registration()
        
        # 3. 測試用戶登入
        await self.test_user_login()
        
        # 4. 測試獲取附近車輛
        await self.test_get_vehicles()
        
        # 5. 測試行程預估
        await self.test_trip_estimate()
        
        # 6. 測試創建行程
        await self.test_create_trip()
        
        # 7. 測試獲取行程歷史
        await self.test_get_trip_history()
        
        # 8. 測試錢包餘額
        await self.test_wallet_balance()
        
        print("\n" + "=" * 50)
        print("📊 測試完成！")
    
    async def test_backend_health(self):
        """測試後端健康狀態"""
        print("\n🔍 測試後端健康狀態...")
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{BACKEND_URL.replace('/api/v1', '')}/health")
                
                if response.status_code == 200:
                    print("✅ 後端服務正常運行")
                else:
                    print(f"❌ 後端服務異常: {response.status_code}")
        except Exception as e:
            print(f"❌ 無法連接後端: {e}")
    
    async def test_user_registration(self):
        """測試用戶註冊"""
        print("\n🔍 測試用戶註冊...")
        
        user_data = {
            "username": "flutter_test_user",
            "password": "12345678",
            "wallet_address": "0x7777777777777777777777777777777777777777777777777777777777777777",
            "email": "flutter@test.com",
            "user_type": "passenger"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{BACKEND_URL}/users/register",
                    json=user_data,
                    timeout=10.0
                )
                
                if response.status_code in [200, 201]:
                    result = response.json()
                    self.user_id = result['id']
                    print(f"✅ 用戶註冊成功: ID {self.user_id}")
                elif response.status_code == 409:
                    print("✅ 用戶已存在 (正常)")
                else:
                    result = response.json()
                    print(f"❌ 註冊失敗: {result.get('detail', 'Unknown error')}")
        except Exception as e:
            print(f"❌ 註冊請求失敗: {e}")
    
    async def test_user_login(self):
        """測試用戶登入"""
        print("\n🔍 測試用戶登入...")
        
        login_data = {
            "identifier": "flutter_test_user",
            "password": "12345678"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{BACKEND_URL}/users/login",
                    json=login_data,
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    result = response.json()
                    self.token = result['access_token']
                    print("✅ 登入成功，已獲取 token")
                else:
                    result = response.json()
                    print(f"❌ 登入失敗: {result.get('detail', 'Unknown error')}")
        except Exception as e:
            print(f"❌ 登入請求失敗: {e}")
    
    async def test_get_vehicles(self):
        """測試獲取附近車輛"""
        print("\n🔍 測試獲取附近車輛...")
        
        if not self.token:
            print("❌ 需要先登入")
            return
        
        params = {
            "lat": 25.0330,
            "lng": 121.5654,
            "radius_km": 5.0,
            "limit": 10
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{BACKEND_URL}/vehicles/available",
                    params=params,
                    headers={"Authorization": f"Bearer {self.token}"},
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    vehicles = response.json()
                    print(f"✅ 找到 {len(vehicles)} 輛可用車輛")
                    
                    if vehicles:
                        vehicle = vehicles[0]
                        print(f"   示例車輛: {vehicle['vehicle_id']} ({vehicle['model']})")
                else:
                    print(f"❌ 獲取車輛失敗: {response.status_code}")
        except Exception as e:
            print(f"❌ 車輛請求失敗: {e}")
    
    async def test_trip_estimate(self):
        """測試行程預估"""
        print("\n🔍 測試行程預估...")
        
        params = {
            "pickup_lat": 25.0330,
            "pickup_lng": 121.5654,
            "dropoff_lat": 25.0478,
            "dropoff_lng": 121.5173
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{BACKEND_URL}/trips/estimate",
                    params=params,
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    estimate = response.json()
                    print(f"✅ 行程預估成功")
                    print(f"   距離: {estimate['estimated_distance_km']:.2f} 公里")
                    print(f"   預估費用: {estimate['estimated_fare']['total_amount']} micro IOTA")
                    print(f"   可用車輛: {estimate['available_vehicles_count']} 輛")
                else:
                    print(f"❌ 行程預估失敗: {response.status_code}")
        except Exception as e:
            print(f"❌ 預估請求失敗: {e}")
    
    async def test_create_trip(self):
        """測試創建行程"""
        print("\n🔍 測試創建行程...")
        
        if not self.token:
            print("❌ 需要先登入")
            return
        
        trip_data = {
            "pickup_lat": 25.0330,
            "pickup_lng": 121.5654,
            "pickup_address": "台北車站",
            "dropoff_lat": 25.0478,
            "dropoff_lng": 121.5173,
            "dropoff_address": "西門町",
            "passenger_count": 1,
            "preferred_vehicle_type": "sedan",
            "notes": "Flutter 測試行程"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{BACKEND_URL}/trips/",
                    json=trip_data,
                    headers={"Authorization": f"Bearer {self.token}"},
                    timeout=10.0
                )
                
                if response.status_code in [200, 201]:
                    trip = response.json()
                    print(f"✅ 行程創建成功: ID {trip['trip_id']}")
                    print(f"   狀態: {trip['status']}")
                    print(f"   費用: {trip['fare_breakdown']['total_amount']} micro IOTA")
                else:
                    result = response.json()
                    print(f"❌ 創建行程失敗: {result.get('detail', 'Unknown error')}")
        except Exception as e:
            print(f"❌ 創建行程請求失敗: {e}")
    
    async def test_get_trip_history(self):
        """測試獲取行程歷史"""
        print("\n🔍 測試獲取行程歷史...")
        
        if not self.token:
            print("❌ 需要先登入")
            return
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{BACKEND_URL}/trips/",
                    headers={"Authorization": f"Bearer {self.token}"},
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    trips = response.json()
                    print(f"✅ 獲取行程歷史成功: {len(trips)} 筆記錄")
                    
                    if trips:
                        trip = trips[0]
                        print(f"   最新行程: ID {trip['trip_id']} ({trip['status']})")
                else:
                    print(f"❌ 獲取行程歷史失敗: {response.status_code}")
        except Exception as e:
            print(f"❌ 行程歷史請求失敗: {e}")
    
    async def test_wallet_balance(self):
        """測試錢包餘額"""
        print("\n🔍 測試錢包餘額...")
        
        if not self.token:
            print("❌ 需要先登入")
            return
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{BACKEND_URL}/trips/payment/wallet/balance",
                    headers={"Authorization": f"Bearer {self.token}"},
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    balance = response.json()
                    print(f"✅ 錢包餘額查詢成功")
                    print(f"   餘額: {balance['balance_iota']} IOTA")
                    print(f"   地址: {balance['wallet_address']}")
                else:
                    print(f"❌ 錢包餘額查詢失敗: {response.status_code}")
        except Exception as e:
            print(f"❌ 錢包餘額請求失敗: {e}")

async def main():
    """主函數"""
    tester = FrontendBackendTester()
    await tester.test_all()

if __name__ == "__main__":
    asyncio.run(main())