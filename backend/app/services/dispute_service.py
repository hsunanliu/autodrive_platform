"""
爭議服務 — 鏈上仲裁（Phase 4）

流程：
  1. 乘客或司機 raise_dispute → 凍結該筆 escrow（鏈上），trip.status = disputed。
     raise 需當事人錢包簽章（非託管）；後端設定 DB 狀態並回傳給行動端要簽的 move-call 參數。
     行動端簽完後把 Dispute 物件 ID 回報，存入 trip.dispute_object_id。
  2. 管理員 resolve_dispute → 平台持 ArbiterCap 上鏈裁決（判司機 release／退乘客 refund）。
     此步由後端以 operator 金鑰執行（call_contract_resolve_dispute）。
"""

import logging
from typing import Any, Dict, Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import Trip

logger = logging.getLogger(__name__)

RULING_DRIVER = 1     # 判給司機
RULING_PASSENGER = 2  # 退乘客


class DisputeService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def _get_trip(self, trip_id: int) -> Optional[Trip]:
        return (await self.db.execute(
            select(Trip).where(Trip.trip_id == trip_id)
        )).scalar_one_or_none()

    async def raise_dispute(
        self,
        trip_id: int,
        user_id: int,
        reason: str,
        dispute_object_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """乘客或司機發起爭議，凍結 escrow（DB 標記 + 回傳鏈上簽章參數）。"""
        trip = await self._get_trip(trip_id)
        if not trip:
            return {"success": False, "error": "行程不存在"}
        if user_id not in (trip.user_id, trip.driver_id):
            return {"success": False, "error": "只有該行程的乘客或司機可發起爭議"}
        if not trip.escrow_object_id:
            return {"success": False, "error": "此行程無鏈上託管可爭議"}
        if trip.status in ("cancelled", "disputed"):
            return {"success": False, "error": f"目前狀態不可發起爭議（{trip.status}）"}

        trip.status = "disputed"
        if dispute_object_id:
            trip.dispute_object_id = dispute_object_id
        await self.db.commit()

        # raise_dispute 需當事人錢包簽章；回傳要簽的 move-call 參數給行動端。
        on_chain_call = None
        if not dispute_object_id:
            on_chain_call = {
                "package": settings.CONTRACT_PACKAGE_ID,
                "module": "payment_escrow",
                "function": "raise_dispute",
                "arguments": {
                    "escrow": trip.escrow_object_id,
                    "reason": reason,
                },
                "note": "請用您的錢包簽署此交易以凍結款項，簽完回報 Dispute 物件 ID",
            }

        return {
            "success": True,
            "trip_id": trip_id,
            "status": "disputed",
            "dispute_object_id": trip.dispute_object_id,
            "on_chain_call": on_chain_call,
        }

    async def report_dispute_object(self, trip_id: int, user_id: int, dispute_object_id: str) -> Dict[str, Any]:
        """行動端簽完 raise_dispute 後，回報鏈上 Dispute 物件 ID。"""
        trip = await self._get_trip(trip_id)
        if not trip:
            return {"success": False, "error": "行程不存在"}
        if user_id not in (trip.user_id, trip.driver_id):
            return {"success": False, "error": "無權操作此行程"}
        trip.dispute_object_id = dispute_object_id
        await self.db.commit()
        return {"success": True, "trip_id": trip_id, "dispute_object_id": dispute_object_id}

    async def resolve_dispute(
        self,
        trip_id: int,
        ruling: int,
        admin_note: Optional[str] = None,
    ) -> Dict[str, Any]:
        """管理員裁決爭議並上鏈執行（平台 ArbiterCap + operator 金鑰）。"""
        if ruling not in (RULING_DRIVER, RULING_PASSENGER):
            return {"success": False, "error": "ruling 必須為 1（判司機）或 2（退乘客）"}

        trip = await self._get_trip(trip_id)
        if not trip:
            return {"success": False, "error": "行程不存在"}
        if trip.status != "disputed":
            return {"success": False, "error": f"行程非爭議狀態（{trip.status}）"}
        if not trip.escrow_object_id or not trip.dispute_object_id:
            return {"success": False, "error": "缺 escrow/dispute 物件 ID，無法裁決"}

        from app.services.sui_service import sui_service
        chain = await sui_service.call_contract_resolve_dispute(
            package_id=settings.CONTRACT_PACKAGE_ID,
            arbiter_cap_id=settings.ARBITER_CAP_ID,
            escrow_object_id=trip.escrow_object_id,
            dispute_object_id=trip.dispute_object_id,
            ruling=ruling,
        )
        if not chain.get("success"):
            return {"success": False, "error": f"鏈上裁決失敗: {chain.get('error')}"}

        if ruling == RULING_DRIVER:
            trip.status = "completed"
            trip.payment_status = "released"
        else:
            trip.status = "cancelled"
            trip.payment_status = "refunded"
        await self.db.commit()

        return {
            "success": True,
            "trip_id": trip_id,
            "ruling": ruling,
            "status": trip.status,
            "transaction_hash": chain.get("transaction_hash", ""),
        }
