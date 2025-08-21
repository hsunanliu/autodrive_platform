# backend/app/services/iota_service.py（1.1.4 版本）
from typing import Dict, Any, Optional
import asyncio

try:
    from iota_sdk import Client
    SDK_AVAILABLE = True
    print("✅ IOTA SDK loaded successfully")
except ImportError as e:
    SDK_AVAILABLE = False
    print(f"❌ IOTA SDK import failed: {e}")

from app.config import settings

class IOTAService:
    """IOTA SDK 服務 - 使用 1.1.4 版本完整功能"""
    
    def __init__(self):
        if SDK_AVAILABLE:
            try:
                # 1.1.4 版本的初始化方式
                self.client = Client({"nodes": [settings.IOTA_NODE_URL]})
                print(f"✅ IOTA Client initialized with {settings.IOTA_NODE_URL}")
            except Exception as e:
                print(f"⚠️ Client init failed: {e}")
                self.client = None
        else:
            self.client = None
        
        self.package_id = settings.CONTRACT_PACKAGE_ID
    
    async def get_network_info(self) -> Dict[str, Any]:
        """獲取網路資訊（1.1.4 API）"""
        if not SDK_AVAILABLE or not self.client:
            return {"status": "sdk_unavailable"}
        
        try:
            # 1.1.4 版本的方法
            info = await self.client.get_info()
            return {
                "status": "connected",
                "chain_id": info.chain_id,
                "epoch": info.epoch,
                "checkpoint": info.checkpoint,
                "software_version": info.software_version,
                "sdk_version": "1.1.4"
            }
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "sdk_version": "1.1.4"
            }
    
    async def get_object(self, object_id: str) -> Optional[Dict[str, Any]]:
        """獲取鏈上對象（1.1.4 API）"""
        if not SDK_AVAILABLE or not self.client:
            return None
        
        try:
            result = await self.client.get_object(
                object_id=object_id,
                options={
                    "showType": True,
                    "showOwner": True,
                    "showPreviousTransaction": True,
                    "showContent": True,
                    "showStorageRebate": True
                }
            )
            return result
        except Exception as e:
            print(f"Failed to get object {object_id}: {e}")
            return None
    
    async def get_all_registry_stats(self) -> Dict[str, Any]:
        """獲取所有Registry的統計數據"""
        results = {}
        
        try:
            # 獲取 UserRegistry
            user_registry = await self.get_object(settings.USER_REGISTRY_ID)
            if user_registry and user_registry.get("data"):
                results["user_registry"] = {
                    "object_id": settings.USER_REGISTRY_ID,
                    "total_users": user_registry["data"]["content"]["fields"].get("total_users", 0),
                    "admin": user_registry["data"]["content"]["fields"].get("admin")
                }
            
            # 獲取 VehicleRegistry
            vehicle_registry = await self.get_object(settings.VEHICLE_REGISTRY_ID)
            if vehicle_registry and vehicle_registry.get("data"):
                results["vehicle_registry"] = {
                    "object_id": settings.VEHICLE_REGISTRY_ID,
                    "total_vehicles": vehicle_registry["data"]["content"]["fields"].get("total_vehicles", 0),
                    "admin": vehicle_registry["data"]["content"]["fields"].get("admin")
                }
            
            # 獲取 MatchingService
            matching_service = await self.get_object(settings.MATCHING_SERVICE_ID)
            if matching_service and matching_service.get("data"):
                results["matching_service"] = {
                    "object_id": settings.MATCHING_SERVICE_ID,
                    "total_requests": matching_service["data"]["content"]["fields"].get("total_requests", 0),
                    "total_matches": matching_service["data"]["content"]["fields"].get("total_matches", 0),
                    "service_fee_rate": matching_service["data"]["content"]["fields"].get("service_fee_rate", 0)
                }
            
            return {
                "status": "success",
                "sdk_version": "1.1.4",
                "data": results
            }
            
        except Exception as e:
            return {
                "status": "error",
                "error": str(e),
                "fallback": "check_individual_contracts"
            }

# 全局服務實例
_iota_service = None

def get_iota_service() -> IOTAService:
    global _iota_service
    if _iota_service is None:
        _iota_service = IOTAService()
    return _iota_service
