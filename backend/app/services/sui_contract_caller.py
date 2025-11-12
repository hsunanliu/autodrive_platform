# backend/app/services/sui_contract_caller.py
"""
Sui 智能合約調用服務
使用 pysui SDK 調用部署在測試網的智能合約
"""

import logging
from typing import Dict, Any, Optional
from pysui import SuiConfig, SyncClient
from pysui.sui.sui_txn import SyncTransaction
from pysui.sui.sui_types.scalars import ObjectID, SuiAddress
from pysui.sui.sui_types.bcs import Argument

from app.config import settings

logger = logging.getLogger(__name__)

class SuiContractCaller:
    """Sui 智能合約調用服務"""

    def __init__(self):
        # 配置 Sui 客戶端
        self.config = SuiConfig.testnet()
        self.client = SyncClient(self.config)

        # 合約信息
        self.package_id = settings.CONTRACT_PACKAGE_ID
        self.platform_wallet = settings.PLATFORM_WALLET

        # Operator 錢包（用於支付 gas 和執行交易）
        self.operator_private_key = settings.OPERATOR_PRIVATE_KEY

        logger.info(f"✅ SuiContractCaller 初始化完成")
        logger.info(f"   Package ID: {self.package_id[:20]}...")
        logger.info(f"   Platform Wallet: {self.platform_wallet[:20]}...")
        logger.info(f"   Network: testnet")

    async def call_lock_payment(
        self,
        passenger_wallet: str,
        driver_wallet: str,
        trip_id: int,
        amount_mist: int,
        platform_fee_mist: int
    ) -> Dict[str, Any]:
        """
        調用智能合約的 lock_payment 函數

        參數:
        - passenger_wallet: 乘客錢包地址
        - driver_wallet: 司機錢包地址
        - trip_id: 行程 ID
        - amount_mist: 總支付金額（MIST 格式）
        - platform_fee_mist: 平台費用（MIST 格式）

        返回:
        - success: 是否成功
        - tx_hash: 交易哈希
        - escrow_id: 託管對象 ID
        """
        try:
            logger.info(f"🔒 調用智能合約 lock_payment:")
            logger.info(f"   Trip ID: {trip_id}")
            logger.info(f"   Amount: {amount_mist} MIST ({amount_mist / 1_000_000_000} SUI)")
            logger.info(f"   Platform Fee: {platform_fee_mist} MIST")
            logger.info(f"   Driver: {driver_wallet[:20]}...")
            logger.info(f"   Passenger: {passenger_wallet[:20]}...")

            # 創建交易
            txn = SyncTransaction(
                client=self.client,
                initial_sender=SuiAddress(self.platform_wallet)
            )

            # 1. 分割支付幣種
            # 從 operator 錢包中分割出支付金額
            payment_coin = txn.split_coin(
                coin=txn.gas,
                amounts=[Argument("Input", amount_mist)]
            )

            # 2. 調用 lock_payment 函數
            txn.move_call(
                target=f"{self.package_id}::payment_escrow::lock_payment",
                arguments=[
                    payment_coin,                          # Coin<SUI>
                    Argument("Input", trip_id),            # u64: trip_id
                    Argument("Input", driver_wallet),      # address: driver
                    Argument("Input", self.platform_wallet), # address: platform
                    Argument("Input", platform_fee_mist),  # u64: platform_fee
                ],
                type_arguments=[]
            )

            # 3. 執行交易
            result = txn.execute(
                gas_budget="10000000"  # 0.01 SUI
            )

            if result.is_ok():
                tx_digest = result.result_data.digest

                logger.info(f"✅ 智能合約調用成功!")
                logger.info(f"   TX Digest: {tx_digest}")

                # 獲取創建的 Escrow 對象
                # 從交易結果中提取 escrow object ID
                escrow_id = None
                if hasattr(result.result_data, 'created_objects'):
                    for obj in result.result_data.created_objects:
                        # Escrow 對象會是第一個創建的共享對象
                        if hasattr(obj, 'object_id'):
                            escrow_id = str(obj.object_id)
                            break

                if not escrow_id:
                    # 如果無法從結果中獲取，使用 tx_digest 作為標識
                    escrow_id = tx_digest

                return {
                    "success": True,
                    "tx_hash": tx_digest,
                    "escrow_id": escrow_id,
                    "message": "智能合約調用成功，支付已鎖定"
                }
            else:
                error_msg = str(result.result_error) if hasattr(result, 'result_error') else "未知錯誤"
                logger.error(f"❌ 智能合約調用失敗: {error_msg}")

                return {
                    "success": False,
                    "error": f"交易執行失敗: {error_msg}"
                }

        except Exception as e:
            logger.error(f"❌ 調用 lock_payment 異常: {str(e)}")
            logger.exception(e)
            return {
                "success": False,
                "error": f"調用智能合約異常: {str(e)}"
            }

    async def call_release_payment(
        self,
        escrow_object_id: str,
        trip_id: int
    ) -> Dict[str, Any]:
        """
        調用智能合約的 release_payment 函數

        參數:
        - escrow_object_id: 託管對象 ID
        - trip_id: 行程 ID

        返回:
        - success: 是否成功
        - tx_hash: 交易哈希
        """
        try:
            logger.info(f"📤 調用智能合約 release_payment:")
            logger.info(f"   Escrow ID: {escrow_object_id[:20]}...")
            logger.info(f"   Trip ID: {trip_id}")

            # 創建交易
            txn = SyncTransaction(
                client=self.client,
                initial_sender=SuiAddress(self.platform_wallet)
            )

            # 調用 release_payment 函數
            txn.move_call(
                target=f"{self.package_id}::payment_escrow::release_payment",
                arguments=[
                    Argument("Input", escrow_object_id),  # &mut Escrow
                    Argument("Input", trip_id),           # u64: trip_id
                ],
                type_arguments=[]
            )

            # 執行交易
            result = txn.execute(gas_budget="10000000")

            if result.is_ok():
                tx_digest = result.result_data.digest

                logger.info(f"✅ 釋放支付成功!")
                logger.info(f"   TX Digest: {tx_digest}")

                return {
                    "success": True,
                    "tx_hash": tx_digest,
                    "message": "支付已釋放給司機和平台"
                }
            else:
                error_msg = str(result.result_error) if hasattr(result, 'result_error') else "未知錯誤"
                logger.error(f"❌ 釋放支付失敗: {error_msg}")

                return {
                    "success": False,
                    "error": f"釋放支付失敗: {error_msg}"
                }

        except Exception as e:
            logger.error(f"❌ 調用 release_payment 異常: {str(e)}")
            logger.exception(e)
            return {
                "success": False,
                "error": f"調用智能合約異常: {str(e)}"
            }


# 創建全局實例
sui_contract_caller = SuiContractCaller()
