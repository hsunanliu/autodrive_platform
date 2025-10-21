from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.database import get_async_session
from app.dependencies.admin import get_current_admin
from app.models import RefundRequest, Trip, User, Vehicle
from app.schemas.admin import RefundUpdateRequest

router = APIRouter(prefix="/admin/refunds", tags=["admin-refunds"])

VALID_REFUND_STATUSES = {"pending", "approved", "rejected", "on_hold", "cancelled"}


@router.get("")
async def list_refunds(
    status: str | None = Query(default=None),
    search_type: str | None = Query(default=None),
    search_value: str | None = Query(default=None),
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    owner_alias = aliased(User)

    stmt = (
        select(RefundRequest, Trip, User, Vehicle, owner_alias)
        .join(Trip, RefundRequest.trip_id == Trip.trip_id)
        .join(User, RefundRequest.user_id == User.id)
        .outerjoin(Vehicle, Trip.vehicle_id == Vehicle.vehicle_id)
        .outerjoin(owner_alias, Vehicle.owner_id == owner_alias.id)
        .order_by(RefundRequest.created_at.desc())
    )

    if status:
        stmt = stmt.where(RefundRequest.status == status)

    if search_type and search_value:
        if search_type == "user_id":
            try:
                numeric_value = int(search_value)
            except ValueError as exc:
                raise HTTPException(status_code=400, detail="用戶 ID 必須為數字") from exc
            stmt = stmt.where(
                or_(
                    RefundRequest.user_id == numeric_value,
                    Vehicle.owner_id == numeric_value,
                )
            )
        elif search_type == "trip_id":
            try:
                numeric_value = int(search_value)
            except ValueError as exc:
                raise HTTPException(status_code=400, detail="行程 ID 必須為數字") from exc
            stmt = stmt.where(RefundRequest.trip_id == numeric_value)
        elif search_type == "user_name":
            like_value = f"%{search_value}%"
            stmt = stmt.where(
                or_(
                    User.display_name.ilike(like_value),
                    User.username.ilike(like_value),
                    owner_alias.display_name.ilike(like_value),
                    owner_alias.username.ilike(like_value),
                )
            )

    results = (await session.execute(stmt)).all()

    data: List[dict] = []
    for refund, trip, rider, vehicle, owner in results:
        data.append(
            {
                "refund_request_id": refund.id,
                "trip_id": refund.trip_id,
                "reason": refund.reason,
                "requested_refund_twd": refund.requested_refund_twd,
                "requested_refund_points": refund.requested_refund_points,
                "approved_refund_twd": refund.approved_refund_twd,
                "approved_refund_points": refund.approved_refund_points,
                "status": refund.status,
                "decision_note": refund.decision_note,
                "liability": refund.liability,
                "liability_note": refund.liability_note,
                "recovery_status": refund.recovery_status,
                "created_at": refund.created_at.isoformat() if refund.created_at else None,
                "decided_at": refund.decided_at.isoformat() if refund.decided_at else None,
                "refunded_at": refund.refunded_at.isoformat() if refund.refunded_at else None,
                "rider_id": trip.user_id if trip else None,
                "vehicle_id": trip.vehicle_id if trip else None,
                "rider_name": rider.display_name or rider.username if rider else None,
                "owner_id": vehicle.owner_id if vehicle else None,
                "driver_name": owner.display_name or owner.username if owner else None,
            }
        )

    return data


@router.put("/{refund_id}")
async def update_refund(
    refund_id: int,
    payload: RefundUpdateRequest,
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    refund = await session.get(RefundRequest, refund_id)
    if not refund:
        raise HTTPException(status_code=404, detail="退款請求不存在")

    if payload.status not in VALID_REFUND_STATUSES:
        raise HTTPException(status_code=400, detail="無效的狀態值")

    if payload.status in {"approved", "on_hold"}:
        if (
            payload.approved_refund_twd is not None
            and refund.requested_refund_twd is not None
            and payload.approved_refund_twd > refund.requested_refund_twd
        ):
            raise HTTPException(status_code=400, detail="核准金額不能超過申請金額")
        if (
            payload.approved_refund_points is not None
            and refund.requested_refund_points is not None
            and payload.approved_refund_points > refund.requested_refund_points
        ):
            raise HTTPException(status_code=400, detail="核准點數不能超過申請點數")

    refund.status = payload.status
    refund.decision_note = payload.decision_note
    
    # 更新責任歸屬
    if hasattr(payload, 'liability') and payload.liability:
        refund.liability = payload.liability
    if hasattr(payload, 'liability_note') and payload.liability_note:
        refund.liability_note = payload.liability_note
    if hasattr(payload, 'recovery_status') and payload.recovery_status:
        refund.recovery_status = payload.recovery_status

    if payload.status in {"approved", "on_hold"}:
        refund.approved_refund_twd = payload.approved_refund_twd
        refund.approved_refund_points = payload.approved_refund_points
    else:
        refund.approved_refund_twd = payload.approved_refund_twd if payload.approved_refund_twd is not None else refund.approved_refund_twd
        refund.approved_refund_points = payload.approved_refund_points if payload.approved_refund_points is not None else refund.approved_refund_points

    refund.decided_at = datetime.utcnow()

    await session.commit()
    await session.refresh(refund)

    return {"message": "退款狀態已更新", "status": refund.status}
