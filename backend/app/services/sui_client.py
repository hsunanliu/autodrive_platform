# backend/app/services/sui_client.py
"""
Sui 區塊鏈客戶端服務
"""

import logging
from typing import Optional, Dict, Any
from pysui import SuiConfig, SyncClient
from pysui.sui.sui_txn import SyncTransaction
from pysui.sui.sui_types import SuiString, ObjectID

from app.config import settings

logger = logging.getLogger(__name__)


class SuiBlockchainClient:
    """Sui 區塊鏈客戶端"""

    def __init__(self):
        self.config = None
        self.client = None
        self._initialize_client()

    def _initialize_client(self):
        """初始化 Sui 客戶端。

        pysui 0.65 沒有 SuiConfig.testnet()/devnet()/mainnet()；改用 user_config
        （指定 rpc_url + 平台 operator 金鑰），與 sui_service 一致。
        """
        try:
            operator_key = getattr(settings, "OPERATOR_PRIVATE_KEY", "") or ""
            prv_keys = [operator_key] if operator_key else []
            self.config = SuiConfig.user_config(
                rpc_url=settings.SUI_NODE_URL,
                prv_keys=prv_keys,
            )
            self.client = SyncClient(self.config)
            logger.info(f"✅ Sui 客戶端初始化成功: {settings.SUI_NETWORK} ({settings.SUI_NODE_URL})")
        except Exception as e:
            logger.error(f"❌ Sui 客戶端初始化失敗: {e}")
            self.client = None

    def is_available(self) -> bool:
        """檢查客戶端是否可用"""
        return self.client is not None

    def create_refund_request_transaction(
        self,
        trip_id: int,
        escrow_object_id: str,
        original_amount: int,
        refund_amount: int,
        reason: str,
        sender_address: str,
    ) -> Optional[Dict[str, Any]]:
        """
        創建退款請求交易

        Args:
            trip_id: 行程 ID
            escrow_object_id: Escrow Object ID
            original_amount: 原始金額 (MIST)
            refund_amount: 退款金額 (MIST)
            reason: 退款原因
            sender_address: 發送者地址

        Returns:
            交易數據字典，包含需要簽署的交易
        """
        if not self.is_available():
            logger.error("❌ Sui 客戶端不可用")
            return None

        try:
            # 創建交易
            txn = SyncTransaction(client=self.client, initial_sender=sender_address)

            # 準備函數參數
            # 將原因轉換為十六進制
            reason_hex = reason.encode('utf-8').hex()

            # 調用合約函數
            txn.move_call(
                target=f"{settings.CONTRACT_PACKAGE_ID}::refund_module::create_refund_request",
                arguments=[
                    str(trip_id),                    # trip_id: u64
                    escrow_object_id,                # escrow_object_id: address
                    str(original_amount),            # original_amount: u64
                    str(refund_amount),              # refund_amount: u64
                    f"0x{reason_hex}",              # reason: vector<u8>
                ],
                type_arguments=[],
            )

            # 構建交易
            tx_bytes = txn.build()

            logger.info(f"📝 創建退款請求交易: trip_id={trip_id}, amount={refund_amount} MIST")

            return {
                "tx_bytes": tx_bytes,
                "transaction": txn,
                "sender": sender_address,
            }

        except Exception as e:
            logger.error(f"❌ 創建退款請求交易失敗: {e}")
            return None

    def approve_and_execute_refund_transaction(
        self,
        refund_request_object_id: str,
        refund_pool_object_id: str,
        platform_address: str,
    ) -> Optional[Dict[str, Any]]:
        """
        批准並執行退款交易

        Args:
            refund_request_object_id: 退款請求 Object ID
            refund_pool_object_id: 退款池 Object ID
            platform_address: 平台地址

        Returns:
            交易數據字典
        """
        if not self.is_available():
            logger.error("❌ Sui 客戶端不可用")
            return None

        try:
            # 創建交易
            txn = SyncTransaction(client=self.client, initial_sender=platform_address)

            # 調用合約函數
            txn.move_call(
                target=f"{settings.CONTRACT_PACKAGE_ID}::refund_module::approve_and_execute_refund",
                arguments=[
                    refund_request_object_id,  # request: &mut RefundRequest
                    refund_pool_object_id,     # pool: &mut RefundPool
                ],
                type_arguments=[],
            )

            # 構建交易
            tx_bytes = txn.build()

            logger.info(f"✅ 創建批准退款交易: request={refund_request_object_id[:16]}...")

            return {
                "tx_bytes": tx_bytes,
                "transaction": txn,
                "sender": platform_address,
            }

        except Exception as e:
            logger.error(f"❌ 創建批准退款交易失敗: {e}")
            return None

    def execute_transaction(self, tx_bytes: bytes, signature: str) -> Optional[Dict[str, Any]]:
        """
        執行已簽署的交易

        Args:
            tx_bytes: 交易字節
            signature: 簽名

        Returns:
            交易結果
        """
        if not self.is_available():
            logger.error("❌ Sui 客戶端不可用")
            return None

        try:
            # 執行交易
            result = self.client.execute_tx(tx_bytes=tx_bytes, signatures=[signature])

            logger.info(f"✅ 交易已執行: {result.digest}")

            return {
                "success": True,
                "digest": result.digest,
                "effects": result.effects,
            }

        except Exception as e:
            logger.error(f"❌ 執行交易失敗: {e}")
            return {
                "success": False,
                "error": str(e),
            }

    def get_object(self, object_id: str) -> Optional[Dict[str, Any]]:
        """
        獲取鏈上對象信息

        Args:
            object_id: Object ID

        Returns:
            對象信息
        """
        if not self.is_available():
            return None

        try:
            result = self.client.get_object(object_id=object_id)
            return result.to_dict() if result else None
        except Exception as e:
            logger.error(f"❌ 獲取對象失敗: {e}")
            return None

    def approve_and_execute_refund(
        self,
        refund_request_object_id: str,
        refund_pool_id: str,
        platform_address: str,
        private_key: str
    ) -> Optional[Dict[str, Any]]:
        """
        批准並執行退款（包含簽署和提交）

        Args:
            refund_request_object_id: 退款請求 Object ID
            refund_pool_id: 退款池 Object ID
            platform_address: 平台地址
            private_key: 平台私鑰

        Returns:
            執行結果字典
        """
        if not self.is_available():
            logger.error("❌ Sui 客戶端不可用")
            return {
                "success": False,
                "error": "Sui 客戶端不可用"
            }

        try:
            from pysui.sui.sui_crypto import SuiKeyPair

            # 1. 創建交易
            logger.info(f"📝 創建退款交易...")
            tx_data = self.approve_and_execute_refund_transaction(
                refund_request_object_id=refund_request_object_id,
                refund_pool_object_id=refund_pool_id,
                platform_address=platform_address
            )

            if not tx_data:
                return {
                    "success": False,
                    "error": "創建交易失敗"
                }

            # 2. 使用私鑰簽署交易
            logger.info(f"🔐 簽署交易...")
            keypair = SuiKeyPair.from_b64(private_key)

            # 簽署交易
            signature = keypair.new_sign_secure(tx_data["tx_bytes"])

            # 3. 執行交易
            logger.info(f"📤 提交交易到區塊鏈...")
            result = self.execute_transaction(
                tx_bytes=tx_data["tx_bytes"],
                signature=signature.value
            )

            if result and result.get("success"):
                logger.info(f"✅ 退款交易執行成功: {result.get('digest')}")
                return {
                    "success": True,
                    "transaction_hash": result.get("digest"),
                    "effects": result.get("effects")
                }
            else:
                error_msg = result.get("error", "未知錯誤") if result else "無返回結果"
                logger.error(f"❌ 退款交易執行失敗: {error_msg}")
                return {
                    "success": False,
                    "error": error_msg
                }

        except Exception as e:
            logger.error(f"❌ 批准並執行退款失敗: {str(e)}")
            return {
                "success": False,
                "error": str(e)
            }


# 創建全局客戶端實例
sui_client = SuiBlockchainClient()
