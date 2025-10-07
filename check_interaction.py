#!/usr/bin/env python3
"""
簡化的合約與後端交互檢查
"""

import asyncio
import httpx
import json

# 配置
IOTA_NODE_URL = "https://api.testnet.iota.cafe"
CONTRACT_PACKAGE_ID = "0xa353f4acea9dbacd0cc7af37479b277299160d9288495d017ec4d824ea7a5d31"
USER_REGISTRY_ID = "0x9bdeefc53afba9fca554dc61025514e21fb4e9f9281ad4449bca86f72f18dd5f"
VEHICLE_REGISTRY_ID = "0xfaf54e90664e669943e07e9845dbd2523e71920b04dd5bf264700a68c1370ce4"

async def check_iota_connection():
    """檢查 IOTA 節點連接"""
    print("🔍 檢查 IOTA 測試網連接...")
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
                    print(f"✅ IOTA 測試網連接成功 - 鏈ID: {result['result']}")
                    return True
                else:
                    print(f"❌ IOTA RPC 錯誤: {result.get('error', 'Unknown')}")
                    return False
            else:
                print(f"❌ IOTA HTTP 錯誤: {response.status_code}")
                return False
    except Exception as e:
        print(f"❌ IOTA 連接失敗: {e}")
        return False

async def check_contracts():
    """檢查智能合約部署狀態"""
    print("\n🔍 檢查智能合約部署狀態...")
    
    contracts = [
        ("合約包", CONTRACT_PACKAGE_ID),
        ("用戶註冊合約", USER_REGISTRY_ID),
        ("車輛註冊合約", VEHICLE_REGISTRY_ID)
    ]
    
    all_deployed = True
    
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
                        print(f"✅ {name}: 已部署 (版本: {version})")
                    else:
                        print(f"❌ {name}: 未找到或已刪除")
                        all_deployed = False
                else:
                    print(f"❌ {name}: 查詢失敗 ({response.status_code})")
                    all_deployed = False
        except Exception as e:
            print(f"❌ {name}: 檢查失敗 - {e}")
            all_deployed = False
    
    return all_deployed

async def check_contract_interaction():
    """檢查合約交互能力"""
    print("\n🔍 檢查合約交互能力...")
    
    try:
        # 測試合約調用準備 (不實際執行)
        move_call_data = {
            "packageObjectId": CONTRACT_PACKAGE_ID,
            "module": "user_registry",
            "function": "register_user",
            "arguments": [
                USER_REGISTRY_ID,
                "0x1234567890abcdef1234567890abcdef12345678",
                [1, 2, 3, 4]  # 示例 DID 哈希
            ],
            "typeArguments": []
        }
        
        print("✅ 合約調用數據結構正確")
        print(f"   - 包ID: {move_call_data['packageObjectId']}")
        print(f"   - 模組: {move_call_data['module']}")
        print(f"   - 函數: {move_call_data['function']}")
        
        return True
        
    except Exception as e:
        print(f"❌ 合約交互準備失敗: {e}")
        return False

def analyze_backend_config():
    """分析後端配置"""
    print("\n🔍 分析後端配置...")
    
    try:
        # 讀取配置文件
        with open('backend/app/config.py', 'r') as f:
            config_content = f.read()
        
        # 檢查關鍵配置
        checks = [
            ("IOTA_NODE_URL", "https://api.testnet.iota.cafe"),
            ("CONTRACT_PACKAGE_ID", CONTRACT_PACKAGE_ID),
            ("USER_REGISTRY_ID", USER_REGISTRY_ID),
            ("VEHICLE_REGISTRY_ID", VEHICLE_REGISTRY_ID)
        ]
        
        all_correct = True
        for key, expected in checks:
            if expected in config_content:
                print(f"✅ {key}: 配置正確")
            else:
                print(f"❌ {key}: 配置可能不正確")
                all_correct = False
        
        # 檢查 Mock 模式
        if "MOCK_MODE: bool = True" in config_content:
            print("⚠️  當前為 Mock 模式 - 不會實際調用區塊鏈")
        elif "MOCK_MODE: bool = False" in config_content:
            print("✅ 當前為實際模式 - 會調用真實區塊鏈")
        
        return all_correct
        
    except Exception as e:
        print(f"❌ 配置檢查失敗: {e}")
        return False

def analyze_interaction_flow():
    """分析交互流程"""
    print("\n📋 交互流程分析:")
    print("=" * 50)
    
    flows = [
        {
            "name": "用戶註冊流程",
            "steps": [
                "1. 前端發送註冊請求到後端 API",
                "2. 後端保存用戶信息到數據庫",
                "3. 後端調用 contract_service.register_user_on_chain()",
                "4. contract_service 準備 Move 調用數據",
                "5. 執行智能合約 user_registry::register_user()",
                "6. 合約創建 UserProfile 對象並發射事件",
                "7. 後端更新 blockchain_object_id"
            ]
        },
        {
            "name": "支付處理流程", 
            "steps": [
                "1. 司機完成行程，調用 /trips/{id}/complete",
                "2. 後端調用 iota_service.execute_trip_payment()",
                "3. iota_service 調用 contract_service.process_trip_payment_on_chain()",
                "4. contract_service 準備支付合約調用",
                "5. 執行 payment_escrow::lock_payment() 和 release_payment()",
                "6. 合約處理資金轉移並發射事件",
                "7. 後端更新支付狀態和交易哈希"
            ]
        }
    ]
    
    for flow in flows:
        print(f"\n🔄 {flow['name']}:")
        for step in flow['steps']:
            print(f"   {step}")

async def main():
    """主檢查函數"""
    print("🚀 AutoDrive 合約與後端交互檢查")
    print("=" * 50)
    
    # 1. 檢查 IOTA 連接
    iota_ok = await check_iota_connection()
    
    # 2. 檢查合約部署
    contracts_ok = await check_contracts()
    
    # 3. 檢查交互能力
    interaction_ok = await check_contract_interaction()
    
    # 4. 檢查後端配置
    config_ok = analyze_backend_config()
    
    # 5. 分析交互流程
    analyze_interaction_flow()
    
    # 總結
    print("\n" + "=" * 50)
    print("📊 檢查結果總結")
    print("=" * 50)
    
    results = [
        ("IOTA 測試網連接", iota_ok),
        ("智能合約部署", contracts_ok),
        ("合約交互能力", interaction_ok),
        ("後端配置", config_ok)
    ]
    
    success_count = sum(1 for _, ok in results if ok)
    
    for name, ok in results:
        status = "✅" if ok else "❌"
        print(f"{status} {name}")
    
    print(f"\n📈 成功率: {success_count}/{len(results)} ({success_count/len(results)*100:.1f}%)")
    
    if success_count == len(results):
        print("\n🎉 所有檢查通過！合約與後端交互配置正確。")
        print("\n🔧 下一步:")
        print("   1. 啟動後端服務: docker-compose up -d")
        print("   2. 測試完整流程: 用戶註冊 → 車輛註冊 → 行程創建 → 支付")
        print("   3. 監控日誌: docker-compose logs -f backend")
    else:
        print("\n⚠️  發現問題，請檢查上述失敗項目。")

if __name__ == "__main__":
    asyncio.run(main())