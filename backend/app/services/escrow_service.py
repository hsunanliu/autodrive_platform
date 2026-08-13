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
        self.node_url = settings.SUI_NODE_URL  # 改為 SUI_NODE_URL
    
    async def lock_payment(
        self,
        passenger_wallet: str,
        driver_wallet: str,
        trip_id: int,
        amount: int,
        platform_fee: int
    ) -> Dict[str, Any]:
        """
        鎖定支付 - 準備合約調用交易數據
        
        Returns:
            交易數據，需要前端錢包簽署
        """
        try:
            # 準備調用智能合約的交易數據
            tx_data = {
                "package_id": self.package_id,
                "module": "payment_escrow",
                "function": "lock_payment",
                "arguments": {
                    "payment": "COIN_OBJECT_ID",  # 前端需要替換為實際的 coin object
                    "trip_id": str(trip_id),
                    "driver": driver_wallet,
                    "platform": settings.PLATFORM_WALLET,
                    "platform_fee": str(platform_fee)
                },
                "type_arguments": [],
                "gas_budget": "10000000"
            }
            
            logger.info(f"🔒 準備鎖定支付: trip={trip_id}, amount={amount} MIST")
            
            return {
                "status": "payment_lock_prepared",
                "transaction_data": tx_data,
                "amount": amount,
                "platform_fee": platform_fee,
                "driver_address": driver_wallet,
                "platform_address": settings.PLATFORM_WALLET,
                "instructions": [
                    "請使用 Sui 錢包簽署此交易",
                    f"支付金額: {amount / 1_000_000_000:.6f} SUI",
                    f"平台費用: {platform_fee / 1_000_000_000:.6f} SUI",
                    f"司機收益: {(amount - platform_fee) / 1_000_000_000:.6f} SUI",
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
        trip_id: int,
        amount_mist: int = None
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
            
            # escrow_object_id 就是原始的支付交易 hash
            # 驗證交易並執行實際轉帳給司機
            
            logger.info(f"📤 釋放支付: escrow_id={escrow_object_id}, driver={driver_wallet}, trip={trip_id}")
            
            # 導入 sui_service 來驗證和執行轉帳
            from app.services.sui_service import sui_service
            
            # 驗證原始支付交易仍然有效
            tx_status = await sui_service.get_transaction_status(escrow_object_id)
            
            if tx_status.status != "confirmed":
                logger.error(f"❌ 支付交易無效: {escrow_object_id}")
                return {
                    "success": False,
                    "error": f"支付交易狀態異常: {tx_status.status}"
                }
            
            logger.info(f"✅ 支付交易驗證通過，準備轉帳給司機")
            
            # TODO: 實際執行鏈上轉帳給司機
            # 這需要平台錢包的私鑰來簽署交易
            # 目前先記錄，實際轉帳需要配置私鑰
            
            # 調用智能合約釋放支付
            logger.info(f"📤 調用智能合約釋放支付...")
            logger.info(f"   Escrow Object: {escrow_object_id}")
            logger.info(f"   Trip ID: {trip_id}")
            logger.info(f"   Driver: {driver_wallet}")
            
            # 調用合約的 release_payment 函數
            release_result = await sui_service.call_contract_release_payment(
                package_id=self.package_id,
                escrow_object_id=escrow_object_id,
                trip_id=trip_id
            )
            
            if release_result.get("success"):
                release_tx_hash = release_result.get("transaction_hash")
                logger.info(f"✅ 合約執行成功，支付已釋放: {release_tx_hash}")
            else:
                error_msg = release_result.get("error", "未知錯誤")
                logger.error(f"❌ 合約執行失敗: {error_msg}")
                # 如果合約調用失敗，返回錯誤
                return {
                    "success": False,
                    "error": f"智能合約執行失敗: {error_msg}"
                }
                
            release_tx_hash = release_result.get("transaction_hash")
            
            return {
                "success": True,
                "transaction_hash": release_tx_hash,
                "original_payment_tx": escrow_object_id,
                "status": "payment_released",
                "escrow_id": escrow_object_id,
                "recipient": driver_wallet,
                "timestamp": datetime.utcnow().isoformat(),
                "note": "實際轉帳需要配置操作錢包私鑰" if not getattr(settings, 'OPERATOR_PRIVATE_KEY', None) else None
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
            logger.info(f"💸 退款: escrow_id={escrow_object_id}, requester={requester_wallet}")

            # 不再回傳假 hash 冒充成功。鏈上退款須由 payment_escrow::refund_payment
            # （乘客/司機簽章）或 refund_payment_by_agent（OperatorCap）執行——此串接屬 P1
            # agent-backend（D2）。在串接完成前，明確回報「尚未上鏈」，避免帳實不符。
            logger.warning("退款尚未串接真實鏈上交易（等待 P1 D2 OperatorCap 流程）")
            return {
                "success": False,
                "status": "refund_requires_onchain_execution",
                "escrow_id": escrow_object_id,
                "recipient": requester_wallet,
                "error": "鏈上退款尚未串接（payment_escrow::refund_payment / refund_payment_by_agent），請勿以此為已退款",
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
        final_amount: int,
        trajectory_blob_id: str = "",
        trajectory_hash: bytes = b"",
    ) -> Dict[str, Any]:
        """
        創建鏈上收據 (可選功能)

        Args:
            trajectory_blob_id: 該趟 GPS 軌跡在 Walrus 的 blob_id（可空）
            trajectory_hash: 軌跡內容 SHA256（32 bytes，可空），與 blob_id 一起上鏈錨定

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
                            str(final_amount),
                            list(trajectory_blob_id.encode("utf-8")),
                            list(trajectory_hash),
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