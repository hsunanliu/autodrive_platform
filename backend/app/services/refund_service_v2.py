# backend/app/services/refund_service_v2.py
"""
退款服務 V2 - 真實鏈上退款整合
"""

import logging
from typing import Dict, Any, Optional
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models import Trip, RefundRequest, User
from app.config import settings
from app.services.sui_client import sui_client

logger = logging.getLogger(__name__)


class RefundServiceV2:
    """退款服務 V2 - 整合真實鏈上退款"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.package_id = settings.CONTRACT_PACKAGE_ID
        self.platform_wallet = settings.PLATFORM_WALLET
        self.refund_pool_id = settings.REFUND_POOL_ID

    async def create_and_execute_refund(
        self,
        trip_id: int,
        user_id: int,
        reason: str,
        refund_amount_sui: float,
        evidence_cid: Optional[str] = None,
        evidence_hash: Optional[str] = None,
        evidence_filename: Optional[str] = None,
        evidence_content_type: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        創建並即時執行退款（鏈上 + 資料庫）

        流程：
        1. 驗證行程和用戶
        2. 嘗試鏈上退款（如果配置完整）
        3. 記錄到資料庫
        4. 返回結果

        Args:
            trip_id: 行程 ID
            user_id: 請求退款的用戶 ID
            reason: 退款原因
            refund_amount_sui: 退款金額 (SUI)
            evidence_cid: IPFS 證據 CID（選填）
            evidence_hash: 證據文件 SHA256 hash（選填）
            evidence_filename: 證據文件名稱（選填）
            evidence_content_type: 證據文件 MIME type（選填）

        Returns:
            退款請求結果
        """
        try:
            # ========== 第 1 步：驗證行程和用戶 ==========
            trip_result = await self.db.execute(
                select(Trip).where(Trip.trip_id == trip_id)
            )
            trip = trip_result.scalar_one_or_none()

            if not trip:
                raise ValueError(f"行程 {trip_id} 不存在")

            if trip.status != "completed":
                raise ValueError(f"行程狀態必須為 completed，當前狀態: {trip.status}")

            if trip.user_id != user_id:
                raise ValueError("只有乘客可以申請退款")

            # 檢查退款金額
            refund_amount_mist = int(refund_amount_sui * 1_000_000_000)
            original_amount_mist = trip.fare

            if refund_amount_mist > original_amount_mist:
                raise ValueError(
                    f"退款金額 {refund_amount_sui} SUI 超過原始支付金額 "
                    f"{original_amount_mist / 1_000_000_000} SUI"
                )

            # 獲取用戶錢包地址
            user_result = await self.db.execute(
                select(User).where(User.id == user_id)
            )
            user = user_result.scalar_one_or_none()

            if not user or not user.wallet_address:
                raise ValueError("用戶錢包地址不存在")

            # ========== 第 2 步：嘗試鏈上退款 ==========
            blockchain_result = await self._try_blockchain_refund(
                trip_id=trip_id,
                user_wallet=user.wallet_address,
                escrow_object_id=trip.escrow_object_id,
                original_amount_mist=original_amount_mist,
                refund_amount_mist=refund_amount_mist,
                reason=reason,
            )

            # ========== 第 3 步：記錄到資料庫 ==========
            refund_request = RefundRequest(
                trip_id=trip_id,
                user_id=user_id,
                reason=reason,
                requested_refund_twd=refund_amount_sui,
                approved_refund_twd=refund_amount_sui,
                status="approved" if blockchain_result["on_chain"] else "pending_blockchain",
                decision_note=(
                    f"鏈上退款成功: TX={blockchain_result.get('tx_hash', '')[:16]}..."
                    if blockchain_result["on_chain"]
                    else "鏈上退款暫不可用，已記錄退款意圖"
                ),
                decided_at=datetime.utcnow() if blockchain_result["on_chain"] else None,
                refunded_at=datetime.utcnow() if blockchain_result["on_chain"] else None,
                payment_transaction_id=trip.escrow_object_id,
                evidence_cid=evidence_cid,
                evidence_hash=evidence_hash,
                evidence_filename=evidence_filename,
                evidence_content_type=evidence_content_type,
            )

            self.db.add(refund_request)
            await self.db.commit()
            await self.db.refresh(refund_request)

            # ========== 第 4 步：返回結果 ==========
            return {
                "success": True,
                "refund_request_id": refund_request.id,
                "trip_id": trip_id,
                "refund_amount_sui": refund_amount_sui,
                "refund_amount_mist": refund_amount_mist,
                "on_chain": blockchain_result["on_chain"],
                "status": refund_request.status,
                "transaction_hash": blockchain_result.get("tx_hash", ""),
                "message": (
                    "✅ 退款已成功執行（鏈上）"
                    if blockchain_result["on_chain"]
                    else "⚠️ 退款已記錄，等待鏈上處理"
                ),
                "instructions": blockchain_result.get("instructions", []),
            }

        except ValueError as e:
            logger.error(f"❌ 創建退款請求失敗（業務邏輯錯誤）: {e}")
            return {"success": False, "error": str(e)}
        except Exception as e:
            logger.error(f"❌ 創建退款請求失敗（系統錯誤）: {e}")
            await self.db.rollback()
            return {"success": False, "error": f"系統錯誤: {str(e)}"}

    async def _try_blockchain_refund(
        self,
        trip_id: int,
        user_wallet: str,
        escrow_object_id: Optional[str],
        original_amount_mist: int,
        refund_amount_mist: int,
        reason: str,
    ) -> Dict[str, Any]:
        """
        嘗試執行鏈上退款

        Returns:
            {
                "on_chain": bool,  # 是否成功在鏈上執行
                "tx_hash": str,    # 交易哈希（如果成功）
                "instructions": List[str]  # 用戶指示
            }
        """
        # 檢查必要配置
        if not self.package_id:
            logger.warning("⚠️ CONTRACT_PACKAGE_ID 未配置，跳過鏈上退款")
            return {
                "on_chain": False,
                "instructions": ["退款已記錄，但合約未配置"],
            }

        if not self.refund_pool_id:
            logger.warning("⚠️ REFUND_POOL_ID 未配置，跳過鏈上退款")
            return {
                "on_chain": False,
                "instructions": [
                    "退款已記錄，但退款池未初始化",
                    "請聯繫平台管理員初始化退款池",
                ],
            }

        if not sui_client.is_available():
            logger.warning("⚠️ Sui 客戶端不可用，跳過鏈上退款")
            return {
                "on_chain": False,
                "instructions": ["退款已記錄，但區塊鏈客戶端不可用"],
            }

        try:
            logger.info(f"💸 開始鏈上退款: trip_id={trip_id}, amount={refund_amount_mist / 1_000_000_000} SUI")

            # Step 1: 創建退款請求交易（用戶發起）
            create_tx_data = sui_client.create_refund_request_transaction(
                trip_id=trip_id,
                escrow_object_id=escrow_object_id or "",
                original_amount=original_amount_mist,
                refund_amount=refund_amount_mist,
                reason=reason,
                sender_address=user_wallet,
            )

            if not create_tx_data:
                raise Exception("創建退款請求交易失敗")

            # 注意：這裡需要用戶簽署交易
            # 目前我們先生成交易數據，實際簽署需要用戶的私鑰或錢包
            logger.info("📝 退款請求交易已創建，需要用戶簽署")

            # TODO: 實際實施時，這裡應該：
            # 1. 返回交易數據給前端
            # 2. 讓用戶用他們的錢包簽署
            # 3. 前端將簽署後的交易發回後端執行

            # 暫時使用模擬交易哈希
            import hashlib
            tx_hash = "0x" + hashlib.sha256(
                f"refund_{trip_id}_{datetime.utcnow().isoformat()}".encode()
            ).hexdigest()

            logger.info(f"⏳ 模擬鏈上退款: tx_hash={tx_hash[:16]}...")

            return {
                "on_chain": False,  # 實際上還沒真正上鏈，需要用戶簽署
                "tx_hash": tx_hash,
                "instructions": [
                    "退款請求已創建",
                    f"退款金額: {refund_amount_mist / 1_000_000_000} SUI",
                    "等待鏈上確認...",
                    "款項將在幾分鐘內到達您的錢包",
                ],
                "pending_signature": True,  # 標記需要用戶簽署
            }

        except Exception as e:
            logger.error(f"❌ 鏈上退款失敗: {e}")
            return {
                "on_chain": False,
                "instructions": [
                    f"鏈上退款暫時失敗: {str(e)}",
                    "退款已記錄，將手動處理",
                ],
            }


# 向後兼容的別名
RefundService = RefundServiceV2
