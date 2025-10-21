from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from app.core.database import get_async_session
from app.dependencies.admin import get_current_admin
from app.models import Trip, User, Vehicle
from app.schemas.admin import TripStatusUpdate

router = APIRouter(prefix="/admin/trips", tags=["admin-trips"])

VALID_TRIP_STATUSES = {
    "requested",
    "matched",
    "accepted",
    "picked_up",
    "in_progress",
    "completed",
    "cancelled",
}


@router.get("")
async def list_trips(
    status: str | None = Query(default=None),
    search_type: str | None = Query(default=None),
    search_value: str | None = Query(default=None),
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    rider_alias = aliased(User)
    driver_alias = aliased(User)
    owner_alias = aliased(User)

    stmt = (
        select(Trip, rider_alias, driver_alias, Vehicle, owner_alias)
        .outerjoin(rider_alias, Trip.user_id == rider_alias.id)
        .outerjoin(Vehicle, Trip.vehicle_id == Vehicle.vehicle_id)
        .outerjoin(owner_alias, Vehicle.owner_id == owner_alias.id)
        .outerjoin(driver_alias, Trip.driver_id == driver_alias.id)
        .order_by(Trip.requested_at.desc())
    )

    if status:
        stmt = stmt.where(Trip.status == status)

    if search_type and search_value:
        if search_type == "trip_id":
            try:
                trip_id = int(search_value)
            except ValueError as exc:
                raise HTTPException(status_code=400, detail="行程 ID 必須為數字") from exc
            stmt = stmt.where(Trip.trip_id == trip_id)
        elif search_type == "user_id":
            try:
                user_id = int(search_value)
            except ValueError as exc:
                raise HTTPException(status_code=400, detail="用戶 ID 必須為數字") from exc
            stmt = stmt.where(Trip.user_id == user_id)
        elif search_type == "vehicle_id":
            stmt = stmt.where(Trip.vehicle_id == search_value)
        elif search_type == "owner_id":
            try:
                owner_id = int(search_value)
            except ValueError as exc:
                raise HTTPException(status_code=400, detail="車主 ID 必須為數字") from exc
            stmt = stmt.where(Vehicle.owner_id == owner_id)
        elif search_type == "user_name":
            like_value = f"%{search_value}%"
            stmt = stmt.where(
                or_(
                    rider_alias.display_name.ilike(like_value),
                    rider_alias.username.ilike(like_value),
                    driver_alias.display_name.ilike(like_value),
                    driver_alias.username.ilike(like_value),
                )
            )
        elif search_type == "plate_number":
            stmt = stmt.where(Vehicle.plate_number.ilike(f"%{search_value}%"))
        elif search_type == "vehicle_model":
            stmt = stmt.where(Vehicle.model.ilike(f"%{search_value}%"))

    rows = (await session.execute(stmt)).all()

    data = []
    for trip, rider, driver, vehicle, owner in rows:
        rider_name = None
        rider_phone = None
        if rider:
            rider_name = rider.display_name or rider.username
            rider_phone = rider.phone_number

        driver_name = None
        driver_phone = None
        if driver:
            driver_name = driver.display_name or driver.username
            driver_phone = driver.phone_number
        elif owner:
            driver_name = owner.display_name or owner.username
            driver_phone = owner.phone_number

        data.append(
            {
                "trip_id": trip.trip_id,
                "status": trip.status,
                "user_id": trip.user_id,
                "vehicle_id": trip.vehicle_id,
                "rider_name": rider_name,
                "rider_phone": rider_phone,
                "driver_name": driver_name,
                "driver_phone": driver_phone,
                "plate_number": vehicle.plate_number if vehicle else None,
                "vehicle_model": vehicle.model if vehicle else None,
                "pickup_lat": trip.pickup_lat,
                "pickup_lng": trip.pickup_lng,
                "dropoff_lat": trip.dropoff_lat,
                "dropoff_lng": trip.dropoff_lng,
                "distance_km": trip.distance_km,
                "fare": trip.fare,
                "requested_at": trip.requested_at.isoformat() if trip.requested_at else None,
                "picked_up_at": trip.picked_up_at.isoformat() if trip.picked_up_at else None,
                "dropped_off_at": trip.dropped_off_at.isoformat() if trip.dropped_off_at else None,
                "total_amount": trip.total_amount,
                "payment_status": trip.payment_status,
                "payment_tx_hash": trip.payment_tx_hash,
            }
        )

    return data


@router.get("/{trip_id}")
async def get_trip(
    trip_id: int,
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    trip = await session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="行程不存在")

    rider = await session.get(User, trip.user_id) if trip.user_id else None
    driver = await session.get(User, trip.driver_id) if trip.driver_id else None
    vehicle = await session.get(Vehicle, trip.vehicle_id) if trip.vehicle_id else None
    owner = await session.get(User, vehicle.owner_id) if vehicle and vehicle.owner_id else None

    rider_name = None
    rider_phone = None
    rider_email = None
    if rider:
        rider_name = rider.display_name or rider.username
        rider_phone = rider.phone_number
        rider_email = rider.email

    driver_name = None
    driver_phone = None
    driver_email = None
    driver_id = None
    if driver:
        driver_name = driver.display_name or driver.username
        driver_phone = driver.phone_number
        driver_email = driver.email
        driver_id = driver.id
    elif owner:
        driver_name = owner.display_name or owner.username
        driver_phone = owner.phone_number
        driver_email = owner.email
        driver_id = owner.id

    return {
        "trip_id": trip.trip_id,
        "status": trip.status,
        "pickup_address": trip.pickup_address,
        "dropoff_address": trip.dropoff_address,
        "distance_km": trip.distance_km,
        "fare": trip.fare,
        "total_amount": trip.total_amount,
        "payment_status": trip.payment_status,
        "payment_tx_hash": trip.payment_tx_hash,
        "user": {
            "id": rider.id if rider else None,
            "name": rider_name,
            "phone": rider_phone,
            "email": rider_email,
        },
        "driver": {
            "id": driver_id,
            "name": driver_name,
            "phone": driver_phone,
            "email": driver_email,
        },
        "vehicle": {
            "vehicle_id": vehicle.vehicle_id if vehicle else None,
            "plate_number": vehicle.plate_number if vehicle else None,
            "model": vehicle.model if vehicle else None,
            "battery_capacity_kWh": vehicle.battery_capacity_kwh if vehicle else None,
        },
        "timestamps": {
            "requested_at": trip.requested_at.isoformat() if trip.requested_at else None,
            "matched_at": trip.matched_at.isoformat() if trip.matched_at else None,
            "picked_up_at": trip.picked_up_at.isoformat() if trip.picked_up_at else None,
            "completed_at": trip.completed_at.isoformat() if trip.completed_at else None,
            "cancelled_at": trip.cancelled_at.isoformat() if trip.cancelled_at else None,
        },
    }


@router.put("/{trip_id}/status")
async def update_trip_status(
    trip_id: int,
    payload: TripStatusUpdate,
    _=Depends(get_current_admin),
    session: AsyncSession = Depends(get_async_session),
):
    if payload.status not in VALID_TRIP_STATUSES:
        raise HTTPException(status_code=400, detail="無效的狀態值")

    trip = await session.get(Trip, trip_id)
    if not trip:
        raise HTTPException(status_code=404, detail="行程不存在")

    if payload.skip_timestamp:
        trip.status = payload.status
    else:
        trip.update_status(payload.status)

    await session.commit()

    return {"message": "行程狀態已更新"}
