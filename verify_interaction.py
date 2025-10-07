#!/usr/bin/env python3
"""
合約與後端交互驗證腳本
用於確認智能合約與後端服務的連接狀態
"""

import asyncio
import httpx
import json
from datetime import datetime

# 配置
BACKEND_URL = "http://localhost:8000"
IOTA_NODE_URL = "https://api.testnet.iota.cafe"
CONTRACT_PACKAGE_ID = "0xa353f4acea9dbacd0cc7af37479b277299160d9288495d017ec4d824ea7a5d31"
USER_REGISTRY_ID = "0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f"
VEHICLE_REGISTRY_ID = "0xfaf54e90664e669943e07e9845dbd2523e71920b04dd5bf264700a68c1370ce4"

class InteractionVerifier:
    """交互驗證器"""
    
    def __init__(self):
        self.results = []
    
    async def verify_all(self):
        """執行所有驗證"""
        print("🔍 開始驗證合約與後端交互...")
        print("=" * 50)
        
        # 1. 驗證後端服務狀態
        await self.check_backend_health()
        
        # 2. 驗證 IOTA 節點連接
        await self.check_iota_node()
        
        # 3. 驗證智能合約部署
        await self.check_contracts_deployed()
        
        # 4. 驗證後端合約服務
        await self.check_backend_contract_service()
        
        # 5. 驗證完整流程
        await self.test_full_interaction()
        
        # 輸出結果
        self.print_summary()
    
    async def check_backend_health(self):
        """檢查後端健康狀態"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{BACKEND_URL}/health", timeout=10.0)
                if response.status_code == 200:
                    self.log_success("✅ 後端服務", "運行正常")
                else:
                    self.log_error("❌ 後端服務", f"狀態碼: {response.status_code}")
        except Exception as e:
            self.log_error("❌ 後端服務", f"連接失敗: {e}")
    
    async def check_iota_node(self):
        """檢查 IOTA 節點連接"""
        try:
            payload = {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "iota_getChainIdentifier",
                "params": []
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    IOTA_NODE_URL,
                    json=payload,
                    headers={"Content-Type": "application/json"},
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    result = response.json()
                    if "result" in result:
                        self.log_success("✅ IOTA 節點", f"連接成功 - 鏈ID: {result['result']}")
                    else:
                        self.log_error("❌ IOTA 節點", f"RPC 錯誤: {result.get('error', 'Unknown')}")
                else:
                    self.log_error("❌ IOTA 節點", f"HTTP 錯誤: {response.status_code}")
        except Exception as e:
            self.log_error("❌ IOTA 節點", f"連接失敗: {e}")
    
    async def check_contracts_deployed(self):
        """檢查智能合約部署狀態"""
        contracts = [
            ("合約包", CONTRACT_PACKAGE_ID),
            ("用戶註冊", USER_REGISTRY_ID),
            ("車輛註冊", VEHICLE_REGISTRY_ID)
        ]
        
        for name, object_id in contracts:
            try:
                payload = {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "iota_getObject",
                    "params": [object_id, {"showContent": False}]
                }
                
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        IOTA_NODE_URL,
                        json=payload,
                        headers={"Content-Type": "application/json"},
                        timeout=10.0
                    )
                    
                    if response.status_code == 200:
                        result = response.json()
                        if "result" in result and "data" in result["result"]:
                            version = result["result"]["data"]["version"]
                            self.log_success(f"✅ {name}合約", f"已部署 - 版本: {version}")
                        else:
                            self.log_error(f"❌ {name}合約", "未找到或已刪除")
                    else:
                        self.log_error(f"❌ {name}合約", f"查詢失敗: {response.status_code}")
            except Exception as e:
                self.log_error(f"❌ {name}合約", f"檢查失敗: {e}")
    
    async def check_backend_contract_service(self):
        """檢查後端合約服務"""
        try:
            # 測試用戶註冊 API
            user_data = {
                "username": "verify_test_user",
                "password": "password123",
                "wallet_address": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
                "email": "verify@test.com",
                "user_type": "passenger"
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{BACKEND_URL}/api/v1/users/register",
                    json=user_data,
                    timeout=30.0
                )
                
                if response.status_code in [200, 201]:
                    self.log_success("✅ 後端合約服務", "用戶註冊 API 正常")
                elif response.status_code == 409:
                    self.log_success("✅ 後端合約服務", "用戶註冊 API 正常 (用戶已存在)")
                else:
                    result = response.json()
                    self.log_error("❌ 後端合約服務", f"註冊失敗: {result.get('detail', 'Unknown')}")
        except Exception as e:
            self.log_error("❌ 後端合約服務", f"測試失敗: {e}")
    
    async def test_full_interaction(self):
        """測試完整交互流程"""
        try:
            # 1. 創建測試用戶
            user_data = {
                "username": f"verify_user_{int(datetime.now().timestamp())}",
                "password": "password123",
                "wallet_address": f"0x{'1' * 64}",
                "email": "verify@interaction.test",
                "user_type": "passenger"
            }
            
            async with httpx.AsyncClient() as client:
                # 註冊用戶
                response = await client.post(
                    f"{BACKEND_URL}/api/v1/users/register",
                    json=user_data,
                    timeout=30.0
                )
                
                if response.status_code not in [200, 201]:
                    raise Exception(f"用戶註冊失敗: {response.status_code}")
                
                user_result = response.json()
                
                # 登入用戶
                login_data = {
                    "identifier": user_data["username"],
                    "password": user_data["password"]
                }
                
                response = await client.post(
                    f"{BACKEND_URL}/api/v1/users/login",
                    json=login_data,
                    timeout=10.0
                )
                
                if response.status_code != 200:
                    raise Exception(f"用戶登入失敗: {response.status_code}")
                
                login_result = response.json()
                token = login_result["access_token"]
                
                # 測試錢包餘額查詢
                response = await client.get(
                    f"{BACKEND_URL}/api/v1/trips/payment/wallet/balance",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=10.0
                )
                
                if response.status_code == 200:
                    balance_result = response.json()
                    self.log_success("✅ 完整交互", f"錢包餘額: {balance_result['balance_iota']} IOTA")
                else:
                    raise Exception(f"餘額查詢失敗: {response.status_code}")
                
        except Exception as e:
            self.log_error("❌ 完整交互", f"測試失敗: {e}")
    
    def log_success(self, component: str, message: str):
        """記錄成功"""
        result = {"status": "success", "component": component, "message": message}
        self.results.append(result)
        print(f"{component}: {message}")
    
    def log_error(self, component: str, message: str):
        """記錄錯誤"""
        result = {"status": "error", "component": component, "message": message}
        self.results.append(result)
        print(f"{component}: {message}")
    
    def print_summary(self):
        """輸出總結"""
        print("\n" + "=" * 50)
        print("📊 驗證結果總結")
        print("=" * 50)
        
        success_count = len([r for r in self.results if r["status"] == "success"])
        error_count = len([r for r in self.results if r["status"] == "error"])
        
        print(f"✅ 成功: {success_count}")
        print(f"❌ 失敗: {error_count}")
        print(f"📈 成功率: {success_count / len(self.results) * 100:.1f}%")
        
        if error_count > 0:
            print("\n🔧 需要修復的問題:")
            for result in self.results:
                if result["status"] == "error":
                    print(f"  • {result['component']}: {result['message']}")
        
        print("\n🎯 交互狀態:", "✅ 正常" if error_count == 0 else "⚠️ 需要修復")

async def main():
    """主函數"""
    verifier = InteractionVerifier()
    await verifier.verify_all()

if __name__ == "__main__":
    asyncio.run(main())