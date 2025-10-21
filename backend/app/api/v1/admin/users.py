from fastapi import APIRouter, Depends, HTTPException, Path, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.core.database import get_async_session
from app.dependencies.admin import get_current_admin
from app.models import Trip, User, Vehicle

router = APIRouter(prefix="/admin/users", tags=["admin-users"])


def _user_display_name(user: User | None) -> str | None:
    if not user:
        return None
    return user.display_name or user.username


@router.get("")
async def list_users(
    type: str | None = Query(default=None),
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    data = []

    include_riders = type in (None, "", "rider")
    include_drivers = type in (None, "", "driver")

    if include_riders:
        rider_stmt = (
            select(User, func.count(Trip.trip_id).label("trip_count"))
            .outerjoin(Trip, Trip.user_id == User.id)
            .where(User.user_type.in_(["passenger", "both"]))
            .group_by(User.id)
            .order_by(User.id.desc())
        )
        for user, trip_count in (await session.execute(rider_stmt)).all():
            data.append(
                {
                    "id": user.id,
                    "name": _user_display_name(user),
                    "phone": user.phone_number,
                    "email": user.email,
                    "created_at": user.created_at.isoformat() if user.created_at else None,
                    "user_type": "rider",
                    "trip_count": int(trip_count or 0),
                }
            )

    if include_drivers:
        driver_stmt = (
            select(User, func.count(Vehicle.vehicle_id).label("vehicle_count"))
            .outerjoin(Vehicle, Vehicle.owner_id == User.id)
            .where(User.user_type.in_(["driver", "both"]))
            .group_by(User.id)
            .order_by(User.id.desc())
        )
        for user, vehicle_count in (await session.execute(driver_stmt)).all():
            data.append(
                {
                    "id": user.id,
                    "name": _user_display_name(user),
                    "phone": user.phone_number,
                    "email": user.email,
                    "created_at": user.created_at.isoformat() if user.created_at else None,
                    "user_type": "driver",
                    "vehicle_count": int(vehicle_count or 0),
                }
            )

    return data


@router.get("/{user_type}/{user_id}")
async def get_user_detail(
    user_type: str = Path(..., regex="^(rider|driver)$"),
    user_id: int = Path(...),
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    user = await session.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="用戶不存在")

    return {
        "id": user.id,
        "name": _user_display_name(user),
        "phone": user.phone_number,
        "email": user.email,
        "created_at": user.created_at.isoformat() if user.created_at else None,
        "user_type": user_type,
    }


@router.get("/driver/{user_id}/vehicles")
async def get_driver_vehicles(
    user_id: int,
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    stmt = (
        select(Vehicle)
        .where(Vehicle.owner_id == user_id)
        .options(joinedload(Vehicle.owner))
        .order_by(Vehicle.vehicle_id.desc())
    )
    vehicles = (await session.execute(stmt)).scalars().all()

    return [
        {
            "vehicle_id": vehicle.vehicle_id,
            "plate_number": vehicle.plate_number,
            "model": vehicle.model,
            "status": vehicle.status,
            "battery_capacity_kWh": vehicle.battery_capacity_kwh,
            "current_charge_percent": vehicle.current_charge_percent,
            "updated_at": vehicle.updated_at.isoformat() if vehicle.updated_at else None,
        }
        for vehicle in vehicles
    ]


@router.get("/rider/{user_id}/trips")
async def get_rider_trips(
    user_id: int,
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    stmt = (
        select(Trip)
        .where(Trip.user_id == user_id)
        .order_by(Trip.requested_at.desc())
    )
    trips = (await session.execute(stmt)).scalars().all()

    return [
        {
            "trip_id": trip.trip_id,
            "status": trip.status,
            "fare": trip.fare,
            "total_amount": trip.total_amount,
            "requested_at": trip.requested_at.isoformat() if trip.requested_at else None,
            "pickup_address": trip.pickup_address,
            "dropoff_address": trip.dropoff_address,
        }
        for trip in trips
    ]
