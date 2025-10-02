# backend/app/services/escrow_service.py
"""
託管服務 - 僅處理鏈上支付鎖定和釋放
"""

import logging
import hashlib
from typing import Dict, Any
from datetime import datetime

from app.config import settings

logger = logging.getLogger(__name__)

class EscrowService:
    """支付託管服務 - 僅與智能合約互動"""
    
    def __init__(self):
        self.package_id = settings.CONTRACT_PACKAGE_ID
        self.node_url = settings.IOTA_NODE_URL
    
    async def lock_payment(
        self,
        passenger_wallet: str,
        driver_wallet: str,
        trip_id: int,
        amount: int,
        platform_fee: int
    ) -> Dict[str, Any]:
        """
        鎖定支付 - 準備交易數據
        
        Returns:
            交易數據，需要前端錢包簽署
        """
        try:
            tx_data = {
                "kind": "moveCall",
                "data": {
                    "packageObjectId": self.package_id,
                    "module": "payment_escrow",
                    "function": "lock_payment",
                    "arguments": [
                        # passenger_coin - 由前端提供
                        str(trip_id),
                        driver_wallet,
                        str(platform_fee)
                    ],
                    "typeArguments": ["0x2::iota::IOTA"],
                    "gasBudget": "10000000"
                }
            }
            
            return {
                "status": "payment_lock_prepared",
                "transaction_data": tx_data,
                "amount": amount,
                "platform_fee": platform_fee,
                "instructions": [
                    "請使用 IOTA 錢包簽署此交易",
                    f"支付金額: {amount / 1000000:.6f} IOTA",
                    f"平台費用: {platform_fee / 1000000:.6f} IOTA",
                    "資金將被安全鎖定在智能合約中"
                ]
            }
            
        except Exception as e:
            logger.error(f"準備支付鎖定失敗: {e}")
            return {
                "status": "error",
                "error": str(e)
            }
    
    async def release_payment(
        self,
        escrow_object_id: str,
        driver_wallet: str,
        trip_id: int
    ) -> Dict[str, Any]:
        """
        釋放支付 - 執行實際的鏈上交易
        
        Args:
            escrow_object_id: 託管對象ID (從行程記錄獲取)
            driver_wallet: 司機錢包地址
            trip_id: 行程ID
            
        Returns:
            交易結果
        """
        try:
            # 這裡應該實際執行鏈上交易
            # 由於需要私鑰簽名，實際部署時需要配置平台錢包
            
            if settings.MOCK_MODE:
                # Mock 模式: 模擬交易
                tx_hash = self._generate_mock_tx_hash(escrow_object_id, trip_id)
                
                return {
                    "success": True,
                    "transaction_hash": tx_hash,
                    "status": "payment_released",
                    "escrow_id": escrow_object_id,
                    "recipient": driver_wallet,
                    "timestamp": datetime.utcnow().isoformat()
                }
# 實際模式: 調用 IOTA RPC
            else:
                import httpx
                
                tx_data = {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "iota_moveCall",
                    "params": {
                        "signer": settings.PLATFORM_WALLET,
                        "packageObjectId": self.package_id,
                        "module": "payment_escrow",
                        "function": "release_payment",
                        "typeArguments": [],
                        "arguments": [
                            escrow_object_id,
                            driver_wallet
                        ],
                        "gasBudget": "10000000"
                    }
                }
                
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        self.node_url,
                        json=tx_data,
                        headers={"Content-Type": "application/json"},
                        timeout=30.0
                    )
                    response.raise_for_status()
                    result = response.json()
                
                if "error" in result:
                    raise Exception(f"RPC Error: {result['error']}")
                
                return {
                    "success": True,
                    "transaction_hash": result["result"]["digest"],
                    "status": "payment_released",
                    "escrow_id": escrow_object_id,
                    "recipient": driver_wallet
                }
            
        except Exception as e:
            logger.error(f"釋放支付失敗: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def refund_payment(
        self,
        escrow_object_id: str,
        requester_wallet: str
    ) -> Dict[str, Any]:
        """
        退款 - 取消行程時調用
        
        Args:
            escrow_object_id: 託管對象ID
            requester_wallet: 請求退款的錢包地址 (乘客或管理員)
        """
        try:
            if settings.MOCK_MODE:
                tx_hash = self._generate_mock_tx_hash(escrow_object_id, "refund")
                
                return {
                    "success": True,
                    "transaction_hash": tx_hash,
                    "status": "payment_refunded",
                    "escrow_id": escrow_object_id,
                    "recipient": requester_wallet
                }
            
            else:
                import httpx
                
                tx_data = {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "iota_moveCall",
                    "params": {
                        "signer": requester_wallet,
                        "packageObjectId": self.package_id,
                        "module": "payment_escrow",
                        "function": "refund_payment",
                        "typeArguments": [],
                        "arguments": [escrow_object_id],
                        "gasBudget": "10000000"
                    }
                }
                
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        self.node_url,
                        json=tx_data,
                        headers={"Content-Type": "application/json"},
                        timeout=30.0
                    )
                    response.raise_for_status()
                    result = response.json()
                
                if "error" in result:
                    raise Exception(f"RPC Error: {result['error']}")
                
                return {
                    "success": True,
                    "transaction_hash": result["result"]["digest"],
                    "status": "payment_refunded"
                }
            
        except Exception as e:
            logger.error(f"退款失敗: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    async def create_trip_receipt(
        self,
        trip_id: int,
        passenger_address: str,
        driver_address: str,
        pickup_lat: float,
        pickup_lng: float,
        dropoff_lat: float,
        dropoff_lng: float,
        distance_km: int,
        final_amount: int
    ) -> Dict[str, Any]:
        """
        創建鏈上收據 (可選功能)
        
        Returns:
            收據創建結果
        """
        try:
            # 計算位置哈希
            pickup_hash = self._hash_location(pickup_lat, pickup_lng)
            dropoff_hash = self._hash_location(dropoff_lat, dropoff_lng)
            
            if settings.MOCK_MODE:
                receipt_id = f"receipt_{trip_id}_{int(datetime.utcnow().timestamp())}"
                
                return {
                    "success": True,
                    "receipt_id": receipt_id,
                    "trip_id": trip_id,
                    "status": "receipt_created"
                }
            
            else:
                import httpx
                
                tx_data = {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "iota_moveCall",
                    "params": {
                        "signer": passenger_address,
                        "packageObjectId": self.package_id,
                        "module": "trip_receipt",
                        "function": "create_receipt",
                        "typeArguments": [],
                        "arguments": [
                            str(trip_id),
                            driver_address,
                            list(pickup_hash),
                            list(dropoff_hash),
                            str(distance_km),
                            str(final_amount)
                        ],
                        "gasBudget": "10000000"
                    }
                }
                
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        self.node_url,
                        json=tx_data,
                        headers={"Content-Type": "application/json"},
                        timeout=30.0
                    )
                    response.raise_for_status()
                    result = response.json()
                
                if "error" in result:
                    raise Exception(f"RPC Error: {result['error']}")
                
                return {
                    "success": True,
                    "receipt_id": result["result"]["objectId"],
                    "transaction_hash": result["result"]["digest"]
                }
            
        except Exception as e:
            logger.error(f"創建收據失敗: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    # === 私有輔助方法 ===
    
    def _generate_mock_tx_hash(self, data1: str, data2: Any) -> str:
        """生成模擬交易哈希"""
        combined = f"{data1}{data2}{datetime.utcnow().isoformat()}"
        return "0x" + hashlib.sha256(combined.encode()).hexdigest()
    
    def _hash_location(self, lat: float, lng: float) -> bytes:
        """計算位置哈希"""
        location_str = f"{lat:.6f},{lng:.6f}"
        return hashlib.sha256(location_str.encode()).digest()   