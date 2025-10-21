from datetime import datetime, timedelta
from typing import Dict, List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_async_session
from app.dependencies.admin import get_current_admin
from app.models import PaymentTransaction, Trip, User, Vehicle

router = APIRouter(prefix="/admin/dashboard", tags=["admin-dashboard"])


@router.get("/totals")
async def get_totals(
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    total_users = (await session.execute(select(func.count(User.id)))).scalar() or 0
    total_drivers = (
        await session.execute(
            select(func.count(User.id)).where(User.user_type.in_(["driver", "both"]))
        )
    ).scalar() or 0
    total_vehicles = (await session.execute(select(func.count(Vehicle.vehicle_id)))).scalar() or 0
    total_trips = (await session.execute(select(func.count(Trip.trip_id)))).scalar() or 0
    total_revenue = (await session.execute(select(func.sum(Trip.fare)).where(Trip.status == "completed"))).scalar() or 0

    return {
        "totalUsers": total_users,
        "totalDrivers": total_drivers,
        "totalVehicles": total_vehicles,
        "totalTrips": total_trips,
        "totalRevenue": total_revenue,
    }


def _parse_date(date_str: str) -> datetime:
    try:
        return datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail="日期格式應為 YYYY-MM-DD") from exc


@router.get("/revenue/{period_type}")
async def get_revenue(
    period_type: str,
    startDate: str | None = Query(default=None),
    endDate: str | None = Query(default=None),
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    if period_type not in {"daily", "monthly", "yearly"}:
        raise HTTPException(status_code=400, detail="無效的類型")

    date_column = func.coalesce(PaymentTransaction.completed_at, PaymentTransaction.created_at)
    if period_type == "daily":
        group_expr = func.date_trunc('day', date_column)
        formatter = "%Y-%m-%d"
    elif period_type == "monthly":
        group_expr = func.date_trunc('month', date_column)
        formatter = "%Y-%m"
    else:
        group_expr = func.date_trunc('year', date_column)
        formatter = "%Y"

    stmt = (
        select(
            group_expr.label("bucket"),
            func.sum(
                case(
                    (PaymentTransaction.payment_type == "fiat", PaymentTransaction.amount),
                    else_=0.0,
                )
            ).label("card_revenue"),
            func.sum(
                case(
                    (PaymentTransaction.payment_type != "fiat", PaymentTransaction.amount),
                    else_=0.0,
                )
            ).label("points_revenue"),
            func.sum(PaymentTransaction.amount).label("total_revenue"),
            func.count(PaymentTransaction.transaction_id).label("transaction_count"),
        )
        .where(PaymentTransaction.status == "completed")
        .group_by(group_expr)
        .order_by(group_expr.asc())
    )

    if startDate:
        start_dt = _parse_date(startDate)
        stmt = stmt.where(date_column >= start_dt)
    if endDate:
        end_dt = _parse_date(endDate) + timedelta(days=1)
        stmt = stmt.where(date_column < end_dt)

    results = (await session.execute(stmt)).all()

    def _format_date(value: datetime) -> str:
        return value.strftime(formatter)

    data: List[Dict[str, object]] = []
    for bucket, card_rev, points_rev, total_rev, tx_count in results:
        data.append(
            {
                "date": _format_date(bucket),
                "card_revenue": float(card_rev or 0),
                "points_revenue": float(points_rev or 0),
                "total_revenue": float(total_rev or 0),
                "trip_count": int(tx_count or 0),
            }
        )

    return data


def _calculate_period_bounds(period_type: str, base_date: datetime) -> tuple[tuple[datetime, datetime], tuple[datetime, datetime]]:
    base_start = base_date.replace(hour=0, minute=0, second=0, microsecond=0)
    if period_type == "daily":
        current_start = base_start
        current_end = current_start + timedelta(days=1)
        previous_start = current_start - timedelta(days=1)
        previous_end = current_start
    elif period_type == "weekly":
        weekday = base_start.weekday()
        current_start = base_start - timedelta(days=weekday)
        current_end = current_start + timedelta(days=7)
        previous_start = current_start - timedelta(days=7)
        previous_end = current_start
    elif period_type == "monthly":
        current_start = base_start.replace(day=1)
        if current_start.month == 12:
            current_end = current_start.replace(year=current_start.year + 1, month=1)
        else:
            current_end = current_start.replace(month=current_start.month + 1)
        if current_start.month == 1:
            previous_start = current_start.replace(year=current_start.year - 1, month=12)
        else:
            previous_start = current_start.replace(month=current_start.month - 1)
        previous_start = previous_start.replace(day=1)
        previous_end = current_start
    elif period_type == "yearly":
        current_start = base_start.replace(month=1, day=1)
        current_end = current_start.replace(year=current_start.year + 1)
        previous_start = current_start.replace(year=current_start.year - 1)
        previous_end = current_start
    else:
        raise HTTPException(status_code=400, detail="無效的類型")

    return (current_start, current_end), (previous_start, previous_end)


@router.get("/growth/{period_type}")
async def get_growth(
    period_type: str,
    baseDate: str | None = Query(default=None),
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    if period_type not in {"daily", "weekly", "monthly", "yearly"}:
        raise HTTPException(status_code=400, detail="無效的類型")

    if baseDate:
        base = _parse_date(baseDate)
    else:
        base = datetime.utcnow()

    (current_start, current_end), (previous_start, previous_end) = _calculate_period_bounds(period_type, base)

    trip_stmt = select(func.count(Trip.trip_id)).where(
        Trip.requested_at >= current_start,
        Trip.requested_at < current_end,
    )
    revenue_stmt = select(func.coalesce(func.sum(PaymentTransaction.amount), 0)).where(
        PaymentTransaction.status == "completed",
        func.coalesce(PaymentTransaction.completed_at, PaymentTransaction.created_at) >= current_start,
        func.coalesce(PaymentTransaction.completed_at, PaymentTransaction.created_at) < current_end,
    )

    prev_trip_stmt = select(func.count(Trip.trip_id)).where(
        Trip.requested_at >= previous_start,
        Trip.requested_at < previous_end,
    )
    prev_revenue_stmt = select(func.coalesce(func.sum(PaymentTransaction.amount), 0)).where(
        PaymentTransaction.status == "completed",
        func.coalesce(PaymentTransaction.completed_at, PaymentTransaction.created_at) >= previous_start,
        func.coalesce(PaymentTransaction.completed_at, PaymentTransaction.created_at) < previous_end,
    )

    current_trip_count = (await session.execute(trip_stmt)).scalar() or 0
    current_revenue = float((await session.execute(revenue_stmt)).scalar() or 0)
    previous_trip_count = (await session.execute(prev_trip_stmt)).scalar() or 0
    previous_revenue = float((await session.execute(prev_revenue_stmt)).scalar() or 0)

    def _growth(current_value: float, previous_value: float) -> float:
        if previous_value == 0:
            return 100.0 if current_value > 0 else 0.0
        return round(((current_value - previous_value) / previous_value) * 100, 1)

    labels = {
        "daily": ("選定日", "前一日"),
        "weekly": ("選定週", "前一週"),
        "monthly": ("選定月", "前一月"),
        "yearly": ("選定年", "前一年"),
    }

    return {
        "current": {
            "label": labels[period_type][0],
            "trips": int(current_trip_count),
            "revenue": current_revenue,
        },
        "previous": {
            "label": labels[period_type][1],
            "trips": int(previous_trip_count),
            "revenue": previous_revenue,
        },
        "growth": {
            "trips": _growth(current_trip_count, previous_trip_count),
            "revenue": _growth(current_revenue, previous_revenue),
        },
    }


@router.get("/payment-distribution")
async def get_payment_distribution(
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    stmt = (
        select(
            PaymentTransaction.payment_type,
            func.count(PaymentTransaction.transaction_id).label("count"),
            func.sum(PaymentTransaction.amount).label("amount"),
        )
        .where(PaymentTransaction.status == "completed")
        .group_by(PaymentTransaction.payment_type)
    )
    rows = (await session.execute(stmt)).all()

    distribution: Dict[str, Dict[str, float | int]] = {}
    for payment_type, count, amount in rows:
        mapped = "card" if payment_type == "fiat" else "points"
        record = distribution.setdefault(mapped, {"count": 0, "amount": 0.0})
        record["count"] += int(count or 0)
        record["amount"] += float(amount or 0)

    total_amount = sum(item["amount"] for item in distribution.values())

    data = []
    for key, value in distribution.items():
        percentage = 0.0
        if total_amount > 0:
            percentage = round((value["amount"] / total_amount) * 100, 1)
        data.append(
            {
                "type": key,
                "count": value["count"],
                "amount": value["amount"],
                "percentage": percentage,
            }
        )

    return {
        "data": data,
        "totalAmount": total_amount,
    }
