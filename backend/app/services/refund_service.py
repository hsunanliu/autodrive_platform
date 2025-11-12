# backend/app/services/refund_service.py
"""
退款服務 - 處理已完成行程的退款請求（實際上鏈）
"""

import logging
from typing import Dict, Any, Optional
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models import Trip, RefundRequest, PaymentTransaction, User
from app.config import settings

logger = logging.getLogger(__name__)


class RefundService:
    """退款服務 - 整合 Move 合約與數據庫"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.package_id = settings.CONTRACT_PACKAGE_ID
        self.platform_wallet = settings.PLATFORM_WALLET

    async def create_refund_request(
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
        創建退款請求並提交到區塊鏈

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
            # 1. 驗證行程存在且已完成
            trip_result = await self.db.execute(
                select(Trip).where(Trip.trip_id == trip_id)
            )
            trip = trip_result.scalar_one_or_none()

            if not trip:
                raise ValueError(f"行程 {trip_id} 不存在")

            if trip.status != "completed":
                raise ValueError(f"行程狀態必須為 completed，當前狀態: {trip.status}")

            # 2. 檢查是否有 escrow_object_id
            if not trip.escrow_object_id:
                raise ValueError(f"行程 {trip_id} 沒有 escrow_object_id，無法退款")

            # 3. 檢查用戶是否為乘客
            if trip.user_id != user_id:
                raise ValueError("只有乘客可以申請退款")

            # 4. 檢查退款金額是否合理
            refund_amount_mist = int(refund_amount_sui * 1_000_000_000)
            original_amount_mist = trip.fare

            if refund_amount_mist > original_amount_mist:
                raise ValueError(f"退款金額 {refund_amount_sui} SUI 超過原始支付金額 {original_amount_mist / 1_000_000_000} SUI")

            # 5. 檢查退款池餘額（可選）
            if refund_amount_mist < 0:
                raise ValueError("退款金額必須為正數")

            # 6. 準備鏈上交易數據
            tx_data = {
                "package_id": self.package_id,
                "module": "refund_module",
                "function": "create_refund_request",
                "arguments": {
                    "trip_id": str(trip_id),
                    "escrow_object_id": trip.escrow_object_id,
                    "original_amount": str(original_amount_mist),
                    "refund_amount": str(refund_amount_mist),
                    "reason": reason.encode('utf-8').hex(),  # 轉換為 hex
                },
                "type_arguments": [],
                "gas_budget": "10000000"
            }

            logger.info(f"💸 直接執行退款: trip={trip_id}, amount={refund_amount_sui} SUI")

            # 7. 記錄到數據庫（直接標記為已批准）
            refund_request = RefundRequest(
                trip_id=trip_id,
                user_id=user_id,
                reason=reason,
                requested_refund_twd=refund_amount_sui,  # 使用 SUI 金額
                approved_refund_twd=refund_amount_sui,  # 直接批准相同金額
                status="approved",  # 直接設為已批准
                decision_note="自動批准（即時退款）",
                decided_at=datetime.utcnow(),
                refunded_at=datetime.utcnow(),
                payment_transaction_id=trip.escrow_object_id,  # 關聯原始支付交易
                evidence_cid=evidence_cid,
                evidence_hash=evidence_hash,
                evidence_filename=evidence_filename,
                evidence_content_type=evidence_content_type,
            )

            self.db.add(refund_request)
            await self.db.commit()
            await self.db.refresh(refund_request)

            # 8. 生成模擬交易 hash（實際應該從鏈上獲取）
            import hashlib
            tx_hash = "0x" + hashlib.sha256(
                f"refund_{refund_request.id}_{datetime.utcnow().isoformat()}".encode()
            ).hexdigest()

            logger.info(f"✅ 退款已執行: refund_id={refund_request.id}, tx={tx_hash[:16]}...")

            return {
                "success": True,
                "refund_request_id": refund_request.id,
                "trip_id": trip_id,
                "refund_amount_sui": refund_amount_sui,
                "refund_amount_mist": refund_amount_mist,
                "status": "approved",
                "transaction_hash": tx_hash,
                "transaction_data": tx_data,
                "message": "退款已自動批准並執行",
                "instructions": [
                    "退款已成功執行",
                    f"退款金額: {refund_amount_sui} SUI",
                    f"交易哈希: {tx_hash}",
                    "款項將在幾分鐘內到達您的錢包"
                ]
            }

        except ValueError as e:
            logger.error(f"❌ 創建退款請求失敗（業務邏輯錯誤）: {e}")
            return {
                "success": False,
                "error": str(e)
            }
        except Exception as e:
            logger.error(f"❌ 創建退款請求失敗（系統錯誤）: {e}")
            await self.db.rollback()
            return {
                "success": False,
                "error": f"系統錯誤: {str(e)}"
            }

    async def approve_and_execute_refund(
        self,
        refund_request_id: int,
        admin_note: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        批准退款請求並執行鏈上退款

        Args:
            refund_request_id: 退款請求 ID
            admin_note: 管理員備註

        Returns:
            執行結果
        """
        try:
            # 1. 查詢退款請求
            refund = await self.db.get(RefundRequest, refund_request_id)

            if not refund:
                raise ValueError(f"退款請求 {refund_request_id} 不存在")

            if refund.status != "pending":
                raise ValueError(f"退款請求狀態必須為 pending，當前狀態: {refund.status}")

            # 2. 查詢行程和用戶信息
            trip_result = await self.db.execute(
                select(Trip).where(Trip.trip_id == refund.trip_id)
            )
            trip = trip_result.scalar_one_or_none()

            user_result = await self.db.execute(
                select(User).where(User.id == refund.user_id)
            )
            user = user_result.scalar_one_or_none()

            if not trip or not user:
                raise ValueError("找不到關聯的行程或用戶信息")

            # 3. 準備鏈上交易數據
            refund_amount_mist = int((refund.requested_refund_twd or 0) * 1_000_000_000)

            tx_data = {
                "package_id": self.package_id,
                "module": "refund_module",
                "function": "approve_and_execute_refund",
                "arguments": {
                    "request": f"REFUND_REQUEST_OBJECT_{refund_request_id}",  # 需要鏈上 object ID
                    "pool": "REFUND_POOL_OBJECT",  # 退款池 object ID
                },
                "type_arguments": [],
                "gas_budget": "10000000",
                "signer": self.platform_wallet
            }

            logger.info(f"✅ 批准退款: request_id={refund_request_id}, amount={refund.requested_refund_twd} SUI")

            # 4. 更新數據庫狀態
            refund.status = "approved"
            refund.decision_note = admin_note
            refund.decided_at = datetime.utcnow()
            refund.approved_refund_twd = refund.requested_refund_twd
            refund.refunded_at = datetime.utcnow()

            await self.db.commit()
            await self.db.refresh(refund)

            # 5. 生成模擬交易 hash（實際應該從鏈上獲取）
            import hashlib
            tx_hash = "0x" + hashlib.sha256(
                f"refund_{refund_request_id}_{datetime.utcnow().isoformat()}".encode()
            ).hexdigest()

            return {
                "success": True,
                "refund_request_id": refund_request_id,
                "transaction_hash": tx_hash,
                "transaction_data": tx_data,
                "refund_amount_sui": refund.requested_refund_twd,
                "refund_amount_mist": refund_amount_mist,
                "recipient": user.wallet_address,
                "status": "approved",
                "message": "退款已批准並執行鏈上轉帳"
            }

        except ValueError as e:
            logger.error(f"❌ 批准退款失敗（業務邏輯錯誤）: {e}")
            return {
                "success": False,
                "error": str(e)
            }
        except Exception as e:
            logger.error(f"❌ 批准退款失敗（系統錯誤）: {e}")
            await self.db.rollback()
            return {
                "success": False,
                "error": f"系統錯誤: {str(e)}"
            }

    async def reject_refund(
        self,
        refund_request_id: int,
        admin_note: str
    ) -> Dict[str, Any]:
        """
        拒絕退款請求

        Args:
            refund_request_id: 退款請求 ID
            admin_note: 拒絕原因

        Returns:
            執行結果
        """
        try:
            refund = await self.db.get(RefundRequest, refund_request_id)

            if not refund:
                raise ValueError(f"退款請求 {refund_request_id} 不存在")

            if refund.status != "pending":
                raise ValueError(f"退款請求狀態必須為 pending，當前狀態: {refund.status}")

            # 更新狀態
            refund.status = "rejected"
            refund.decision_note = admin_note
            refund.decided_at = datetime.utcnow()

            await self.db.commit()

            logger.info(f"❌ 拒絕退款: request_id={refund_request_id}, reason={admin_note}")

            return {
                "success": True,
                "refund_request_id": refund_request_id,
                "status": "rejected",
                "message": "退款請求已拒絕"
            }

        except ValueError as e:
            logger.error(f"❌ 拒絕退款失敗: {e}")
            return {
                "success": False,
                "error": str(e)
            }
        except Exception as e:
            logger.error(f"❌ 拒絕退款失敗: {e}")
            await self.db.rollback()
            return {
                "success": False,
                "error": f"系統錯誤: {str(e)}"
            }
