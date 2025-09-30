# backend/app/services/iota_service.py
"""
IOTA 區塊鏈服務
處理智能合約調用和區塊鏈交互
"""

import asyncio
import logging
from typing import Dict, Any, Optional
from datetime import datetime
import httpx
import json

from app.config import settings
from app.schemas.payment import PaymentStatus, TransactionStatus, WalletBalance
from app.services.contract_service import contract_service

logger = logging.getLogger(__name__)

class IOTAService:
    """IOTA 區塊鏈服務類"""
    
    def __init__(self):
        self.node_url = settings.IOTA_NODE_URL
        self.network = settings.IOTA_NETWORK
        self.contract_package_id = settings.CONTRACT_PACKAGE_ID
        self.platform_wallet = settings.PLATFORM_WALLET if hasattr(settings, 'PLATFORM_WALLET') else None
        
    async def execute_trip_payment(
        self,
        passenger_wallet: str,
        driver_wallet: str,
        amount_breakdown: Dict[str, int],
        trip_id: int
    ) -> Dict[str, Any]:
        """
        執行行程支付的智能合約調用
        
        Args:
            passenger_wallet: 乘客錢包地址
            driver_wallet: 司機錢包地址
            amount_breakdown: 費用分解
            trip_id: 行程ID
            
        Returns:
            交易結果字典
        """
        try:
            # 使用真正的智能合約服務
            result = await contract_service.process_trip_payment_on_chain(
                passenger_wallet=passenger_wallet,
                driver_wallet=driver_wallet,
                platform_wallet=self.platform_wallet,
                amount_breakdown=amount_breakdown,
                trip_id=trip_id
            )
            
            if result.get("success"):
                return {
                    "success": True,
                    "transaction_hash": result["transaction_hash"],
                    "gas_used": result.get("gas_used"),
                    "status": PaymentStatus.PENDING,
                    "estimated_confirmation_time": 30  # 秒
                }
            else:
                raise Exception(f"Smart contract execution failed: {result.get('error')}")
                
        except Exception as e:
            logger.error(f"Payment execution failed: {str(e)}")
            return {
                "success": False,
                "error": str(e),
                "status": PaymentStatus.FAILED
            }
    
    async def get_wallet_balance(self, wallet_address: str) -> WalletBalance:
        """
        查詢錢包餘額
        
        Args:
            wallet_address: 錢包地址
            
        Returns:
            錢包餘額信息
        """
        try:
            if settings.MOCK_MODE:
                return await self._mock_wallet_balance(wallet_address)
            
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.node_url}/api/wallet/{wallet_address}/balance",
                    timeout=10.0
                )
                response.raise_for_status()
                result = response.json()
            
            balance_micro_iota = result["balance_micro_iota"]
            balance_iota = int(balance_micro_iota) / 1_000_000  # 轉換為 IOTA
            
            return WalletBalance(
                wallet_address=wallet_address,
                balance_micro_iota=balance_micro_iota,
                balance_iota=balance_iota,
                last_updated=datetime.utcnow()
            )
            
        except Exception as e:
            logger.error(f"Failed to get wallet balance: {str(e)}")
            # 返回零餘額作為默認值
            return WalletBalance(
                wallet_address=wallet_address,
                balance_micro_iota="0",
                balance_iota=0.0,
                last_updated=datetime.utcnow()
            )
    
    async def get_transaction_status(self, tx_hash: str) -> TransactionStatus:
        """
        查詢交易狀態
        
        Args:
            tx_hash: 交易哈希
            
        Returns:
            交易狀態信息
        """
        try:
            if settings.MOCK_MODE:
                return await self._mock_transaction_status(tx_hash)
            
            async with httpx.AsyncClient() as client:
                response = await client.get(
                    f"{self.node_url}/api/transaction/{tx_hash}",
                    timeout=10.0
                )
                response.raise_for_status()
                result = response.json()
            
            # 根據確認次數判斷狀態
            confirmation_count = result.get("confirmation_count", 0)
            if confirmation_count >= 3:
                status = PaymentStatus.CONFIRMED
            elif confirmation_count > 0:
                status = PaymentStatus.PENDING
            else:
                status = PaymentStatus.FAILED
            
            return TransactionStatus(
                transaction_hash=tx_hash,
                status=status,
                confirmation_count=confirmation_count,
                block_number=result.get("block_number"),
                block_hash=result.get("block_hash"),
                gas_used=result.get("gas_used"),
                timestamp=datetime.fromisoformat(result["timestamp"]) if result.get("timestamp") else None
            )
            
        except Exception as e:
            logger.error(f"Failed to get transaction status: {str(e)}")
            return TransactionStatus(
                transaction_hash=tx_hash,
                status=PaymentStatus.FAILED,
                confirmation_count=0
            )
    
    async def estimate_gas_fee(self, transaction_type: str = "payment") -> int:
        """
        估算 Gas 費用
        
        Args:
            transaction_type: 交易類型
            
        Returns:
            估算的 Gas 費用 (micro IOTA)
        """
        # 簡單的 Gas 費用估算
        base_fee = 1000  # micro IOTA
        
        if transaction_type == "payment":
            return base_fee * 2  # 支付交易稍微複雜
        else:
            return base_fee
    
    # Mock 方法 (用於測試和開發)
    async def _mock_payment_execution(
        self, 
        passenger_wallet: str, 
        driver_wallet: str, 
        amount_breakdown: Dict[str, int], 
        trip_id: int
    ) -> Dict[str, Any]:
        """模擬支付執行"""
        # 模擬網絡延遲
        await asyncio.sleep(0.5)
        
        # 生成模擬交易哈希
        import hashlib
        data = f"{passenger_wallet}{driver_wallet}{trip_id}{datetime.utcnow().isoformat()}"
        tx_hash = "0x" + hashlib.sha256(data.encode()).hexdigest()
        
        return {
            "success": True,
            "transaction_hash": tx_hash,
            "block_number": 12345678,
            "gas_used": "2000",
            "status": PaymentStatus.PENDING,
            "estimated_confirmation_time": 30
        }
    
    async def _mock_wallet_balance(self, wallet_address: str) -> WalletBalance:
        """模擬錢包餘額查詢"""
        # 模擬不同錢包有不同餘額
        mock_balances = {
            "default": "1000000000",  # 1000 IOTA
            "low": "50000000",        # 50 IOTA
            "high": "10000000000"     # 10000 IOTA
        }
        
        # 根據錢包地址後幾位決定餘額類型
        if wallet_address.endswith(('0', '2', '4', '6', '8')):
            balance_key = "high"
        elif wallet_address.endswith(('1', '3')):
            balance_key = "low"
        else:
            balance_key = "default"
        
        balance_micro_iota = mock_balances[balance_key]
        balance_iota = int(balance_micro_iota) / 1_000_000
        
        return WalletBalance(
            wallet_address=wallet_address,
            balance_micro_iota=balance_micro_iota,
            balance_iota=balance_iota,
            last_updated=datetime.utcnow()
        )
    
    async def _mock_transaction_status(self, tx_hash: str) -> TransactionStatus:
        """模擬交易狀態查詢"""
        # 模擬交易在一段時間後確認
        import time
        
        # 根據交易哈希模擬不同的確認狀態
        hash_int = int(tx_hash[-4:], 16) if tx_hash.startswith('0x') else 0
        
        if hash_int % 10 == 0:
            # 10% 的交易失敗
            status = PaymentStatus.FAILED
            confirmation_count = 0
        elif hash_int % 3 == 0:
            # 已確認
            status = PaymentStatus.CONFIRMED
            confirmation_count = 5
        else:
            # 待確認
            status = PaymentStatus.PENDING
            confirmation_count = 1
        
        return TransactionStatus(
            transaction_hash=tx_hash,
            status=status,
            confirmation_count=confirmation_count,
            block_number=12345678 if status != PaymentStatus.FAILED else None,
            timestamp=datetime.utcnow()
        )

# 創建全局實例
iota_service = IOTAService()